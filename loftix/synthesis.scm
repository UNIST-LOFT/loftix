;;; Packages for software systhesis
;;;
;;; SPDX-FileCopyrightText: 2024-2026 Nguyễn Gia Phong
;;; SPDX-License-Identifier: GPL-3.0-or-later

(define-module (loftix synthesis)
  #:use-module (gnu packages)
  #:use-module (gnu packages base)
  #:use-module (gnu packages debug)
  #:use-module (gnu packages instrumentation)
  #:use-module (gnu packages m4)
  #:use-module (gnu packages maths)
  #:use-module (gnu packages java)
  #:use-module (gnu packages patchutils)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-build)
  #:use-module (gnu packages python-check)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages zig)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system pyproject)
  #:use-module (guix download)
  #:use-module (guix fossil-download)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages)
  #:use-module (loftix fuzzing)
  #:use-module (loftix model-checking))

(define-public python-pacfix
  (package
    (name "python-pacfix")
    (version "0.0.3")
    (source
      (origin
        (method url-fetch)
        (uri (pypi-uri "pacfix" version))
        (sha256
          (base32 "1gpr410gfwab5mg3k57r001mddqgxk9d5rbn89v1wczi51ljlsc5"))))
    (build-system pyproject-build-system)
    (native-inputs (list python-flit-core))
    (propagated-inputs (list python-pysmt))
    (arguments '(#:phases
                 (modify-phases %standard-phases
                   (replace 'check
                     (lambda* (#:key tests? #:allow-other-keys)
                       (when tests?
                         (invoke "python" "-m" "unittest" "-v")))))))
    (home-page "https://github.com/hsh814/pacfix-python")
    (synopsis "PAC-learning-based program systhesizer")
    (description "Pacfix systhesizes predicate expressions for program repair
from values in possitive and negative examples using a PAC learning algorithm.")
    (license license:expat)))

(define-public syminfer
  (let ((commit "7e1ebec4899d7687607e4fdd4c284dd835d68eec")
        (revision "0"))
    (package
      (name "syminfer")
      (version (git-version "2.0.2b" revision commit))
      (source
       (origin
         (method git-fetch)
         (uri (git-reference
               (url "https://github.com/dynaroars/dig")
               (commit commit)))
         (file-name (git-file-name name version))
         (sha256
          (base32 "090bzr2303wybdkqdsndn5i264k15pw89fmixb5rg5zx350mrsmf"))
         (patches (search-patches "patches/syminfer-pyproject.patch"))
         (modules '((guix build utils)))
         (snippet #~(with-directory-excursion "src"
                      (delete-file-recursively "algebraicaxioms")
                      (delete-file-recursively "beta")
                      (delete-file-recursively "prover")
                      (delete-file "java/asm-all-5.2.jar")
                      (delete-file "kip.py")
                      (delete-file "preconds.py")
                      (delete-file "tmp.py")))))
      (build-system pyproject-build-system)
      (arguments
       (list #:phases
             #~(modify-phases %standard-phases
                 (add-after 'unpack 'set-paths
                   (lambda* (#:key inputs outputs #:allow-other-keys)
                     (substitute* (find-files "src" "\\.py$")
                       (("beartype\\.") "")
                       ((".*beartype.*") ""))
                     (substitute* "src/settings.py"
                       (("^(SRC_DIR) = .*" all lhs)
                        (simple-format #f "~a = Path(~s)\n"
                          lhs (site-packages inputs outputs)))
                       (("^(JAVAC_CMD) = .*" all lhs)
                        (simple-format #f "~a = Path(~s)\n"
                          lhs (search-input-file inputs "bin/javac")))
                       (("^(JAVA_CMD) = .*" all lhs)
                        (simple-format #f "~a = Path(~s)\n"
                          lhs (search-input-file inputs "bin/java")))
                       (("^(    ASM_JAR) = .*" all lhs)
                        (simple-format #f "~a = Path(~s)\n"
                          lhs (search-input-file
                               inputs
                               "lib/m2/org/ow2/asm/asm/6.0/asm-6.0.jar")))
                       (("^(    CIVL_RUN) = .*" all lhs)
                        (simple-format #f "~a = '~a verify ~a ~a'.format\n"
                          lhs
                          (search-input-file inputs "bin/civl")
                          "-maxdepth={maxdepth}"
                          "{file}"))))))))
      (native-inputs (list python-setuptools))
      (inputs (list civl
                    java-asm
                    (list openjdk "jdk")
                    python-pycparser
                    python-sympy
                    z3))
      (home-page "https://github.com/dynaroars/dig")
      (synopsis "Numerical invariant generation tool")
      (description
       "SymInfer is an invariant generation tool that discovers
program properties at arbitrary program locations (e.g., loop invariants,
post conditions).  It infers program invariants or properties
over program execution traces or program source code.  SymInfer supports
many forms of numerical invariants, including nonlinear equalities,
octagonal and interval properties, min/max-plus relations,
and congruence relations.")
      (license license:expat))))

(define-public taosc
  (package
    (name "taosc")
    (version "0.0.8")
    (source
     (origin
       (method fossil-fetch)
       (uri (fossil-reference
             (uri "https://chim.loan/taosc")
             (check-in version)))
       (sha256
        (base32 "0k7iqkix6rjhg7a2160brlrby5xavfvxvr7nhhza1g46va79c2p8"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:imported-modules
      (cons '(guix build zig-utils)
            %default-gnu-imported-modules)
      #:modules
      (cons '(guix build zig-utils)
            %default-gnu-modules)
      #:make-flags
      #~(list (string-append "E9TOOL=" #$(this-package-input "e9patch")
                             "/bin/e9tool")
              (string-append "FIND=" #$(this-package-input "findutils")
                             "/bin/find")
              (string-append "XARGS=" #$(this-package-input "findutils")
                             "/bin/xargs")
              (string-append "FUZZOLIC=" #$(this-package-input "fuzzolic")
                             "/bin/fuzzolic")
              (string-append "QEMU=" #$(this-package-input "aflplusplus")
                             "/bin/afl-qemu-trace")
              (string-append "PREFIX=" #$output))
      #:phases
      #~(modify-phases %standard-phases
          (replace 'configure zig-configure))))
    (native-inputs (list m4 zig-0.15))
    (inputs (list aflplusplus dyninst aflplusplus e9patch findutils fuzzolic))
    (synopsis "Emergency binary patcher")
    (description "Taosc generates emergent fixes for binaries.")
    (home-page "https://chim.loan/taosc")
    (license license:agpl3+)))
