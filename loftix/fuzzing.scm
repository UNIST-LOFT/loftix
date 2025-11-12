;;; Packages for software fuzzing
;;;
;;; SPDX-FileCopyrightText: 2024-2025 Nguyễn Gia Phong
;;; SPDX-License-Identifier: GPL-3.0-or-later

(define-module (loftix fuzzing)
  #:use-module (gnu packages)
  #:use-module (gnu packages check)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages debug)
  #:use-module (gnu packages digest)
  #:use-module (gnu packages glib)
  #:use-module (gnu packages instrumentation)
  #:use-module (gnu packages man)
  #:use-module (gnu packages m4)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-build)
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
  #:use-module (loftix emulation)
  #:export (for-evocatio))

(define-public afl++
  (let ((commit "93a6e1dbd19da92702dd7393d1cd1b405a6c29ee"))
    (package
      (inherit aflplusplus)
      (name "afl++")
      (version (git-version "4.35a" "0" commit))
      (source
       (origin
         (method git-fetch)
         (uri (git-reference
               (url "https://github.com/AFLplusplus/AFLplusplus")
               (commit commit)))
         (file-name (git-file-name name version))
         (sha256
          (base32 "16b516f9xwxv61wzwbgw4wazx3jnhai3zlb0wpw3q0gdxcb7y61q"))))
      (arguments
       (substitute-keyword-arguments (package-arguments aflplusplus)
         ((#:phases phases)
          #~(modify-phases #$phases
              (add-after 'build 'build-qasan
                (lambda* (#:key parallel-build? make-flags #:allow-other-keys)
                  (apply invoke "make" "-C" "qemu_mode/libqasan"
                         "-j" (number->string (if parallel-build?
                                                  (parallel-job-count)
                                                  "1"))
                         make-flags)))
              ;; afl-qemu-trace is a symbolic link to QEMU's binary.
              ;; Substituting its source code with AFL++'s output path
              ;; would result in a dependency cycle.
              (add-after 'install-qemu 'wrap-qemu
                (lambda _
                  (wrap-program (string-append #$output "/bin/afl-qemu-trace")
                    `("AFL_PATH" =
                      (,(string-append #$output "/lib/afl"))))))))))
      (inputs (modify-inputs (package-inputs aflplusplus)
                (replace "qemu" qemu-for-afl++))))))

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

(define-public evocatio
  (let ((commit "fc8f6dc5bbdf5f49cf1231e746a7944efa09dcc7")
        (revision "0"))
    (package
      (inherit aflplusplus)
      (name "evocatio")
      (version (git-version "3.15a" revision commit))
      (source (origin
                (method git-fetch)
                (uri (git-reference
                      (url "https://github.com/HexHive/Evocatio")
                      (commit commit)))
                (file-name (git-file-name name version))
                (sha256
                 (base32
                  "16kc2xa4dk9lq1sg7sl5489n7r3p8kc6hmfgy0gh7i1n6h269bry"))
                (patches
                 (search-patches
                   "patches/evocatio-argv-fuzz-amd64-only.patch"))))
      (arguments
        (substitute-keyword-arguments (package-arguments aflplusplus)
          ((#:make-flags make-flags)
           #~(cons* "-C" "bug-severity-AFLplusplus"
                    "CFLAGS=-O2 -g -fcommon"
                    "NO_SPLICING=1"
                    #$make-flags))
          ((#:build-target _) "source-only")
          ((#:modules modules %default-gnu-modules)
           `((ice-9 string-fun) ,@modules))
          ((#:phases phases)
           #~(modify-phases #$phases
               (replace 'patch-gcc-path
                 (lambda* (#:key inputs #:allow-other-keys)
                   ;; AFL++ is prefixed with bug-severity-AFLplusplus
                   (substitute* "bug-severity-AFLplusplus/src/afl-cc.c"
                     (("alt_cc = \"gcc\";")
                      (format #f "alt_cc = \"~a\";"
                              (search-input-file inputs "bin/gcc")))
                     (("alt_cxx = \"g\\+\\+\";")
                      (format #f "alt_cxx = \"~a\";"
                              (search-input-file inputs "bin/g++"))))))
               (add-after 'build 'build-argv-fuzzing
                 (lambda* (#:key make-flags #:allow-other-keys)
                   (apply invoke
                     "make" "-C" "bug-severity-AFLplusplus/utils/argv_fuzzing"
                     (cdddr make-flags))))
               (add-after 'install 'install-argv-fuzzing
                 (lambda* (#:key make-flags #:allow-other-keys)
                   (apply invoke
                     "make" "-C" "bug-severity-AFLplusplus/utils/argv_fuzzing"
                     "install" (cdddr make-flags))))
               (add-after 'install 'install-scripts
                 (lambda* (#:key outputs #:allow-other-keys)
                   (let ((bin (string-append (assoc-ref outputs "out")
                                             "/bin")))
                     (for-each
                       (lambda (script)
                         (let ((file (string-append
                                       bin "/evocatio-"
                                       (string-replace-substring script
                                         "_" "-"))))
                           (copy-file (string-append "scripts/" script ".py")
                                      file)
                           (chmod file #o755)))
                       '("calculate_severity_score"
                         "gen_raw_data_for_cve")))))))))
      (home-page "https://github.com/HexHive/Evocatio")
      (description
        "Evocatio is a bug analyzer built on top of AFL++ and AddressSanitizer.
It automatically discovers a bug's capabilities: analyzing a crashing test case
(i.e., an input exposing a bug) to understand the full extent
of how an attacker can exploit a bug.

Evocatio leverages a capability-guided fuzzer to efficiently uncover
new bug capabilities (rather than only generating a single crashing test case
for a given bug, as a traditional greybox fuzzer does)."))))

(define (for-evocatio base)
  (package
    (inherit base)
    (name (string-append (package-name base) "-for-evocatio"))
    (arguments
     (substitute-keyword-arguments (package-arguments base)
       ((#:configure-flags flags #~'())
        #~(cons (string-append "CC=" #$evocatio "/bin/afl-cc")
                #$flags))
       ((#:phases phases #~%standard-phases)
        #~(modify-phases #$phases
            (add-before 'configure 'set-env
              (lambda _
                (setenv "CC" #$(file-append evocatio "/bin/afl-cc"))
                (setenv "AFL_USE_ASAN" "1")
                (setenv "AFL_USE_UBSAN" "1")
                (setenv "ASAN_OPTIONS" "detect_leaks=0")))))
       ((#:tests? _ #f)
        #f)))
    (native-inputs
      (modify-inputs (package-native-inputs base)
        (append evocatio)))))

(define-public fuzzolic-showmap
  (hidden-package
   (package
     (inherit afl++)
     (name "fuzzolic-showmap")
     (source (origin
               (inherit (package-source afl++))
               (patches (search-patches "patches/fuzzolic-showmap.patch"))))
     (arguments
      (substitute-keyword-arguments (package-arguments afl++)
        ((#:phases phases #~%standard-phases)
         #~(modify-phases #$phases
             (replace 'install
               (lambda* (#:key outputs #:allow-other-keys)
                 (let* ((dir (string-append (assoc-ref outputs "out")
                                            "/bin"))
                        (file (string-append dir "/fuzzolic-showmap")))
                   (mkdir-p dir)
                   (copy-file "afl-showmap" file)))))))))))

(define-public fuzzolic
  (let* ((base-name "fuzzolic")
         (commit "39937821d5360b139f026f09e2019f214a4929c1")
         (revision "0")
         (version (git-version "0" revision commit))
         (base-source
          (origin
            (method git-fetch)
            (uri (git-reference
                  (url "https://github.com/season-lab/fuzzolic")
                  (commit commit)))
            (file-name (git-file-name base-name version))
            (sha256
             (base32
              "0wh452qzia97i34hvxjj8x38wb9h6x51zsjkzdvpfpj5zbpdv495"))))
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
         (home-page "https://season-lab.github.io/fuzzolic")
         (solver
          (package
            (name (string-append base-name "-solver"))
            (version version)
            (source (origin
                      (inherit base-source)
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
            (synopsis "Fuzzy constraint solver for FUZZOLIC")
            (description description)
            (home-page home-page)
            (license license:gpl2+)))
         (utils
          (package
            (name (string-append base-name "-utils"))
            (version version)
            (source (origin
                      (inherit base-source)
                      (patches (search-patches
                                "patches/fuzzolic-utils-make.patch"))))
            (build-system gnu-build-system)
            (arguments
             (list #:make-flags #~(list (string-append "CC=" #$(cc-for-target))
                                        (string-append "PREFIX=" #$output))
                   #:phases #~(modify-phases %standard-phases
                                (delete 'configure)
                                (delete 'check))))
            (inputs (list python))
            (synopsis "Fuzzy constraint solver for FUZZOLIC")
            (description description)
            (home-page home-page)
            (license license:gpl2+))))
    (package
      (name base-name)
      (version version)
      (source (origin
                (inherit base-source)
                (snippet #~(call-with-output-file "pyproject.toml"
                             (lambda (port)
                               (display (string-append "
[build-system]
requires = ['flit_core >=3.2']
build-backend = 'flit_core.buildapi'

[project]
name = '" #$base-name "'
version = '0'
description = '''" #$description "
'''

[project.scripts]
fuzzolic = 'fuzzolic.fuzzolic:main'
fuzzolic-with-afl = 'fuzzolic.run_afl_fuzzolic:main'
") port))))
                (patches (search-patches
                          "patches/fuzzolic-python-package.patch"
                          "patches/fuzzolic-unbundle.patch"
                          "patches/fuzzolic-relax-perf-test.patch"
                          "patches/fuzzolic-test-fix-runner.patch"
                          "patches/fuzzolic-test-skip-nondeterministic.patch"))))
      (build-system pyproject-build-system)
      (arguments
       '(#:phases (modify-phases %standard-phases
                    (replace 'check
                      (lambda* (#:key tests? #:allow-other-keys)
                        (when tests?
                          (invoke "make" "-C" "tests")
                          (invoke "pytest" "-vv" "tests/run.py" "--fuzzy")
                          (invoke "pytest" "-vv" "tests/run.py")))))))
      (native-inputs (list python-flit-core python-pytest))
      (propagated-inputs (list afl++
                               fuzzolic-showmap
                               qemu-for-fuzzolic
                               solver
                               utils))
      (synopsis "Concolic fuzzer")
      (description description)
      (home-page home-page)
      (license license:gpl2+))))
