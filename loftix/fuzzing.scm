;;; Packages for software fuzzing
;;;
;;; SPDX-FileCopyrightText: 2024-2026 Nguyễn Gia Phong
;;; SPDX-License-Identifier: GPL-3.0-or-later

(define-module (loftix fuzzing)
  #:use-module (srfi srfi-1)
  #:use-module (gnu packages)
  #:use-module (gnu packages c)
  #:use-module (gnu packages check)
  #:use-module (gnu packages cmake)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages debug)
  #:use-module (gnu packages digest)
  #:use-module (gnu packages glib)
  #:use-module (gnu packages boost)
  #:use-module (gnu packages graphviz)
  #:use-module (gnu packages instrumentation)
  #:use-module (gnu packages man)
  #:use-module (gnu packages m4)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-build)
  #:use-module (gnu packages python-web)
  #:use-module (gnu packages python-xyz)
  #:use-module (guix build-system cmake)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system pyproject)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages)
  #:use-module (guix utils)
  #:use-module (gnu packages llvm)
  #:use-module (loftix deduction)
  #:use-module (loftix emulation))

(define-public afl-dyninst
  (package
    (name "afl-dyninst")
    (version "1.0.0")
    (source
      (origin
        (method url-fetch)
        (uri (string-append
               "https://trong.loang.net/~cnx/afl-dyninst/snapshot/afl-dyninst-"
               version ".tar.gz"))
        (sha256
          (base32 "13gxrsn2fwh5qazqy142v6g7mxhwfpq4f07h05fd1w4r46yh1v00"))))
    (build-system gnu-build-system)
    (arguments
      (list #:make-flags
            #~(list (string-append "DYNINST_LIB="
                                   (assoc-ref %build-inputs "dyninst")
                                   "/lib")
                    (string-append "PREFIX=" #$output))
            #:phases #~(modify-phases %standard-phases
                         (delete 'configure)
                         (delete 'check))))
    (native-inputs (list m4 help2man))
    (inputs (list aflplusplus dyninst))
    (synopsis "Dyninst integration for AFL++")
    (description "Dyninst integration for AFL++")
    (home-page "https://trong.loang.net/~cnx/afl-dyninst")
    (license (list license:agpl3+ license:asl2.0))))

(define-public fuzzolic-showmap
  (hidden-package
   (package
     (inherit aflplusplus)
     (name "fuzzolic-showmap")
     (source (origin
               (inherit (package-source aflplusplus))
               (file-name (git-file-name name (package-version aflplusplus)))
               (patches (search-patches "patches/fuzzolic-showmap.patch"))))
     (arguments
      (substitute-keyword-arguments arguments
        ((#:phases phases #~%standard-phases)
         #~(modify-phases #$phases
             (replace 'install
               (lambda* (#:key outputs #:allow-other-keys)
                 (let* ((dir (string-append (assoc-ref outputs "out")
                                            "/bin"))
                        (file (string-append dir "/fuzzolic-showmap")))
                   (mkdir-p dir)
                   (copy-file "afl-showmap" file)))))))))))

(define-public fuzzolic-solver
  (let ((commit "39937821d5360b139f026f09e2019f214a4929c1")
        (revision "0"))
    (package
      (name "fuzzolic-solver")
      (version (git-version "0" revision commit))
      (source
       (origin
         (method git-fetch)
         (uri (git-reference
               (url "https://github.com/season-lab/fuzzolic")
               (commit commit)))
         (file-name (git-file-name "fuzzolic" version))
         (sha256
          (base32
           "0wh452qzia97i34hvxjj8x38wb9h6x51zsjkzdvpfpj5zbpdv495"))
         (patches (search-patches
                   "patches/fuzzolic-solver-unbundle.patch"
                   "patches/fuzzolic-solver-install.patch"))))
      (build-system cmake-build-system)
      (arguments '(#:configure-flags '("-S" "../source/solver")
                   #:tests? #f))
      (native-inputs (list pkg-config which))
      (inputs (list fuzzy-sat
                    glib
                    qemu-for-fuzzolic
                    xxhash
                    z3-for-fuzzolic))
      (home-page "https://season-lab.github.io/fuzzolic")
      (synopsis "Fuzzy constraint solver for FUZZOLIC")
      (description "FUZZOLIC is a concolic executor based on QEMU.

It can instrument binary programs at runtime in order to build
symbolic expressions and queries.  To reduce the runtime overhead
and improve accuracy of the queries, it devises three analysis modes
that are dynamically enabled during the program execution based on
the running context.

Moreover, differently from other concolic executors,
FUZZOLIC runs the solver component, which reasons over the symbolic queries
generated when analyzing a program, inside another process to reduce
execution interferences that may be caused by the solver
and negatively affect the analyzed application.")
      (license license:gpl2+))))

(define-public fuzzolic-utils
  (package/inherit fuzzolic-solver
    (name "fuzzolic-utils")
    (source
     (origin
       (inherit (package-source fuzzolic-solver))
       (patches (search-patches "patches/fuzzolic-utils-make.patch"))))
    (build-system gnu-build-system)
    (arguments
     (list #:make-flags #~(list (string-append "CC=" #$(cc-for-target))
                                (string-append "PREFIX=" #$output))
           #:phases #~(modify-phases %standard-phases
                        (delete 'configure)
                        (delete 'check))))
    (inputs (list python))
    (synopsis "CLI utilities for FUZZOLIC")))

(define-public fuzzolic
  (package/inherit fuzzolic-solver
    (name "fuzzolic")
    (source
     (origin
       (inherit (package-source fuzzolic-solver))
       (snippet #~(call-with-output-file "pyproject.toml"
                    (lambda (port)
                      (simple-format port "
[build-system]
requires = ['flit_core >=3.2']
build-backend = 'flit_core.buildapi'

[project]
name = 'fuzzolic'
version = '0'
description = '''~a
'''

[project.scripts]
fuzzolic = 'fuzzolic.fuzzolic:main'
fuzzolic-with-afl = 'fuzzolic.run_afl_fuzzolic:main'
" #$(package-description fuzzolic-solver)))))
       (patches (search-patches
                 "patches/fuzzolic-python-package.patch"
                 "patches/fuzzolic-relax-perf-test.patch"
                 "patches/fuzzolic-test-fix-runner.patch"
                 "patches/fuzzolic-test-skip-nondeterministic.patch"))))
    (build-system pyproject-build-system)
    (arguments
     (list
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'patch-paths
            (lambda* (#:key inputs #:allow-other-keys)
              (substitute* "fuzzolic/executor.py"
                (("^(SOLVER_SMT_BIN = ).*" _ assign)
                 (simple-format #f "~a~s\n"
                   assign (search-input-file inputs "bin/solver-smt")))
                (("^(SOLVER_FUZZY_BIN = ).*" _ assign)
                 (simple-format #f "~a~s\n"
                   assign (search-input-file inputs "bin/solver-fuzzy")))
                (("\\<SCRIPT_DIR \\+ \"/find_models_addrs\\.py\"")
                 (simple-format #f "~s" (search-input-file inputs
                                         "bin/fuzzolic-find-models-addrs"))))
              (substitute* '("fuzzolic/executor.py"
                             "fuzzolic/minimizer.py"
                             "fuzzolic/testcase_checker.py")
                (("^(TRACER_BIN = ).*" _ assign)
                 (simple-format #f "~a~s\n"
                   assign (search-input-file inputs "bin/qemu-x86_64"))))
              (substitute* "fuzzolic/minimizer_qsym.py"
                (("^( +self\\.showmap = ).*" _ assign)
                 (simple-format #f "~a~s\n"
                   assign (search-input-file inputs "bin/afl-showmap")))
                (("^( +self\\.showmap_fork = ).*" _ assign)
                 (simple-format #f "~a~s\n"
                   assign (search-input-file inputs "bin/fuzzolic-showmap")))
                (("\\<SCRIPT_DIR \\+ '.+/merge_bitmap'")
                 (simple-format #f "~s" (search-input-file inputs
                                         "bin/fuzzolic-merge-bitmap"))))
              (substitute* "fuzzolic/run_afl_fuzzolic.py"
                (("^(AFL_BIN = ).*" _ assign)
                 (simple-format #f "~a~s\n"
                   assign (search-input-file inputs "bin/afl-fuzz")))
                (("^(FUZZOLIC_BIN = ).*" _ assign)
                 (simple-format #f "~a~s\n"
                   assign (string-append #$output "/bin/afl-fuzz"))))))
          (replace 'check
            (lambda* (#:key tests? #:allow-other-keys)
              (when tests?
                (invoke "make" "-C" "tests")
                (invoke "pytest" "-vv" "tests/run.py" "--fuzzy")
                (invoke "pytest" "-vv" "tests/run.py")))))))
    (native-inputs (list python-flit-core python-pytest))
    (inputs (list aflplusplus
                  fuzzolic-showmap
                  fuzzolic-solver
                  fuzzolic-utils
                  qemu-for-fuzzolic))
    (synopsis "Concolic fuzzer")))

(define-public aflplusplus-for-binradar
  (hidden-package
    ;; FIXME: binradar needs a target address reach detection patch:
    ;; https://github.com/hsh814/AFLplusplus/commit/4f7fc3727b39
    (package/inherit aflplusplus
      (name "aflplusplus-for-binradar")
      (inputs (modify-inputs inputs
                (replace "qemu" qemu-for-aflplusplus-for-binradar))))))

(define-public binradar-solver
  (let ((commit "3e4a50cfa015d08852cb9eac460112a82606bc4c")
        (revision "1"))
    (package
      (inherit fuzzolic-solver)
      (name "binradar-solver")
      (version (git-version "0.1.0" revision commit))
      (source
       (origin
         (method git-fetch)
         (uri (git-reference
               (url "https://github.com/UNIST-LOFT/binradar")
               (commit commit)))
         (file-name (git-file-name name version))
         (sha256
          (base32 "0m1ckp780qwkspn8iycvwd3drngxc13n49a61855d4myvqqyrvdv"))
         (patches
          (search-patches "patches/binradar-solver-unbundle.patch"
                          "patches/fuzzolic-solver-install.patch"))))
      (inputs
       (modify-inputs inputs
         (prepend c-sbsv
                  qemu-for-binradar)
         (delete "qemu-for-fuzzolic")))
      (synopsis "Fuzzy constraint solver for BinRadar"))))

(define-public binradar-utils
  (package
    (inherit fuzzolic-utils)
    (name "binradar-utils")
    (version (package-version binradar-solver))
    (source
     (origin
       (inherit (package-source binradar-solver))
       (patches (search-patches "patches/binradar-utils-make.patch"))))
    (synopsis "CLI utilities for BinRadar")))

(define-public binradar
  (package
    (inherit fuzzolic)
    (name "binradar")
    (version (package-version binradar-solver))
    (source
     (origin
       (inherit (package-source binradar-solver))
       (patches (search-patches "patches/binradar-python-package.patch"))))
    (arguments
     (substitute-keyword-arguments arguments
       ((#:phases phases #~%standard-phases)
        #~(modify-phases #$phases
            (add-after 'patch-paths 'patch-more-paths
              (lambda* (#:key inputs #:allow-other-keys)
                (substitute* "fuzzolic/binradar.py"
                  (("^(SOLVER_SMT_BIN = ).*" _ assign)
                   (simple-format #f "~a~s\n"
                     assign (search-input-file inputs "bin/solver-smt")))
                  (("^(TRACER_BIN = ).*" _ assign)
                   (simple-format #f "~a~s\n"
                     assign (search-input-file inputs "bin/qemu-x86_64")))
                  (("^(FIND_MODELS_BIN = ).*" _ assign)
                   (simple-format #f "~a~s\n"
                     assign (search-input-file
                             inputs "bin/fuzzolic-find-models-addrs"))))
                (substitute* "fuzzolic/binradar_fuzzer.py"
                  (("os\\.path\\.join\\(AFL_PATH, \"afl-fuzz\"\\)")
                   (simple-format #f "~s"
                     (search-input-file inputs "bin/afl-fuzz"))))
                (substitute* "fuzzolic/binradar_verifier.py"
                  (("^(QEMU_STACKTRACE_RELEASE = ).*" _ assign)
                   (simple-format #f "~a~s\n"
                     assign (search-input-file
                             inputs "bin/afl-qemu-trace"))))))))
       ((#:tests? _ #t)
        #f)))
    (inputs (modify-inputs inputs
              (prepend aflplusplus-for-binradar
                       binradar-solver
                       binradar-utils
                       python-sbsv
                       python-sortedcontainers
                       qemu-for-binradar)
              (delete "fuzzolic-solver"
                      "fuzzolic-utils"
                      "qemu-for-fuzzolic")))
    (home-page "https://github.com/UNIST-LOFT/binradar")
    (synopsis "Binary patch verification tool")
     (description
      "Binradar is a binary patch verification tool
using PoC-bounded under-constrained concolic execution.")))

(define-public sdfuzz
  (let ((commit "e8f5b1750b4ae0a2babcc27ad1b40cc1b3494886")
        (revision "0"))
    (package
      (name "sdfuzz")
      (version (git-version "2.52b" revision commit))
      (source
       (origin
         (method git-fetch)
         (uri (git-reference
               (url "https://github.com/cuhk-seclab/sdfuzz")
               (commit commit)))
          (patches (search-patches "patches/sdfuzz-llvm-13.patch"
                                  "patches/sdfuzz-scripts.patch"
                                  "patches/sdfuzz-crash-seeds.patch"
                                  "patches/sdfuzz-stackparser.patch"))
         (file-name (git-file-name name version))
         (sha256
          (base32
           "0mhfwm1h8wpszpd969rm9rhn73ylprc44gdcrnbfqh278cyib0cq"))))
      (build-system gnu-build-system)
      (arguments
       (list #:make-flags
             #~(list (string-append "CC=" #$(cc-for-target))
                     (string-append "PREFIX=" #$output)
                     "AFL_NO_X86=1")
             #:phases
             #~(modify-phases %standard-phases
                 (delete 'configure)
                 (delete 'check)
                 (add-after 'build 'build-llvm-components
                    (lambda* (#:key inputs #:allow-other-keys)
                       (let ((llvm-dir (string-append
                                        (assoc-ref inputs "llvm") "/bin"))
                             (clang-dir (string-append
                                         (assoc-ref inputs "clang") "/bin")))
                         (setenv "PATH" (string-append llvm-dir ":" clang-dir ":"
                                                       (getenv "PATH"))))
                      (let ((llvm-config (string-append
                                          (assoc-ref inputs "llvm")
                                          "/bin/llvm-config"))
                            (cc (string-append
                                 (assoc-ref inputs "clang")
                                 "/bin/clang"))
                            (cxx (string-append
                                  (assoc-ref inputs "clang")
                                  "/bin/clang++")))
                        (substitute* "llvm_mode/Makefile"
                          (("which \\$\\(LLVM_CONFIG\\)")
                           "test -x $(LLVM_CONFIG)")
                          (("which \\$\\(CC\\)")
                           "test -x $(CC)")
                          (("which \\$\\(CXX\\)")
                           "test -x $(CXX)"))
                         (invoke "make" "-C" "llvm_mode"
                                 (string-append "LLVM_CONFIG=" llvm-config)
                                 (string-append "CC=" cc)
                                 (string-append "CXX=" cxx)
                           (string-append "PREFIX=" #$output)
                                 "clean" "all")
                        (invoke "make" "-C" "instr"
                          (string-append "LLVM_CONFIG=" llvm-config)
                          (string-append "CXX=" cxx)
                          "clean" "all")
                        (invoke "make" "-C" "libdislocator"
                          "CC=gcc" "all")
                        (invoke "make" "-C" "libtokencap"
                          "CC=gcc" "all"))))
                 (add-after 'install 'install-extra
                   (lambda* (#:key inputs outputs #:allow-other-keys)
                     (let* ((out (assoc-ref outputs "out"))
                            (bin (string-append out "/bin"))
                            (lib (string-append out "/lib/afl"))
                            (doc (string-append out "/share/doc/afl"))
                            (scripts (string-append out "/share/sdfuzz/scripts"))
                            (python-bin (search-input-file inputs "bin/python3"))
                            (shell (search-input-file inputs "bin/sh"))
                            (pythonpath
                             (string-append
                              #$(file-append
                                  python-networkx
                                  (string-append
                                   "/lib/python"
                                   (version-major+minor
                                    (package-version python))
                                   "/site-packages"))
                              ":"
                              #$(file-append
                                  python-pydot
                                  (string-append
                                   "/lib/python"
                                   (version-major+minor
                                    (package-version python))
                                   "/site-packages")))))
                       (install-file "fuzzopt.so" lib)
                       (install-file
                        "libdislocator/libdislocator.so" lib)
                       (install-file
                        "libtokencap/libtokencap.so" lib)
                       (install-file
                        "libdislocator/README.dislocator" doc)
                       (install-file
                        "libtokencap/README.tokencap" doc)
                       (copy-recursively "scripts" scripts)
                       (for-each
                        (lambda (spec)
                          (let ((name (car spec))
                                (interpreter (cdr spec)))
                            (let ((wrapper (string-append bin "/" name)))
                            (with-output-to-file wrapper
                              (lambda _
                                (format #t
                                        "#!~a~%export PYTHON=~s~%export PYTHONPATH=~a${PYTHONPATH:+:$PYTHONPATH}~%export LLVM_OPT=~s~%export SDFUZZ_PREFIX=~s~%exec ~s ~s \"$@\"~%"
                                        shell
                                        python-bin
                                        pythonpath
                                        (search-input-file inputs "bin/opt")
                                        out
                                        interpreter
                                        (string-append scripts "/" name))))
                              (chmod wrapper #o555))))
                        `(("Stackparser.py" . ,python-bin)
                          ("BBmapping.py" . ,python-bin)
                          ("genDistance.sh" . ,shell)))
                       (let ((lld-wrapper (string-append bin "/sdfuzz-ld.lld")))
                         (with-output-to-file lld-wrapper
                           (lambda _
                             (format #t "#!~a~%exec ~s \"$@\"~%"
                                     shell
                                     (search-input-file inputs "bin/ld.lld"))))
                         (chmod lld-wrapper #o555))))))))
      (inputs (list clang-13 llvm-13 lld-13 python python-networkx python-pydot))
      (home-page "https://github.com/cuhk-seclab/sdfuzz")
      (synopsis "Target states driven directed fuzzer")
      (description
       "SDFuzz is a directed fuzzing tool driven by target states.
It leverages selective instrumentation and early termination,
combined with distance metrics to optimize fuzzing efficiency.")
      (license license:asl2.0))))

;; Transitive propagated Python inputs of python-openai (the OpenAI SDK
;; imports pydantic/httpx/typing-extensions/... at runtime) plus the
;; distance-script dependencies, for the trigfuzz wrapper PYTHONPATH.
(define (trigfuzz-python-deps)
  (delete-duplicates
   (append
    (map (lambda (input) (cadr input))
         (package-transitive-propagated-inputs python-openai))
    (list python-openai python-networkx python-pydot))))

(define python-site-suffix
  (string-append "/lib/python"
                 (version-major+minor (package-version python))
                 "/site-packages"))

(define trigfuzz-pypath
  #~(string-join
     (list #$@(map (lambda (dep)
                     (file-append dep python-site-suffix))
                   (trigfuzz-python-deps)))
     ":"))

(define-public trigfuzz
  (let ((commit "45f5a5175ff100a19c0582860b3cce97c9068794")
        (revision "0"))
    (package
      (name "trigfuzz")
      (version (git-version "2.57b" revision commit))
      (source
       (origin
         (method git-fetch)
         (uri (git-reference
               (url "https://github.com/vul337/TrigFuzz.git")
               (commit commit)))
         (file-name (git-file-name name version))
         (sha256
          (base32
           "1nz3x58b6drj1sn198spkq2bd09incqml1aaadwlvd9gqmpdixa9"))
         (patches (search-patches "patches/trigfuzz-crash-seeds.patch"
                                  "patches/trigfuzz-llvm-13.patch"
                                  "patches/trigfuzz-scripts.patch"
                                  "patches/trigfuzz-instrument-include.patch"))
         ;; Only the AFLGo engine + shared tooling are built; drop the
         ;; heavyweight bundled AFL++ tree to avoid unpacking it.
         (modules '((guix build utils)))
         (snippet
          #~(delete-file-recursively "engines/aflplusplus-selective"))))
      (build-system gnu-build-system)
      (arguments
       (list #:make-flags
             #~(list (string-append "CC=" #$(cc-for-target))
                     (string-append "PREFIX=" #$output)
                     "AFL_NO_X86=1")
             #:tests? #f
             #:phases
             #~(modify-phases %standard-phases
                 (delete 'configure)
                 ;; Build inside the AFLGo engine subtree.
                 (add-before 'build 'chdir-engine
                   (lambda _ (chdir "engines/aflgo-trigfuzz/afl-2.57b")))
                 (add-after 'build 'build-llvm-components
                   (lambda* (#:key inputs outputs #:allow-other-keys)
                     (let* ((llvm-dir (string-append
                                       (assoc-ref inputs "llvm") "/bin"))
                            (clang-dir (string-append
                                        (assoc-ref inputs "clang") "/bin"))
                            (llvm-config (string-append
                                          (assoc-ref inputs "llvm")
                                          "/bin/llvm-config"))
                            (cc (string-append
                                 (assoc-ref inputs "clang") "/bin/clang"))
                            (cxx (string-append
                                  (assoc-ref inputs "clang") "/bin/clang++")))
                       (setenv "PATH" (string-append llvm-dir ":" clang-dir ":"
                                                     (getenv "PATH")))
                       ;; llvm_mode + instrument: same Makefile `which`-fix
                       ;; as sdfuzz.
                       (substitute* '("llvm_mode/Makefile"
                                      "../instrument/Makefile")
                         (("which \\$\\(LLVM_CONFIG\\)") "test -x $(LLVM_CONFIG)")
                         (("which \\$\\(CC\\)") "test -x $(CC)")
                         (("which \\$\\(CXX\\)") "test -x $(CXX)"))
                       (invoke "make" "-C" "llvm_mode"
                               (string-append "LLVM_CONFIG=" llvm-config)
                               (string-append "CC=" cc)
                               (string-append "CXX=" cxx)
                               (string-append "PREFIX=" #$output)
                               "clean" "all")
                       ;; instrument/: aflgo-clang + aflgo-pass.so + runtime.
                       (invoke "make" "-C" "../instrument"
                               (string-append "LLVM_CONFIG=" llvm-config)
                               (string-append "CC=" cc)
                               (string-append "CXX=" cxx)
                               (string-append "PREFIX=" #$output)
                               "clean" "all")
                       ;; distance_calculator binary (distance.bin).
                       (invoke "cmake" "-S" "../distance/distance_calculator"
                               "-B" "../distance/distance_calculator/build"
                               "-DCMAKE_POLICY_VERSION_MINIMUM=3.5")
                       (invoke "cmake" "--build"
                               "../distance/distance_calculator/build")
                       (invoke "make" "-C" "libdislocator" "CC=gcc" "all")
                       (invoke "make" "-C" "libtokencap" "CC=gcc" "all"))))
                 (replace 'install
                   (lambda* (#:key inputs outputs #:allow-other-keys)
                     (let* ((out (assoc-ref outputs "out"))
                            (bin (string-append out "/bin"))
                            (lib (string-append out "/lib/afl"))
                            (doc (string-append out "/share/doc/afl"))
                            (eng (string-append out "/share/trigfuzz/engine"))
                            (scripts (string-append out "/share/trigfuzz/scripts"))
                            (pyroot (string-append out "/share/trigfuzz/python"))
                            (python-bin (search-input-file inputs "bin/python3"))
                            (shell (search-input-file inputs "bin/sh"))
                            (pypath #$trigfuzz-pypath))
                       ;; AFL core binaries (afl-fuzz, afl-gcc, afl-showmap, ...).
                       (install-file "afl-fuzz" bin)
                       (install-file "afl-gcc" bin)
                       (install-file "afl-showmap" bin)
                       (install-file "afl-tmin" bin)
                       (install-file "afl-analyze" bin)
                       (install-file "afl-as" bin)
                       ;; afl-gcc locates its assembler wrapper as
                       ;; $AFL_PATH/as (or $dir/afl-as); provide both names.
                       (symlink "afl-as" (string-append bin "/as"))
                       (for-each (lambda (s) (install-file s bin))
                                 '("afl-g++" "afl-clang" "afl-clang++"))
                       ;; LLVM fast compiler + pass + runtime objects.
                       (install-file "afl-clang-fast" bin)
                       (symlink "afl-clang-fast" (string-append bin "/afl-clang-fast++"))
                       ;; afl-clang-fast locates its pass/runtime via AFL_PATH
                       ;; or its own binary dir; make both resolve.
                       (symlink "../lib/afl/afl-llvm-pass.so" (string-append bin "/afl-llvm-pass.so"))
                       (symlink "../lib/afl/afl-llvm-rt.o" (string-append bin "/afl-llvm-rt.o"))
                       (symlink "../lib/afl/afl-llvm-rt-64.o" (string-append bin "/afl-llvm-rt-64.o"))
                       (install-file "afl-llvm-pass.so" lib)
                       (install-file "afl-llvm-rt.o" lib)
                       (install-file "afl-llvm-rt-64.o" lib)
                       ;; AFLGo instrument pass + runtime.
                       (install-file "../instrument/aflgo-clang" bin)
                       (symlink "aflgo-clang" (string-append bin "/aflgo-clang++"))
                       (install-file "../instrument/aflgo-pass.so" lib)
                       (install-file "../instrument/aflgo-runtime.o" lib)
                       (install-file "../instrument/aflgo-runtime-64.o" lib)
                       ;; Dislocator/tokencap preload libs.
                       (install-file "libdislocator/libdislocator.so" lib)
                       (install-file "libtokencap/libtokencap.so" lib)
                       (install-file "libdislocator/README.dislocator" doc)
                       (install-file "libtokencap/README.tokencap" doc)
                       ;; distance calculator + scripts.
                       (install-file
                        "../distance/distance_calculator/build/distance.bin"
                        (string-append scripts "/distance.bin"))
                       (copy-recursively "../distance" scripts)
                       ;; Runtime header so targets can #include "distance.h".
                       (install-file "../../../distance.h" eng)
                       (install-file "config.h" eng)
                       ;; AFLGO=.../engine layout for aflgo-clang: it locates
                       ;; its pass/runtime via $AFLGO/instrument/.
                       (mkdir-p (string-append eng "/instrument"))
                       (install-file "../instrument/aflgo-pass.so"
                                     (string-append eng "/instrument"))
                       (install-file "../instrument/aflgo-runtime.o"
                                     (string-append eng "/instrument"))
                       (install-file "../instrument/aflgo-runtime-64.o"
                                     (string-append eng "/instrument"))
                       ;; Python tooling (trigfuzz package).
                       (copy-recursively "../../../trigfuzz"
                                         (string-append pyroot "/trigfuzz"))
                       ;; The driver resolves REPO_ROOT as parents[1] of the
                       ;; package dir (= pyroot) and compiles with -I REPO_ROOT
                       ;; for distance.h; install it there.
                       (install-file "../../../distance.h" pyroot)
                       (install-file "../../../distance.h"
                                     (string-append pyroot "/../include"))
                       ;; Wrappers: distance scripts + tcgen/driver, mirroring
                       ;; the sdfuzz wrapper pattern (PYTHONPATH, prefix env).
                       (for-each
                        (lambda (spec)
                          (let* ((name (car spec))
                                 (interp (cdr spec))
                                 (real (string-append scripts "/" name))
                                 (wrapper (string-append bin "/" name)))
                            (with-output-to-file wrapper
                              (lambda _
                                (format #t
                                        "#!~a~%export PYTHONPATH=~a${PYTHONPATH:+:$PYTHONPATH}~%export TRIGFUZZ_PREFIX=~s~%export LLVM_OPT=~s~%exec ~s ~s \"$@\"~%"
                                        shell pypath out
                                        (search-input-file inputs "bin/opt")
                                        interp real)))
                            (chmod wrapper #o555)))
                        `(("gen_distance_orig.sh" . ,shell)
                          ("gen_distance_fast.py" . ,python-bin)))
                       ;; Python module entry-point wrappers.
                       (for-each
                        (lambda (spec)
                          (let* ((mod (car spec))
                                 (wrapper (string-append bin "/" (cdr spec))))
                            (with-output-to-file wrapper
                              (lambda _
                                (format #t
                                        "#!~a~%export PYTHONPATH=~a:~a${PYTHONPATH:+:$PYTHONPATH}~%export OPENAI_API_KEY=\"${OPENAI_API_KEY:-}\"~%export OPENAI_MODEL=\"${OPENAI_MODEL:-}\"~%export OPENAI_API_BASE_URL=\"${OPENAI_API_BASE_URL:-}\"~%exec ~s -B -m ~s \"$@\"~%"
                                        shell pypath pyroot python-bin mod)))
                            (chmod wrapper #o555)))
                        '(("trigfuzz.tcgen" . "trigfuzz-tcgen")
                          ("trigfuzz.driver" . "trigfuzz-driver")))
                       ;; ld.lld wrapper (LLVM 13 gold/LTO linker).
                       (let ((lld-wrapper (string-append bin "/trigfuzz-ld.lld")))
                         (with-output-to-file lld-wrapper
                           (lambda _
                             (format #t "#!~a~%exec ~s \"$@\"~%"
                                     shell (search-input-file inputs "bin/ld.lld"))))
                         (chmod lld-wrapper #o555))))))))
      (native-inputs (list cmake))
      (inputs (list clang-13 llvm-13 lld-13 boost python
                    python-networkx python-pydot python-openai))
      (home-page "https://github.com/vul337/TrigFuzz")
      (synopsis "Triggering-conditions guided directed fuzzer")
      (description
       "TrigFuzz is a directed fuzzing tool that leverages LLMs to extract
vulnerability triggering conditions for PoC generation.  It is built on
AFLGo and adds triggering-distance feedback scheduling and optional
byte-aware mutation.  This package provides the AFLGo-based engine, the
LLM-driven triggering-condition generator, and the distance-computation
scripts.")
      (license license:asl2.0))))
