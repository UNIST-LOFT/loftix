;;; Packages for software fuzzing
;;;
;;; SPDX-FileCopyrightText: 2024-2026 Nguyễn Gia Phong
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
                               (simple-format port "
[build-system]
requires = ['flit_core >=3.2']
build-backend = 'flit_core.buildapi'

[project]
name = ~s
version = '0'
description = '''~a
'''

[project.scripts]
fuzzolic = 'fuzzolic.fuzzolic:main'
fuzzolic-with-afl = 'fuzzolic.run_afl_fuzzolic:main'
" #$base-name #$description))))
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
      (propagated-inputs (list aflplusplus
                               fuzzolic-showmap
                               qemu-for-fuzzolic
                               solver
                               utils))
      (synopsis "Concolic fuzzer")
      (description description)
      (home-page home-page)
      (license license:gpl2+))))
