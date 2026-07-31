#!/usr/bin/env bash
# SDFuzz directed-analysis workflow, parameterized by config.env.
# Originally developed for CVE-2017-14940 (binutils nm),
# generalized to work with any subject via config.env build fields.
set -euo pipefail

# case_dir is the CVE-specific directory (the symlink location, not resolved).
case_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# channel_dir is the repo root.  Resolve the script's real location
# using readlink -f so that it works regardless of where the symlink
# that points here lives.
script_real="$(readlink -f "${BASH_SOURCE[0]}")"
channel_dir="$(cd "$(dirname "$script_real")/.." && pwd)"

# shellcheck source=config.env
source "$case_dir/config.env"

if [[ "$GUIX_SPEC" != *@* ]]; then
    echo "GUIX_SPEC must include an explicit version (for example binutils@2.29)." >&2
    exit 2
fi

# ---- Build configuration (from config.env, with defaults) ----
# Use ${var-default} (instead of :-) so that setting a variable to the
# empty string explicitly overrides the default.  This is important for
# CONFIGURE_FLAGS (empty = no extra flags), MAKE_BINARY_TARGET
# (empty = no specific make target, "make all" builds everything),
# and MAKE_BINARY_SUBDIR (empty = binary is in the build root).
# BINARY_BASENAME: actual binary filename in build tree (e.g. nm-new, readelf)
binary_basename="${BINARY_BASENAME:-$BINARY}"
# BUILD_SYSTEM: configure (autotools; the default) or cmake.  Leave unset
# for the traditional ./configure + make flow used by existing subjects.
build_system="${BUILD_SYSTEM:-configure}"
# CONFIGURE_FLAGS: extra flags for ./configure or cmake.  The default is
# binutils-style for autotools and empty for cmake, so that a cmake
# subject which omits CONFIGURE_FLAGS never receives autotools flags.
if [[ "$build_system" == "cmake" ]]; then
    configure_flags="${CONFIGURE_FLAGS-}"
else
    configure_flags="${CONFIGURE_FLAGS---disable-nls --disable-werror}"
fi
# MAKE_BUILD_TARGET: target for full build (e.g. all-binutils, all)
# MAKE_BINARY_TARGET: target for the specific binary (e.g. nm-new; empty = none)
# MAKE_BINARY_SUBDIR: subdirectory for binary target (e.g. binutils; empty = root)
# The defaults are autotools-specific; for CMake subjects the conventional
# targets differ ("all" for the full build, binaries in the build root), so
# mirror the CONFIGURE_FLAGS treatment and use build-system-aware defaults.
if [[ "$build_system" == "cmake" ]]; then
    make_build_target="${MAKE_BUILD_TARGET-all}"
    make_binary_target="${MAKE_BINARY_TARGET-}"
    make_binary_subdir="${MAKE_BINARY_SUBDIR-}"
else
    make_build_target="${MAKE_BUILD_TARGET:-all-binutils}"
    make_binary_target="${MAKE_BINARY_TARGET-$binary_basename}"
    make_binary_subdir="${MAKE_BINARY_SUBDIR-binutils}"
fi
# SANITIZER_FLAGS: extra flags for ASan build (default catches memory errors).
# For bugs like signed integer overflow, add -fsanitize=undefined.
sanitizer_flags="${SANITIZER_FLAGS:--fsanitize=address}"
# EXTRA_CFLAGS: additional compiler flags applied to all build passes
# (ASan, first-pass LTO, and second-pass distance-instrumented).
# Use for project-specific codegen flags (e.g. -fcommon for libming).
extra_cflags="${EXTRA_CFLAGS-}"

version="${GUIX_SPEC##*@}"
source_name="${GUIX_SPEC%%@*}-${version}"
work_dir="$case_dir/work-sdfuzz"
src_dir="$work_dir/src"
dist_dir="$work_dir/distance"
build1_dir="$work_dir/build-pass1"
build2_dir="$work_dir/build-pass2"
wrapper_dir="$work_dir/wrappers"
poc_path="$case_dir/$POC_INPUT"
jobs="${SDFUZZ_JOBS:-16}"

sdfuzz=""
runtime_library_path=""
linux_headers=""
clang_prefix=""
llvm_prefix=""
cmake_bin=""
# BUILD_INPUTS: space-separated Guix package names for build dependencies.
# Resolved in require_tools(); their include (-isystem) and library (-L)
# paths are added to CFLAGS and LDFLAGS in all build passes.
build_inputs_cflags=""
build_inputs_ldflags=""

# Resolved source directory (after extracting the tarball, the actual
# directory name may differ from $source_name when GUIX_SPEC includes
# a transformation suffix like -static, -with-asan, etc.)
resolved_src_dir=""

# Global for ASan binary path (avoids command-substitution subshell which
# would discard side effects like runtime_library_path modifications).
_asan_binary_path=""

# ---- Helper: run the project's configure step ----
# Supports both autotools (./configure) and CMake (out-of-source cmake)
# build systems, selected via the BUILD_SYSTEM config.env field.
run_configure() {
    local source_dir="$1"
    if [[ "$build_system" == "cmake" ]]; then
        [[ -n "$cmake_bin" ]] || {
            echo "run_configure: cmake_bin unset; require_tools must run first." >&2
            exit 1
        }
        # -DCMAKE_POLICY_VERSION_MINIMUM=3.5 keeps old CMakeLists.txt files
        # (e.g. libjpeg-turbo 2.0.1's cmake_minimum_required 2.8.12)
        # configurable with the modern CMake that Guix resolves.
        "$cmake_bin" "$source_dir" \
            -DCMAKE_POLICY_VERSION_MINIMUM=3.5 $configure_flags
    else
        "$source_dir/configure" $configure_flags
    fi
}

# ---- Helper: run make for the configured binary target ----
# When MAKE_BINARY_TARGET is empty, the full build (make all) already
# builds the binary and no additional make invocation is needed.
run_make_binary() {
    [[ -z "$make_binary_target" ]] && return 0
    if [[ -n "$make_binary_subdir" ]]; then
        make -j"$jobs" -C "$make_binary_subdir" "$make_binary_target" "$@"
    else
        make -j"$jobs" "$make_binary_target" "$@"
    fi
}

# ---- Helper: find the binary in a build directory ----
# Prefer the real binary in .libs/ (libtool installs shell wrappers at the
# main path and the real ELF binary in .libs/).  Fall back to anything.
find_binary() {
    local build_dir="$1"
    local binary
    # Look inside .libs/ first (real ELF binary, not a libtool wrapper).
    binary="$(find "$build_dir" -type f -path "*/.libs/$binary_basename" \
        -perm -111 -print -quit 2>/dev/null || true)"
    if [[ -z "$binary" ]]; then
        # Fall back to any matching file in the build tree.
        binary="$(find "$build_dir" -type f -name "$binary_basename" -perm -111 \
            -print -quit 2>/dev/null || true)"
    fi
    printf '%s\n' "$binary"
}

require_tools() {
    [[ -f "$poc_path" ]] || {
        echo "PoC input not found: $poc_path" >&2
        exit 1
    }

    # For CMake subjects, resolve cmake from the Guix store rather than the
    # host system: the build runs with a Guix LD_LIBRARY_PATH (libgcc/asan
    # runtime), and the system cmake breaks on the Guix libstdc++ (GLIBC
    # version mismatch).  guix build cmake returns multiple outputs
    # (cmake-<v>-doc, main), so drop the -doc output (no bin/cmake there).
    if [[ "$build_system" == "cmake" ]]; then
        local cmake_prefix
        cmake_prefix="$(guix build -L "$channel_dir" cmake --no-grafts \
            2>/dev/null | grep -v -- '-doc$' | head -1 || true)"
        # Guard against an empty prefix: without it, "$cmake_prefix/bin/cmake"
        # would silently become "/bin/cmake" (system cmake), reintroducing
        # the GLIBC mismatch this Guix resolution is meant to avoid.
        cmake_bin="$cmake_prefix/bin/cmake"
        [[ -n "$cmake_prefix" && -x "$cmake_bin" ]] || {
            echo "BUILD_SYSTEM=cmake but Guix cmake could not be resolved." >&2
            exit 1
        }
    fi

    sdfuzz="$(guix build -L "$channel_dir" sdfuzz --no-grafts)"
    [[ -x "$sdfuzz/bin/afl-clang-fast" && -x "$sdfuzz/bin/sdfuzz-ld.lld" ]] || {
        echo "Guix SDFuzz compiler or LLVM 13 linker is unavailable: $sdfuzz" >&2
        exit 1
    }
    clang_prefix="$(guix build -e '(@ (gnu packages llvm) clang-13)' --no-grafts)"
    # guix build llvm-13 returns multiple outputs (opt-viewer, main).
    # Filter to get only the main output (contains bin/llvm-symbolizer).
    llvm_prefix="$(guix build -e '(@ (gnu packages llvm) llvm-13)' --no-grafts 2>/dev/null | grep -v opt-viewer | head -1 || true)"
    [[ -n "$llvm_prefix" ]] || {
        echo "Could not resolve Guix LLVM 13 (needed for llvm-ar and symbolizer)." >&2
        exit 1
    }
    export PATH="$clang_prefix/bin:$llvm_prefix/bin:$PATH"

    local libgcc asan_runtime
    libgcc="$("$sdfuzz/bin/afl-clang-fast" -print-file-name=libgcc_s.so.1 \
        2>/dev/null | tail -n 1)"
    asan_runtime="$("$sdfuzz/bin/afl-clang-fast" \
        -print-file-name=libclang_rt.asan-x86_64.so 2>/dev/null | tail -n 1)"
    [[ -f "$libgcc" && -f "$asan_runtime" ]] || {
        echo "Could not resolve SDFuzz compiler runtime libraries." >&2
        exit 1
    }
    runtime_library_path="$(dirname "$libgcc"):$(dirname "$asan_runtime")"
    linux_headers="$(guix build -L "$channel_dir" linux-libre-headers --no-grafts)"
    [[ -f "$linux_headers/include/linux/limits.h" ]] || {
        echo "Could not resolve Guix Linux C headers." >&2
        exit 1
    }

    # Resolve BUILD_INPUTS from Guix and collect include / library paths.
    if [[ -n "${BUILD_INPUTS:-}" ]]; then
        printf '[+] Resolving build inputs: %s\n' "${BUILD_INPUTS}" >&2
        local resolved_paths=""
        for dep in $BUILD_INPUTS; do
            local p
            # For multi-output packages (e.g. giflib has bin + out),
            # pick the first output that contains include/ files.
            p="$(guix build "$dep" --no-grafts 2>/dev/null | \
                while read -r candidate; do
                    [[ -d "$candidate/include" ]] && { echo "$candidate"; break; }
                done || true)"
            [[ -n "$p" ]] || {
                echo "Failed to resolve build input: $dep" >&2
                exit 1
            }
            [[ -d "$p/include" ]] && build_inputs_cflags="$build_inputs_cflags -isystem $p/include"
            [[ -d "$p/lib" ]] && build_inputs_ldflags="$build_inputs_ldflags -L$p/lib"
            resolved_paths="$resolved_paths $p"
        done
        # Also add Guix lib dirs to runtime_library_path so shared libraries
        # (e.g. libpng, libz) can be found when running the instrumented binary.
        for p in $resolved_paths; do
            [[ -d "$p/lib" ]] && \
                runtime_library_path="$runtime_library_path:$p/lib"
        done
    fi

    # Build SVF (pointer analysis) and set SDFUZZ_WPA for indirect-call resolution
    printf '[+] Building SVF for WPA pointer analysis...\n' >&2
    local svf_prefix wpa_path
    svf_prefix="$(guix build -L "$channel_dir" svf --no-grafts 2>/dev/null || true)"
    if [[ -n "$svf_prefix" ]]; then
        wpa_path="$svf_prefix/bin/wpa"
        if [[ -x "$wpa_path" ]]; then
            export SDFUZZ_WPA="$wpa_path"
        fi
    fi
}

prepare_source() {
    require_tools
    local source_tarball source_dir

    source_tarball="$(guix build -L "$channel_dir" "$GUIX_SPEC" --source --no-grafts)"
    mkdir -p "$src_dir"
    source_dir="$src_dir/$source_name"

    if [[ ! -d "$source_dir" ]]; then
        if [[ -d "$source_tarball" ]]; then
            # Git-fetch checkout: Guix --source returns a read-only
            # directory.  Copy it into the work tree so we can run
            # autoreconf and write build artifacts.
            printf '[+] Copying git checkout to %s\n' "$source_dir" >&2
            cp -r "$source_tarball" "$source_dir"
            chmod -R u+w "$source_dir"
            resolved_src_dir="$source_dir"
        else
            tar -xf "$source_tarball" -C "$src_dir"
        fi

        # The extracted directory may have a different name when GUIX_SPEC
        # includes a package transformation suffix like -static, -with-asan.
        # Search for the actual build-system entry point to discover the
        # real dir (configure for autotools, CMakeLists.txt for CMake).
        # Skip this when we already resolved via git checkout copy.
        if [[ -z "$resolved_src_dir" ]]; then
            local found
            if [[ "$build_system" == "cmake" ]]; then
                found="$(find "$src_dir" -maxdepth 2 -name CMakeLists.txt -type f \
                    -print -quit 2>/dev/null || true)"
            else
                found="$(find "$src_dir" -maxdepth 2 -name configure -type f \
                    -not -path '*/config.*' -print -quit 2>/dev/null || true)"
            fi
            if [[ -n "$found" ]]; then
                resolved_src_dir="$(dirname "$found")"
                source_dir="$resolved_src_dir"
            fi
        fi
    else
        resolved_src_dir="$source_dir"
    fi
    source_dir="$resolved_src_dir"

    # Git-fetch checkouts may lack a generated configure script.
    # Auto-detect configure.in / configure.ac and run autoreconf.
    if [[ "$build_system" == "configure" && ! -x "$source_dir/configure" ]]; then
        if [[ -f "$source_dir/configure.in" || -f "$source_dir/configure.ac" ]]; then
            printf '[+] Running autoreconf for %s\n' "$source_dir" >&2
            local autotools old_path="$PATH" old_aclocal="${ACLOCAL_PATH:-}"
            # Resolve autotools from the Guix store on demand.
            autotools="$(guix build autoconf automake libtool pkg-config m4 --no-grafts 2>/dev/null || true)"
            if [[ -z "$autotools" ]]; then
                echo "Could not resolve autotools from Guix store." >&2
                exit 1
            fi
            for t in $autotools; do
                [[ -d "$t/bin" ]] && export PATH="$t/bin:$PATH"
                [[ -d "$t/share/aclocal" ]] && export ACLOCAL_PATH="$t/share/aclocal${ACLOCAL_PATH:+:$ACLOCAL_PATH}"
            done
            if command -v autoreconf &>/dev/null; then
                (cd "$source_dir" && autoreconf -fi) || {
                    echo "autoreconf failed; see output above." >&2
                    exit 1
                }
            else
                echo "autoreconf not found in PATH; cannot bootstrap $source_dir" >&2
                exit 1
            fi
            export PATH="$old_path"
            export ACLOCAL_PATH="$old_aclocal"
        fi
    fi

    if [[ "$build_system" == "cmake" ]]; then
        [[ -f "$source_dir/CMakeLists.txt" ]] || {
            echo "Unexpected source layout; CMakeLists.txt is missing from $source_dir" >&2
            exit 1
        }
    else
        [[ -x "$source_dir/configure" ]] || {
            echo "Unexpected source layout; configure is missing from $source_dir" >&2
            exit 1
        }
    fi

    printf '[+] Source prepared in %s\n' "$source_dir" >&2
}

build_target_stack() {
    require_tools
    local asan_bin crash_log callstack status glibc_lib
    _asan_binary_path=""
    build_asan_binary
    asan_bin="$_asan_binary_path"
    [[ -n "$asan_bin" ]] || {
        echo "build_asan_binary did not set _asan_binary_path" >&2
        exit 1
    }

    # Extract the Guix glibc library path from the binary's ELF interpreter
    # so the correct libc is found at runtime (avoiding host-system mismatch).
    glibc_lib="$(readelf -l "$asan_bin" 2>/dev/null | \
        sed -n 's/.*\[Requesting program interpreter: \(.*\)\]/\1/p' | \
        xargs dirname 2>/dev/null || true)"

    mkdir -p "$dist_dir"
    crash_log="$dist_dir/crash.log"
    callstack="$dist_dir/BBtargets.txt"

    local -a test_args
    read -r -a test_args <<< "$TEST_CMD"
    for i in "${!test_args[@]}"; do
        [[ "${test_args[$i]}" == '@@' ]] && test_args[$i]="$poc_path"
    done

    set +e
    # Diagnostics: verify the binary is executable and the interpreter exists.
    if [[ ! -x "$asan_bin" ]]; then
        echo "[!] Binary not executable: $asan_bin" | tee -a "$crash_log" 2>/dev/null
        exit 1
    fi
    local interp
    interp="$(readelf -l "$asan_bin" 2>/dev/null | \
        sed -n 's/.*\[Requesting program interpreter: \(.*\)\]/\1/p' || true)"
    if [[ -n "$interp" && ! -x "$interp" ]]; then
        echo "[!] ELF interpreter not found: $interp" | tee -a "$crash_log" 2>/dev/null
        exit 1
    fi
    printf '[DBG] Running: %s\n' "$asan_bin" >&2
    printf '[DBG] LD_LIBRARY_PATH=%s\n' "${glibc_lib:+$glibc_lib:}$runtime_library_path${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" >&2
    LD_LIBRARY_PATH="${glibc_lib:+$glibc_lib:}$runtime_library_path${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
        ASAN_OPTIONS='detect_leaks=0:abort_on_error=1:symbolize=1'"${ASAN_OPTIONS:+:$ASAN_OPTIONS}" \
        UBSAN_OPTIONS='print_stacktrace=1:halt_on_error=1:symbolize=1'"${UBSAN_OPTIONS:+:$UBSAN_OPTIONS}" \
        ASAN_SYMBOLIZER_PATH="$llvm_prefix/bin/llvm-symbolizer" \
        "$asan_bin" "${test_args[@]}" >"$crash_log" 2>&1
    status=$?
    set -e
    if [[ $status -eq 0 ]]; then
        echo "The configured PoC did not crash the ASan-instrumented $BINARY." >&2
        exit 1
    fi

    "$sdfuzz/bin/Stackparser.py" "$crash_log" "$callstack"
    if [[ ! -s "$callstack" ]]; then
        printf '[!] Stackparser.py produced no output; attempting fallback extraction...\n' >&2
        # Fallback 1: look for any file:line patterns in the crash log.
        # Handles UBSan output ("source.c:123: runtime error"), ASan assertions,
        # and other sanitizer reports.
        local fb_target
        fb_target="$(
            grep -oP '\b\w+\.(?:c|cpp|cxx|cc|c\+\+|h|hpp|hh|hxx):\d+' "$crash_log" 2>/dev/null | \
            grep -v -E '(sanitizer|compiler-rt|ubsan|asan|libc|pthread|include/)' | \
            tail -1 || true
        )"
        if [[ -n "$fb_target" ]]; then
            printf '%s\n' "$fb_target" >"$callstack"
            printf '[+] Extracted target from crash log: %s\n' "$fb_target" >&2
        else
            # Fallback 2: Try running under the crash log with addr2line
            # to extract file:line from any instruction-pointer reference.
            # This handles cases where the binary exits with an error code
            # but the crash log contains no symbolized file:line references.
            local instr_addr
            instr_addr="$(grep -oP '0x[0-9a-f]{6,}' "$crash_log" 2>/dev/null | head -1 || true)"
            if [[ -n "$instr_addr" && -n "$asan_bin" ]]; then
                local addr2line_out
                addr2line_out="$("$llvm_prefix/bin/llvm-symbolizer" --obj="$asan_bin" "$instr_addr" 2>/dev/null || true)"
                fb_target="$(printf '%s\n' "$addr2line_out" | grep -oP '\w+\.(?:c|cpp|cxx|cc|c\+\+|h|hpp|hh|hxx):\d+' | head -1 || true)"
                if [[ -n "$fb_target" ]]; then
                    printf '%s\n' "$fb_target" >"$callstack"
                    printf '[+] Extracted target via llvm-symbolizer: %s\n' "$fb_target" >&2
                fi
            fi
        fi
    fi
    if [[ ! -s "$callstack" ]]; then
        echo "Stackparser produced no target stack and fallbacks failed; see $crash_log" >&2
        exit 1
    fi
    printf '[+] Target stack written to %s\n' "$callstack" >&2
}

build_asan_binary() {
    local build_dir="$work_dir/build-asan"
    local log_file="$work_dir/asan-build.log"
    local binary

    if [[ -z "$resolved_src_dir" || ! -d "$resolved_src_dir" ]]; then
        prepare_source
    fi
    local source_dir="$resolved_src_dir"
    binary="$(find_binary "$build_dir")"
    if [[ -z "$binary" ]]; then
        rm -rf "$build_dir"
        mkdir -p "$build_dir"
        (
            cd "$build_dir"
            export LD_LIBRARY_PATH="$runtime_library_path${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
            # Build-time tools (e.g. bfd/doc/chew) are also compiled with ASan
            # and may leak; suppress leak detection to avoid build failures.
            export ASAN_OPTIONS="detect_leaks=0${ASAN_OPTIONS:+:$ASAN_OPTIONS}"
            local linux_inc="-isystem $linux_headers/include $build_inputs_cflags"
            CC="${CC_ASAN:-$clang_prefix/bin/clang}" \
                CXX="${CXX_ASAN:-$clang_prefix/bin/clang++}" \
                CFLAGS="-g -O0 $linux_inc $sanitizer_flags $extra_cflags" \
                CXXFLAGS="-g -O0 $linux_inc $sanitizer_flags $extra_cflags" \
                LDFLAGS="$sanitizer_flags $build_inputs_ldflags" \
                run_configure "$source_dir" &&
            make -j"$jobs" "$make_build_target" &&
            run_make_binary
        ) >"$log_file" 2>&1 || {
            tail -n 80 "$log_file" >&2
            exit 1
        }
        binary="$(find_binary "$build_dir")"
    fi
    [[ -n "$binary" ]] || {
        echo "The ASan build did not produce $binary_basename." >&2
        exit 1
    }
    # Resolve project-internal shared library dependencies (e.g. libjasper
    # for imginfo) that are built as part of this project, so they can be
    # found at runtime via LD_LIBRARY_PATH.
    resolve_missing_libs "$binary"
    _asan_binary_path="$binary"
}

# ---- Helper: resolve missing shared library dependencies ----
# After building the ASan binary, check ldd for "not found" libraries and
# search for them in the build tree or Guix store, adding their paths to
# the global runtime_library_path.
resolve_missing_libs() {
    local binary="$1"
    local missing new_paths=""
    # Guard the pipeline: grep finds nothing for fully-static binaries
    # (e.g. djpeg-static) and would otherwise trip set -euo pipefail.
    missing="$(ldd "$binary" 2>/dev/null | grep 'not found' | awk '{print $1}' \
        || true)"
    [[ -z "$missing" ]] && return 0

    for lib in $missing; do
        local found
        # Search in the pass build directories first (project-internal libs
        # compiled without ASan), then the ASan build directory.  This
        # avoids picking up ASan-compiled shared libraries that have ASan
        # runtime dependencies (e.g. __asan_option_detect_stack_use_after_return)
        # which the distance-instrumented (non-ASan) binary can't resolve.
        for bd in "$work_dir/build-pass2" "$work_dir/build-pass1" "$work_dir/build-asan"; do
            found="$(find "$bd" -name "$lib" \
                \( -type f -o -type l \) -print -quit 2>/dev/null || true)"
            [[ -n "$found" ]] && break
        done
        if [[ -z "$found" ]]; then
            # Fall back to all build dirs (excluding extracted source tree).
            found="$(find "$work_dir" -name "$lib" \
                \( -type f -o -type l \) \
                -not -path "$src_dir/*" -print -quit 2>/dev/null || true)"
        fi
        if [[ -z "$found" ]]; then
            # Search the Guix store.
            found="$(find /gnu/store -maxdepth 4 -name "$lib" \
                \( -type f -o -type l \) \
                -print -quit 2>/dev/null || true)"
        fi
        if [[ -n "$found" ]]; then
            local dir="$(dirname "$found")"
            if [[ ":$runtime_library_path:" != *":$dir:"* ]]; then
                new_paths="$new_paths:$dir"
            fi
        fi
    done
    if [[ -n "$new_paths" ]]; then
        runtime_library_path="${runtime_library_path}${new_paths}"
        printf '[+] Added library paths: %s\n' "${new_paths#:}" >&2
    fi
}

create_wrappers() {
    local pass="$1"
    local cc_flags cxx_flags trailing_flags

    mkdir -p "$wrapper_dir"
    case "$pass" in
        first)
            cc_flags="-isystem $linux_headers/include $build_inputs_cflags -g -O0 -flto -fuse-ld=$sdfuzz/bin/sdfuzz-ld.lld -Wl,--save-temps -rdynamic -targets=$dist_dir/BBtargets.txt -outdir=$dist_dir"
            cxx_flags="$cc_flags"
            trailing_flags=""
            ;;
        second)
            cc_flags="-isystem $linux_headers/include $build_inputs_cflags -g -O0 -distance=$dist_dir/distance.cfg.txt -targets=$dist_dir/BBtargets.txt"
            cxx_flags="$cc_flags"
            # Some projects (e.g. libjpeg-turbo 1.5.3) force -O3 -funroll-loops
            # in their Makefile, which lands after our -O0 on the command line
            # and crashes LLVM 13 codegen (Machine Copy Propagation) on the
            # distance-instrumented target functions.  Force the flags back
            # after "$@" so they take precedence over the project's.
            trailing_flags="-O0 -fno-unroll-loops"
            ;;
        *)
            echo "Unknown build pass: $pass" >&2
            exit 2
            ;;
    esac

    rm -f "$wrapper_dir/cc" "$wrapper_dir/cxx"
    cat >"$wrapper_dir/cc" <<EOF
#!/bin/sh
exec "$sdfuzz/bin/afl-clang-fast" $cc_flags $extra_cflags "\$@" $trailing_flags
EOF
    cat >"$wrapper_dir/cxx" <<EOF
#!/bin/sh
exec "$sdfuzz/bin/afl-clang-fast++" $cc_flags $extra_cflags "\$@" $trailing_flags
EOF
    chmod 555 "$wrapper_dir/cc" "$wrapper_dir/cxx"
}

build_pass_binary() {
    local pass="$1" build_dir="$2"
    local log_file="$work_dir/$pass-build.log"

    if [[ -z "$resolved_src_dir" || ! -d "$resolved_src_dir" ]]; then
        prepare_source
    fi
    local source_dir="$resolved_src_dir"
    [[ -s "$dist_dir/BBtargets.txt" ]] || build_target_stack
    rm -rf "$build_dir"
    mkdir -p "$build_dir"
    create_wrappers "$pass"

    (
        cd "$build_dir"
        export LD_LIBRARY_PATH="$runtime_library_path${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
        export CPPFLAGS="-isystem $linux_headers/include $build_inputs_cflags${CPPFLAGS:+ $CPPFLAGS}"
        export LDFLAGS="$build_inputs_ldflags${LDFLAGS:+ $LDFLAGS}"
        # LTO passes compile to LLVM bitcode, which host GNU binutils
        # ar/ranlib cannot index (broken archive symbol table -> "undefined
        # symbol: jpeg_*" at link time).  Use the LLVM archive tools that the
        # Guix llvm-13 package provides, as documented in
        # sdfuzz/temporal-specialization/COMPILE.md.  Scoped to the LTO passes
        # only so the non-LTO ASan build keeps using the host tools.
        export AR="$llvm_prefix/bin/llvm-ar"
        export RANLIB="$llvm_prefix/bin/llvm-ranlib"
        export NM="$llvm_prefix/bin/llvm-nm"
        CC="$wrapper_dir/cc" CXX="$wrapper_dir/cxx" \
            run_configure "$source_dir" &&
        make -j"$jobs" "$make_build_target" &&
        run_make_binary
    ) >"$log_file" 2>&1 || {
        tail -n 80 "$log_file" >&2
        exit 1
    }
}

first_pass() {
    require_tools
    build_pass_binary first "$build1_dir"

    local bitcode
    bitcode="$(find "$build1_dir" -type f -name "${binary_basename}.0.0.preopt.bc" -print -quit)"
    [[ -n "$bitcode" ]] || {
        echo "LTO bitcode for $binary_basename was not saved; see $work_dir/first-build.log" >&2
        exit 1
    }
    [[ -s "$dist_dir/BBnames.txt" && -s "$dist_dir/BBcalls.txt" ]] || {
        echo "SDFuzz did not produce basic-block metadata." >&2
        exit 1
    }

    sed 's/:$//' "$dist_dir/BBnames.txt" | sort -u >"$dist_dir/BBnames.txt.new"
    mv "$dist_dir/BBnames.txt.new" "$dist_dir/BBnames.txt"
    sort -u "$dist_dir/BBcalls.txt" >"$dist_dir/BBcalls.txt.new"
    mv "$dist_dir/BBcalls.txt.new" "$dist_dir/BBcalls.txt"
    printf '[+] First-pass metadata and LTO bitcode are ready.\n' >&2
}

analyze_distances() {
    require_tools
    [[ -s "$dist_dir/BBtargets.txt" && -s "$dist_dir/BBnames.txt" ]] || {
        echo "Run the target-stack and first-pass steps first." >&2
        exit 1
    }

    "$sdfuzz/bin/BBmapping.py" "$dist_dir/BBtargets.txt" \
        "$dist_dir/BBnames.txt" "$dist_dir/real.txt"
    [[ -s "$dist_dir/real.txt" ]] || {
        echo "No target locations mapped to first-pass basic blocks." >&2
        exit 1
    }

    rm -rf "$dist_dir/dot-files" "$dist_dir/state" "$dist_dir/distance.cfg.txt" \
        "$dist_dir/ctrl-data.dot"
    mkdir -p "$dist_dir/dot-files"

    local build1_binary bin_dir
    build1_binary="$(find_binary "$build1_dir")"
    if [[ -n "$make_binary_subdir" ]]; then
        bin_dir="$build1_dir/$make_binary_subdir"
    else
        bin_dir="$build1_dir"
    fi

    if "$sdfuzz/bin/genDistance.sh" "$bin_dir" "$dist_dir" "$binary_basename"; then
        if [[ -s "$dist_dir/distance.cfg.txt" ]]; then
            printf '[+] Distance configuration written to %s\n' "$dist_dir/distance.cfg.txt"
            return
        fi
        echo "genDistance.sh succeeded but distance.cfg.txt is missing; falling back to Python distance computation." >&2
    else
        echo "genDistance.sh failed (fuzzopt.so crash); falling back to Python distance computation." >&2
    fi

    # Fallback: use the Python-based compute_distances.py
    # Search in multiple locations: shared dirs (binutils, loftix-benchmarks root),
    # local tmp/, and other candidates.
    local py_fallback=""
    for candidate in "$(dirname "$case_dir")/compute_distances.py" \
                     "$case_dir/tmp/compute_distances.py" \
                     "$channel_dir/loftix-benchmarks/binutils/compute_distances.py" \
                     "$channel_dir/loftix-benchmarks/compute_distances.py"; do
        [[ -f "$candidate" ]] && { py_fallback="$candidate"; break; }
    done
    if [[ -n "$py_fallback" && -n "$build1_binary" ]]; then
        if "$py_fallback" "$dist_dir" "$dist_dir/distance.cfg.txt" "$build1_binary"; then
            if [[ -s "$dist_dir/distance.cfg.txt" ]]; then
                # Generate ctrl-data.dot (BB whitelist for selective instrumentation)
                # Required by afl-llvm-pass.so.cc when -distance flag is used.
                awk -F',' '{print $1}' "$dist_dir/distance.cfg.txt" > "$dist_dir/ctrl-data.dot"
                printf '[+] Whitelist written to %s\n' "$dist_dir/ctrl-data.dot"
                printf '[+] Distance configuration written to %s (Python fallback)\n' "$dist_dir/distance.cfg.txt"
                return
            fi
        fi
        echo "Python fallback also failed to produce distance.cfg.txt." >&2
    else
        echo "Python fallback unavailable (missing script or binary)." >&2
    fi
    exit 1
}

second_pass() {
    require_tools
    [[ -s "$dist_dir/distance.cfg.txt" ]] || {
        echo "Run the distance-analysis step first." >&2
        exit 1
    }
    build_pass_binary second "$build2_dir"

    local built_binary
    built_binary="$(find_binary "$build2_dir")"
    [[ -n "$built_binary" ]] || {
        echo "The second pass did not build $binary_basename." >&2
        exit 1
    }
    cp "$built_binary" "$work_dir/$BINARY"
    # Resolve shared library dependencies for the distance-instrumented
    # binary (e.g. libjasper.so.1 for imginfo) so they can be found at
    # fuzz time via runtime_library_path.
    resolve_missing_libs "$work_dir/$BINARY"
    printf '[+] Distance-instrumented target written to %s\n' "$work_dir/$BINARY" >&2
}

run_fuzzer() {
    require_tools
    local -a test_args
    if [[ -x "$work_dir/$BINARY" ]]; then
        # require_tools resets runtime_library_path, so re-discover
        # shared library dependencies before running the fuzzer.
        resolve_missing_libs "$work_dir/$BINARY"
    else
        second_pass
    fi
    mkdir -p "$work_dir/in" "$work_dir/out"
    cp "$poc_path" "$work_dir/in/seed"
    read -r -a test_args <<< "$TEST_CMD"
    (
        cd "$work_dir"
        export LD_LIBRARY_PATH="$runtime_library_path${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
        "$sdfuzz/bin/afl-fuzz" -m "${SDFUZZ_MEMORY_LIMIT:-none}" \
            -z "${SDFUZZ_EXPSCHEDULE:-exp}" -c "${SDFUZZ_CYCLE_LIMIT:-45m}" \
            -i in -o out -d -- "./$BINARY" "${test_args[@]}"
    )
}

clean() {
    rm -rf "$work_dir"
}

case "${1:-all}" in
    prepare) prepare_source ;;
    stack) build_target_stack ;;
    pass1) first_pass ;;
    analyze) analyze_distances ;;
    pass2) second_pass ;;
    fuzz) run_fuzzer ;;
    all) clean; prepare_source; build_target_stack; first_pass; analyze_distances; second_pass ;;
    clean) clean ;;
    *)
        echo "Usage: $0 {prepare|stack|pass1|analyze|pass2|fuzz|all|clean}" >&2
        exit 2
        ;;
esac
