;;; Packages for software systhesis
;;;
;;; SPDX-FileCopyrightText: 2024-2025 Nguyễn Gia Phong
;;; SPDX-License-Identifier: GPL-3.0-or-later

(define-module (loftix synthesis)
  #:use-module (gnu packages debug)
  #:use-module (gnu packages elf)
  #:use-module (gnu packages instrumentation)
  #:use-module (gnu packages m4)
  #:use-module (gnu packages parallel)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-build)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages zig)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system pyproject)
  #:use-module (guix build-system python)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages)
  #:use-module (loftix fuzzing)
  #:use-module (loftix patching))

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

(define-public taosc
  (package
    (name "taosc")
    (version "0.0.3.dev1")
    (source
      (origin
        (method url-fetch)
        (uri (string-append
               "https://trong.loang.net/~cnx/taosc/snapshot/taosc-"
               version ".tar.gz"))
        (sha256
          (base32 "0372a542gpn46kz50nq4a8js3b1n3x3ibdg0j0j5ff9dams6cnax"))))
    (build-system gnu-build-system)
    (arguments
      (list #:imported-modules `((guix build zig-utils)
                                 ,@%default-gnu-imported-modules)
            #:modules `((guix build zig-utils)
                        ,@%default-gnu-modules)
            #:make-flags #~(list (string-append "PREFIX=" #$output))
            #:phases
            #~(modify-phases %standard-phases
                (replace 'configure zig-configure)
                (delete 'check))))
    (native-inputs (list m4 zig-0.15))
    (inputs (list dyninst))
    (propagated-inputs (list e9patch fuzzolic)) ; TODO: wrap
    (synopsis "Emergency binary patcher")
    (description "Taosc generates emergent fixes for binaries.")
    (home-page "https://trong.loang.net/~cnx/taosc")
    (license license:agpl3+)))
