;;; Packages for software fuzzing
;;;
;;; SPDX-FileCopyrightText: 2024-2026 Nguyễn Gia Phong
;;; SPDX-License-Identifier: GPL-3.0-or-later

(define-module (loftix fuzzing)
  #:use-module (gnu packages)
  #:use-module (gnu packages c)
  #:use-module (gnu packages check)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages debug)
  #:use-module (gnu packages digest)
  #:use-module (gnu packages glib)
  #:use-module (gnu packages instrumentation)
  #:use-module (gnu packages llvm)
  #:use-module (gnu packages man)
  #:use-module (gnu packages m4)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-build)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages rust-apps)
  #:use-module (guix build-system cmake)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system pyproject)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages)
  #:use-module (guix utils)
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
      (native-inputs (list pkg-config))
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
                (("\\<os\\.path\\.join\\(SCRIPT_DIR, \".+-showmap\"\\)")
                 (simple-format #f "~s"
                   (search-input-file inputs "bin/fuzzolic-showmap")))
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
  (let ((base-version "3.13a")
        (commit "07d4bc1ed1578134ea105d3eac8b2f1b51cce0dc")
        (revision "targeted"))
    (hidden-package
      (package
        (inherit aflplusplus)
        (name "aflplusplus-for-binradar")
        (version (git-version base-version revision commit))
        (source
         (origin
           (method git-fetch)
           (uri (git-reference
                 (url "https://github.com/hsh814/AFLplusplus")
                 (commit commit)))
           (file-name (git-file-name name version))
           (sha256
            (base32 "0mnh767w7c20k07ck6ncyl48kcp82xap4ysy1g0wphx9rkrsm14p"))
           (modules '((guix build utils)))
           (snippet #~(substitute* "GNUmakefile"
                        (("^install: .*") "install: binary-only\n")
                        (("^\tinstall .* afl-as.*") "")
                        (("^\tln .* afl-as .*") "")
                        (("@echo 'main") "@echo 'int main")))))
        (arguments
         (substitute-keyword-arguments arguments
           ((#:phases phases '%standard-phases)
            #~(modify-phases #$phases
                (replace 'build
                  (lambda* (#:key make-flags parallel-build?
                            #:allow-other-keys)
                    (apply invoke "make"
                           (append make-flags
                                   (if parallel-build?
                                       (list "-j" (number->string
                                                   (parallel-job-count)))
                                       '())
                                   '("binary-only")))))))
           ((#:tests? _ #t)
            #f)))
        (inputs (modify-inputs inputs
                  (replace "clang" clang-13)
                  (replace "lld" lld-13)
                  (replace "llvm" llvm-13)
                  (replace "qemu" qemu-for-aflplusplus-for-binradar)))))))

(define-public aflplusplus-for-binradar-stacktrace
  (let ((base-version "3.13a")
        (commit "14cd46bb8d70d136426cbe3fb7ab734a1c15ce8e")
        (revision "binradar"))
    (hidden-package
      (package
        (inherit aflplusplus-for-binradar)
        (name "aflplusplus-for-binradar-stacktrace")
        (version (git-version base-version revision commit))
        (source
         (origin
           (inherit (package-source aflplusplus-for-binradar))
           (uri (git-reference
                 (url "https://github.com/hsh814/AFLplusplus")
                 (commit commit)))
           (file-name (git-file-name name version))
           (sha256
            (base32 "1n6yrfkcqg7zgjfsmnvykpyqcwil1ppq92097rmnc47gdbd1wfif"))))
        (inputs (modify-inputs inputs
                  (replace "qemu" qemu-for-binradar-stacktrace)))))))

(define-public binradar-solver
  (let ((commit "d8ccb69b2be1e54fd7bb3907b8bb7bae29e27684")
        (revision "5"))
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
         (file-name (git-file-name "binradar" version))
         (sha256
          (base32 "0p2da086cp5i93p1v2paq1l3xlbk0s7ij9l6pz43w434f99ikndg"))
         (patches
          (search-patches "patches/binradar-solver-unbundle.patch"
                          "patches/fuzzolic-solver-install.patch"))
         (modules '((guix build utils)))
         (snippet #~(delete-file-recursively "solver/libsbsv"))))
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
       (patches (search-patches "patches/binradar-python-package.patch"))
       (snippet #~(rename-file "benchmarks" "fuzzolic/benchmarks"))))
    (arguments
     (substitute-keyword-arguments arguments
       ((#:phases phases #~%standard-phases)
        #~(modify-phases #$phases
            (replace 'patch-paths
              (lambda* (#:key inputs #:allow-other-keys)
                (substitute* '("fuzzolic/binradar.py"
                               "fuzzolic/binradar-test.py"
                               "fuzzolic/testcase_checker.py"
                               "utils/coverage_tracer.py")
                  (("^(TRACER_BIN = ).*" _ assign)
                   (simple-format #f "~a~s\n"
                     assign (search-input-file inputs "bin/qemu-x86_64"))))
                (substitute* "fuzzolic/binradar.py"
                  (("^(SOLVER_SMT_BIN = ).*" _ assign)
                   (simple-format #f "~a~s\n"
                     assign (search-input-file inputs "bin/solver-smt")))
                  (("^(SOLVER_FUZZY_BIN = ).*" _ assign)
                   (simple-format #f "~a~s\n"
                     assign (search-input-file inputs "bin/solver-fuzzy")))
                  (("^(FIND_MODELS_BIN = ).*" _ assign)
                   (simple-format #f "~a~s\n"
                     assign (search-input-file
                             inputs "bin/fuzzolic-find-models-addrs"))))
                (substitute* "fuzzolic/binradar_fuzzer.py"
                  (("os\\.path\\.join\\(AFL_PATH, \"afl-fuzz\"\\)")
                   (simple-format #f "~s"
                     (search-input-file inputs "bin/afl-fuzz"))))
                (substitute* "fuzzolic/binradar_setup.py"
                  (("\"just\"")
                   (simple-format #f "~s"
                     (search-input-file inputs "bin/just"))))
                (substitute* '("fuzzolic/binradar_setup.py"
                               "fuzzolic/binradar_verifier.py")
                  (("^(QEMU_STACKTRACE_RELEASE = ).*" _ assign)
                   (simple-format #f "~a~s\n"
                     assign (string-append
                             #$(this-package-input
                                "aflplusplus-for-binradar-stacktrace")
                             "/bin/afl-qemu-trace"))))
                (substitute* "fuzzolic/run_afl_fuzzolic.py"
                  (("^(AFL_BIN = ).*" _ assign)
                   (simple-format #f "~a~s\n"
                     assign (search-input-file inputs "bin/afl-fuzz")))
                  (("^(FUZZOLIC_BIN = ).*" _ assign)
                   (simple-format #f "~a~s\n"
                     assign (string-append #$output "bin/binradar"))))))
            (delete 'validate-runpath)))
       ((#:tests? _ #t)
        #f)))
    (inputs (modify-inputs inputs
              (prepend aflplusplus-for-binradar
                       aflplusplus-for-binradar-stacktrace
                       binradar-solver
                       binradar-utils
                       just
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
