;;; Packages for theorem provers
;;;
;;; SPDX-FileCopyrightText: 2026 Nguyễn Gia Phong
;;; SPDX-License-Identifier: GPL-3.0-or-later

(define-module (loftix analysis)
  #:use-module (gnu packages libffi)
  #:use-module (gnu packages llvm)
  #:use-module (gnu packages maths)
  #:use-module (guix build-system cmake)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages))

(define-public svf
  (package
    (name "svf")
    (version "3.3")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/SVF-tools/SVF")
             (commit (string-append "SVF-" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0fp3l443srka5iy7rl1a6hccpmh553378iinbzpafq5nvmzaazh8"))))
    (build-system cmake-build-system)
    (arguments
     (list #:phases #~(modify-phases %standard-phases
                        (add-before 'configure 'setenv
                          (lambda _
                            (setenv "CXXFLAGS"
                                    (string-join
                                     '("-Wno-return-type"
                                       "-Wno-unused-but-set-variable"
                                       "-Wno-unused-variable"))))))
           #:tests? #f))
    (inputs (list clang-21 libffi llvm-21 z3))
    (home-page "https://svf-tools.github.io/SVF")
    (synopsis "Source code analyzer with static value-flow")
    (description
     "SVF is a static tool that enables scalable and precise
value-flow analysis for source code.  SVF allows value-flow construction
and pointer analysis to be performed iteratively, thereby providing
increasingly improved precision for both.")
    (license license:gpl3)))
