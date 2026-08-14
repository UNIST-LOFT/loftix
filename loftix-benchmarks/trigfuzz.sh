#!/usr/bin/env bash
# TrigFuzz directed-analysis workflow, parameterized by config.env.
#
# TrigFuzz is an LLM-driven directed fuzzer: it extracts vulnerability
# triggering conditions (TCUs) from a bug report + source, instruments
# the target with triggering-distance feedback (distance.h runtime), and
# fuzzes with the patched AFLGo engine (crash seeds admitted to the queue).
#
# Steps:
#   prepare  - resolve the Guix package + tools, extract the subject source
#   stack    - build an ASan binary, run the PoC, extract the crash site
#   tcgen    - LLM-generate triggering-condition candidates (tcus.json)
#   build    - instrument the source (v1) and compile with afl-gcc
#   fuzz     - run the patched afl-fuzz with triggering-distance guidance
#   all      - prepare + stack + tcgen + build + fuzz
#
# The .env file (OPENAI_API_KEY / OPENAI_MODEL / OPENAI_API_BASE_URL) is
# loaded from loftix-benchmarks/ when present; the trigfuzz wrappers also
# re-export those variables.
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
binary_basename="${BINARY_BASENAME:-$BINARY}"
build_system="${BUILD_SYSTEM:-configure}"
if [[ "$build_system" == "cmake" ]]; then
    configure_flags="${CONFIGURE_FLAGS-}"
else
    configure_flags="${CONFIGURE_FLAGS---disable-nls --disable-werror}"
fi
if [[ "$build_system" == "cmake" ]]; then
    make_build_target="${MAKE_BUILD_TARGET-all}"
    make_binary_target="${MAKE_BINARY_TARGET-}"
    make_binary_subdir="${MAKE_BINARY_SUBDIR-}"
else
    make_build_target="${MAKE_BUILD_TARGET:-all-binutils}"
    make_binary_target="${MAKE_BINARY_TARGET-$binary_basename}"
    make_binary_subdir="${MAKE_BINARY_SUBDIR-binutils}"
fi
sanitizer_flags="${SANITIZER_FLAGS:--fsanitize=address}"
extra_cflags="${EXTRA_CFLAGS-}"

version="${GUIX_SPEC##*@}"
source_name="${GUIX_SPEC%%@*}-${version}"
work_dir="$case_dir/work-trigfuzz"
src_dir="$work_dir/src"
target_dir="$work_dir/target"
source_v1="$work_dir/source-v1"
asan_dir="$work_dir/build-asan"
v1_dir="$work_dir/build-v1"
meta_file="$work_dir/meta.txt"
crash_points_file="$work_dir/crash_points.txt"
poc_path="$case_dir/$POC_INPUT"
jobs="${TRIGFUZZ_JOBS:-16}"

trigfuzz=""
runtime_library_path=""
linux_headers=""
clang_prefix=""
llvm_prefix=""
cmake_bin=""
build_inputs_cflags=""
build_inputs_ldflags=""
resolved_src_dir=""
python_bin=""

# ---- Helper: run the project's configure step ----
run_configure() {
    local source_dir="$1"
    if [[ "$build_system" == "cmake" ]]; then
        [[ -n "$cmake_bin" ]] || {
            echo "run_configure: cmake_bin unset; require_tools must run first." >&2
            exit 1
        }
        "$cmake_bin" "$source_dir" \
            -DCMAKE_POLICY_VERSION_MINIMUM=3.5 $configure_flags
    else
        "$source_dir/configure" $configure_flags
    fi
}

# ---- Helper: run make for the configured binary target ----
run_make_binary() {
    [[ -z "$make_binary_target" ]] && return 0
    if [[ -n "$make_binary_subdir" ]]; then
        make -j"$jobs" -C "$make_binary_subdir" "$make_binary_target" "$@"
    else
        make -j"$jobs" "$make_binary_target" "$@"
    fi
}

# ---- Helper: find the binary in a build directory ----
find_binary() {
    local build_dir="$1"
    local binary
    binary="$(find "$build_dir" -type f -path "*/.libs/$binary_basename" \
        -perm -111 -print -quit 2>/dev/null || true)"
    if [[ -z "$binary" ]]; then
        binary="$(find "$build_dir" -type f -name "$binary_basename" -perm -111 \
            -print -quit 2>/dev/null || true)"
    fi
    printf '%s\n' "$binary"
}

# ---- Helper: resolve missing shared library dependencies ----
resolve_missing_libs() {
    local binary="$1"
    local missing new_paths="" binary_dir
    missing="$(ldd "$binary" 2>/dev/null | grep 'not found' | awk '{print $1}' \
        || true)"

    binary_dir="$(dirname "$binary")"
    if [[ "$binary_dir" == */.libs && -n "$(ls "$binary_dir"/*.so 2>/dev/null)" ]]; then
        local needed
        needed="$(readelf -d "$binary" 2>/dev/null | grep '(NEEDED)' | \
            sed 's/.*\[\([^]]*\)\]/\1/' || true)"
        for lib in $needed; do
            if [[ -f "$binary_dir/$lib" || -L "$binary_dir/$lib" ]]; then
                if [[ ":$runtime_library_path:" != *":$binary_dir:"* ]]; then
                    new_paths="$new_paths:$binary_dir"
                    break
                fi
            fi
        done
    fi

    local sys_paths
    sys_paths="$(ldd "$binary" 2>/dev/null | \
        awk '/=> \// {print $3}' | xargs -r dirname | sort -u || true)"
    for dir in $sys_paths; do
        if [[ ":$runtime_library_path:" != *":$dir:"* ]]; then
            new_paths="$new_paths:$dir"
        fi
    done

    for lib in $missing; do
        local found
        # Prefer the build directory that produced the binary: the ASan
        # build's shared libraries carry ASan runtime dependencies (e.g.
        # __asan_option_detect_stack_use_after_return) that the
        # distance-instrumented (non-ASan) binary cannot resolve, so the
        # v1 binary must pick up the v1 build's libs (e.g. libjasper.so.1).
        local search_root
        case "$binary" in
            "$asan_dir"/*) search_root="$asan_dir" ;;
            "$v1_dir"/*|"$work_dir/$BINARY") search_root="$v1_dir" ;;
            *) search_root="" ;;
        esac
        if [[ -n "$search_root" ]]; then
            found="$(find "$search_root" -name "$lib" \
                \( -type f -o -type l \) -print -quit 2>/dev/null || true)"
        fi
        if [[ -z "$found" ]]; then
            found="$(find "$work_dir" -name "$lib" \
                \( -type f -o -type l \) \
                -not -path "$src_dir/*" -print -quit 2>/dev/null || true)"
        fi
        if [[ -z "$found" ]]; then
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

require_tools() {
    [[ -f "$poc_path" ]] || {
        echo "PoC input not found: $poc_path" >&2
        exit 1
    }

    # Load the .env file (OPENAI_API_KEY / OPENAI_MODEL / OPENAI_API_BASE_URL)
    # from the benchmarks directory when present.
    if [[ -f "$channel_dir/loftix-benchmarks/.env" ]]; then
        set -a
        # shellcheck disable=SC1091
        source "$channel_dir/loftix-benchmarks/.env"
        set +a
    fi

    if [[ "$build_system" == "cmake" ]]; then
        local cmake_prefix
        cmake_prefix="$(guix build -L "$channel_dir" cmake --no-grafts \
            2>/dev/null | grep -v -- '-doc$' | head -1 || true)"
        cmake_bin="$cmake_prefix/bin/cmake"
        [[ -n "$cmake_prefix" && -x "$cmake_bin" ]] || {
            echo "BUILD_SYSTEM=cmake but Guix cmake could not be resolved." >&2
            exit 1
        }
    fi

    trigfuzz="$(guix build -L "$channel_dir" trigfuzz --no-grafts)"
    [[ -x "$trigfuzz/bin/afl-fuzz" && -x "$trigfuzz/bin/afl-gcc" ]] || {
        echo "Guix TrigFuzz fuzzer or compiler is unavailable: $trigfuzz" >&2
        exit 1
    }
    clang_prefix="$(guix build -e '(@ (gnu packages llvm) clang-13)' --no-grafts)"
    llvm_prefix="$(guix build -e '(@ (gnu packages llvm) llvm-13)' --no-grafts 2>/dev/null | grep -v opt-viewer | head -1 || true)"
    [[ -n "$llvm_prefix" ]] || {
        echo "Could not resolve Guix LLVM 13 (needed for llvm-ar and symbolizer)." >&2
        exit 1
    }
    export PATH="$clang_prefix/bin:$llvm_prefix/bin:$PATH"

    local libgcc asan_runtime
    libgcc="$("$trigfuzz/bin/afl-clang-fast" -print-file-name=libgcc_s.so.1 \
        2>/dev/null | tail -n 1)"
    asan_runtime="$("$trigfuzz/bin/afl-clang-fast" \
        -print-file-name=libclang_rt.asan-x86_64.so 2>/dev/null | tail -n 1)"
    [[ -f "$libgcc" && -f "$asan_runtime" ]] || {
        echo "Could not resolve TrigFuzz compiler runtime libraries." >&2
        exit 1
    }
    runtime_library_path="$(dirname "$libgcc"):$(dirname "$asan_runtime")"
    linux_headers="$(guix build -L "$channel_dir" linux-libre-headers --no-grafts)"
    [[ -f "$linux_headers/include/linux/limits.h" ]] || {
        echo "Could not resolve Guix Linux C headers." >&2
        exit 1
    }

    # Use the same interpreter as the packaged trigfuzz wrappers (their
    # exec line carries the store python3 path).
    python_bin="$(grep -oP 'exec \K[^ ]+' "$trigfuzz/bin/trigfuzz-tcgen" | head -1 || true)"
    [[ -x "$python_bin" ]] || python_bin="$(command -v python3)"

    if [[ -n "${BUILD_INPUTS:-}" ]]; then
        printf '[+] Resolving build inputs: %s\n' "${BUILD_INPUTS}" >&2
        local resolved_paths=""
        for dep in $BUILD_INPUTS; do
            local p
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
        for p in $resolved_paths; do
            [[ -d "$p/lib" ]] && \
                runtime_library_path="$runtime_library_path:$p/lib"
        done
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
            printf '[+] Copying git checkout to %s\n' "$source_dir" >&2
            cp -r "$source_tarball" "$source_dir"
            chmod -R u+w "$source_dir"
            resolved_src_dir="$source_dir"
        else
            if [[ "$source_tarball" == *.tar.zst ]]; then
                local zstd_prefix
                zstd_prefix="$(guix build -L "$channel_dir" zstd --no-grafts \
                    2>/dev/null | while read -r candidate; do
                        [[ -x "$candidate/bin/zstd" ]] && { echo "$candidate"; break; }
                    done || true)"
                [[ -n "$zstd_prefix" && -x "$zstd_prefix/bin/zstd" ]] || {
                    echo "Could not resolve zstd to extract $source_tarball" >&2
                    exit 1
                }
                export PATH="$zstd_prefix/bin:$PATH"
            fi
            tar -xf "$source_tarball" -C "$src_dir"
        fi

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

    if [[ "$build_system" == "configure" && ! -x "$source_dir/configure" ]]; then
        if [[ -f "$source_dir/configure.in" || -f "$source_dir/configure.ac" ]]; then
            printf '[+] Running autoreconf for %s\n' "$source_dir" >&2
            local autotools old_path="$PATH" old_aclocal="${ACLOCAL_PATH:-}"
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

# ---- Step: assemble the TrigFuzz target directory ----
# The tcgen/driver expect target_dir/{source,seeds,bug_report.json}.  The
# report carries the crash site extracted by the stack step (if any).
build_target_dir() {
    require_tools
    if [[ -z "$resolved_src_dir" || ! -d "$resolved_src_dir" ]]; then
        prepare_source
    fi

    rm -rf "$target_dir"
    mkdir -p "$target_dir/seeds"
    cp -r "$resolved_src_dir" "$target_dir/source"
    chmod -R u+w "$target_dir/source"
    cp "$poc_path" "$target_dir/seeds/seed"

    local crash_json="[]"
    if [[ -s "$crash_points_file" ]]; then
        crash_json="["
        local first=1 cp
        while read -r cp; do
            [[ -z "$cp" ]] && continue
            local file="${cp%%:*}" line="${cp##*:}"
            if [[ $first -eq 1 ]]; then first=0; else crash_json="$crash_json,"; fi
            crash_json="$crash_json\"line $line in $file\""
        done < "$crash_points_file"
        crash_json="$crash_json]"
    fi
    cat >"$target_dir/bug_report.json" <<EOF
{
  "type": "benchmark-subject",
  "subject": "$BINARY",
  "guix_spec": "$GUIX_SPEC",
  "poc": "$POC_INPUT",
  "test_cmd": "$TEST_CMD",
  "crash_points": $crash_json,
  "description": "TrigFuzz benchmark subject. The PoC input crashes the $BINARY binary; the triggering condition is to be recovered from the source."
}
EOF
    printf '[+] Target directory ready: %s\n' "$target_dir" >&2
}

# ---- Step: build the ASan binary (crash-site extraction) ----
build_asan_binary() {
    local log_file="$work_dir/asan-build.log"
    local binary
    binary="$(find_binary "$asan_dir")"
    if [[ -z "$binary" ]]; then
        rm -rf "$asan_dir"
        mkdir -p "$asan_dir"
        (
            cd "$asan_dir"
            export LD_LIBRARY_PATH="$runtime_library_path${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
            export ASAN_OPTIONS="detect_leaks=0${ASAN_OPTIONS:+:$ASAN_OPTIONS}"
            local linux_inc="-isystem $linux_headers/include $build_inputs_cflags"
            CC="${CC_ASAN:-$clang_prefix/bin/clang}" \
                CXX="${CXX_ASAN:-$clang_prefix/bin/clang++}" \
                CFLAGS="-g -O0 $linux_inc $sanitizer_flags $extra_cflags" \
                CXXFLAGS="-g -O0 $linux_inc $sanitizer_flags $extra_cflags" \
                LDFLAGS="$sanitizer_flags $build_inputs_ldflags" \
                run_configure "$resolved_src_dir" &&
            make -j"$jobs" "$make_build_target" &&
            run_make_binary
        ) >"$log_file" 2>&1 || {
            tail -n 80 "$log_file" >&2
            exit 1
        }
        binary="$(find_binary "$asan_dir")"
    fi
    [[ -n "$binary" ]] || {
        echo "The ASan build did not produce $binary_basename." >&2
        exit 1
    }
    resolve_missing_libs "$binary"
    printf '%s\n' "$binary"
}

run_stack() {
    require_tools
    if [[ -z "$resolved_src_dir" || ! -d "$resolved_src_dir" ]]; then
        prepare_source
    fi
    local asan_bin crash_log status glibc_lib
    asan_bin="$(build_asan_binary)"
    # build_asan_binary ran in a command substitution (subshell); its
    # resolve_missing_libs updates to runtime_library_path were lost.
    # Re-resolve so the crash run can find project-internal shared
    # libraries (e.g. libjasper.so.1 for imginfo).
    resolve_missing_libs "$asan_bin"
    glibc_lib="$(readelf -l "$asan_bin" 2>/dev/null | \
        sed -n 's/.*\[Requesting program interpreter: \(.*\)\]/\1/p' | \
        xargs dirname 2>/dev/null || true)"

    mkdir -p "$work_dir"
    crash_log="$work_dir/crash.log"
    local -a test_args
    read -r -a test_args <<< "$TEST_CMD"
    for i in "${!test_args[@]}"; do
        [[ "${test_args[$i]}" == '@@' ]] && test_args[$i]="$poc_path"
    done

    set +e
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

    # Extract the crash site (top ASan frame) as file:line, with the path
    # relative to the source root (the crash log carries the full path).
    local site rel_site
    site="$(grep -oP '\b\w+\.(?:c|cpp|cxx|cc|c\+\+|h|hpp|hh|hxx):\d+' "$crash_log" 2>/dev/null | \
        grep -v -E '(sanitizer|compiler-rt|ubsan|asan|libc|pthread|include/)' | \
        head -1 || true)"
    if [[ -z "$site" ]]; then
        echo "Could not extract a crash site from $crash_log" >&2
        exit 1
    fi
    # Re-extract with the full path so we can relativize it.
    local full_site
    full_site="$(grep -oP '/[^ :]+\.(?:c|cpp|cxx|cc|c\+\+|h|hpp|hh|hxx):\d+' "$crash_log" 2>/dev/null | \
        grep -v -E '(sanitizer|compiler-rt|ubsan|asan|libc|pthread|include/)' | \
        head -1 || true)"
    if [[ -n "$full_site" ]]; then
        local full_file="${full_site%:*}" line="${full_site##*:}"
        if [[ "$full_file" == "$resolved_src_dir"/* ]]; then
            rel_site="${full_file#"$resolved_src_dir"/}:$line"
        else
            rel_site="$site"
        fi
    else
        rel_site="$site"
    fi
    printf '%s\n' "$rel_site" >"$crash_points_file"
    printf '[+] Crash site: %s\n' "$rel_site" >&2
    build_target_dir
}

# ---- Step: LLM-generate triggering-condition candidates ----
run_tcgen() {
    require_tools
    [[ -d "$target_dir/source" ]] || build_target_dir
    local -a src_args=()
    if [[ -s "$crash_points_file" ]]; then
        local cp
        while read -r cp; do
            [[ -z "$cp" ]] && continue
            src_args+=(--source "${cp%%:*}")
        done < "$crash_points_file"
    fi
    local k="${TRIGFUZZ_K:-3}"
    local attempts="${TRIGFUZZ_TCGEN_ATTEMPTS:-3}"
    printf '[+] Generating TC candidates (k=%s) with model %s...\n' \
        "$k" "${OPENAI_MODEL:-<unset>}" >&2
    # deepseek-v4:0731 spends a large share of its output budget on
    # reasoning; the default 4096-token cap leaves no room for the final
    # tuple text.  Raise it (the model supports 64k output tokens).
    export OPENAI_MAX_OUTPUT_TOKENS="${OPENAI_MAX_OUTPUT_TOKENS:-65536}"
    local attempt
    for ((attempt = 1; attempt <= attempts; attempt++)); do
        if "$trigfuzz/bin/trigfuzz-tcgen" "$target_dir" --k "$k" \
            "${src_args[@]}"; then
            return 0
        fi
        if [[ $attempt -lt $attempts ]]; then
            printf '[!] TC generation attempt %s/%s failed; retrying...\n' \
                "$attempt" "$attempts" >&2
            sleep 5
        fi
    done
    echo "TC generation failed after $attempts attempts." >&2
    exit 1
}

# ---- Step: v1 instrumentation (distance_instrument calls) ----
instrument_v1() {
    cat >"$work_dir/instrument_v1.py" <<'PYEOF'
import json
import pathlib
import sys

from trigfuzz.instrument import _parse_loc, instrument_v1
from trigfuzz.tcu import from_json

tcus_path, src_root, meta_path = sys.argv[1], pathlib.Path(sys.argv[2]), sys.argv[3]
data = json.loads(pathlib.Path(tcus_path).read_text())
if not data:
    sys.exit("tcus.json is empty")
# Use the first non-empty candidate set: later sets may contain
# hallucinated expressions (e.g. out-of-scope identifiers) that break
# the build, and empty sets carry nothing.
cands = [from_json(data)] if isinstance(data[0], dict) else [from_json(c) for c in data]
union = next((s for s in cands if s), [])
if not union:
    sys.exit("tcus.json contains no non-empty candidate set")

# Keep only TCUs whose loc file exists in the source tree.
kept = []
for t in union:
    try:
        fname, _ = _parse_loc(t.loc)
    except ValueError:
        print(f"[!] skipping TCU with unparseable loc: {t.loc!r}", file=sys.stderr)
        continue
    if (src_root / fname).exists():
        kept.append(t)
    else:
        print(f"[!] skipping TCU with missing file: {t.loc}", file=sys.stderr)
if not kept:
    sys.exit("no TCUs reference files present in the source tree")

next_idx = 0
for t in kept:
    t.save_index = next_idx
    next_idx += 1
instrument_v1(kept, src_root)
ins_num = len(kept)
seq_num = max((t.seq for t in kept), default=0) + 1
pathlib.Path(meta_path).write_text(f"{ins_num}\n{seq_num}\n")
print(f"[+] instrumented {ins_num} TCU(s), ins_num={ins_num} seq_num={seq_num}")
PYEOF
    PYTHONPATH="$trigfuzz/share/trigfuzz/python" "$python_bin" \
        "$work_dir/instrument_v1.py" "$target_dir/tcus.json" "$source_v1" "$meta_file"
}

# ---- Step: instrument + build the v1 target ----
build_target() {
    require_tools
    [[ -s "$target_dir/tcus.json" ]] || run_tcgen
    # A fresh 'build' invocation has no resolved_src_dir; prepare_source
    # sets it (and is a no-op when the extraction already exists).
    if [[ -z "$resolved_src_dir" || ! -d "$resolved_src_dir" ]]; then
        prepare_source
    fi
    rm -rf "$source_v1" "$v1_dir"
    # Copy from the pristine extraction (not target_dir/source) with
    # cp -a so mtimes survive: a plain cp -r resets every mtime to now,
    # which makes make's autotools regeneration rules (Makefile.in from
    # Makefile.am, aclocal.m4, configure) fire and fail when automake is
    # not on PATH.
    cp -a "$resolved_src_dir" "$source_v1"
    chmod -R u+w "$source_v1"
    chmod -R u+w "$source_v1"
    instrument_v1
    mkdir -p "$v1_dir"
    local log_file="$work_dir/build.log"
    (
        cd "$v1_dir"
        export LD_LIBRARY_PATH="$runtime_library_path${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
        export CPPFLAGS="-isystem $linux_headers/include $build_inputs_cflags${CPPFLAGS:+ $CPPFLAGS}"
        export LDFLAGS="$build_inputs_ldflags${LDFLAGS:+ $LDFLAGS}"
        CC="$trigfuzz/bin/afl-clang-fast" CXX="$trigfuzz/bin/afl-clang-fast++" \
            CFLAGS="-g -O1 -isystem $linux_headers/include $build_inputs_cflags -I$trigfuzz/share/trigfuzz/python $extra_cflags" \
            CXXFLAGS="-g -O1 -isystem $linux_headers/include $build_inputs_cflags -I$trigfuzz/share/trigfuzz/python $extra_cflags" \
            run_configure "$source_v1" &&
        make -j"$jobs" "$make_build_target" &&
        run_make_binary
    ) >"$log_file" 2>&1 || {
        tail -n 80 "$log_file" >&2
        exit 1
    }

    local built_binary
    built_binary="$(find_binary "$v1_dir")"
    [[ -n "$built_binary" ]] || {
        echo "The TrigFuzz build did not produce $binary_basename." >&2
        exit 1
    }
    cp "$built_binary" "$work_dir/$BINARY"
    resolve_missing_libs "$work_dir/$BINARY"
    printf '[+] Instrumented target written to %s\n' "$work_dir/$BINARY" >&2
}

# ---- Step: run the fuzzer ----
run_fuzzer() {
    require_tools
    local -a test_args
    if [[ -x "$work_dir/$BINARY" ]]; then
        resolve_missing_libs "$work_dir/$BINARY"
    else
        build_target
    fi
    mkdir -p "$work_dir/in" "$work_dir/out"
    cp "$poc_path" "$work_dir/in/seed"
    read -r -a test_args <<< "$TEST_CMD"

    local ins_num seq_num
    ins_num="$(sed -n '1p' "$meta_file" 2>/dev/null || true)"
    seq_num="$(sed -n '2p' "$meta_file" 2>/dev/null || true)"

    local glibc_lib
    glibc_lib="$(readelf -l "$work_dir/$BINARY" 2>/dev/null | \
        sed -n 's/.*\[Requesting program interpreter: \(.*\)\]/\1/p' | \
        xargs dirname 2>/dev/null || true)"

    local -a afl_args=(-m "${TRIGFUZZ_MEMORY_LIMIT:-none}" -t "${TRIGFUZZ_TIMEOUT:-3000}" -i in -o out -d)
    if [[ -n "$ins_num" && "$ins_num" -gt 0 ]]; then
        afl_args+=(-a "$ins_num" -s "$seq_num")
    fi
    (
        cd "$work_dir"
        export LD_LIBRARY_PATH="${glibc_lib:+$glibc_lib:}$runtime_library_path${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
        "$trigfuzz/bin/afl-fuzz" "${afl_args[@]}" -- "./$BINARY" "${test_args[@]}"
    )
}

clean() {
    rm -rf "$work_dir"
}

case "${1:-all}" in
    prepare) prepare_source ;;
    stack) run_stack ;;
    tcgen) run_tcgen ;;
    build) build_target ;;
    fuzz) run_fuzzer ;;
    all) clean; prepare_source; run_stack; run_tcgen; build_target ;;
    clean) clean ;;
    *)
        echo "Usage: $0 {prepare|stack|tcgen|build|fuzz|all|clean}" >&2
        echo "  all = prepare + stack + tcgen + build (run 'fuzz' separately)" >&2
        exit 2
        ;;
esac
