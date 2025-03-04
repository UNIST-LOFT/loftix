;;; Packages for software fuzzing
;;;
;;; SPDX-FileCopyrightText: 2024 Nguyễn Gia Phong
;;; SPDX-License-Identifier: GPL-3.0-or-later

(define-module (loftix fuzzing)
  #:use-module (gnu packages)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages debug)
  #:use-module (gnu packages instrumentation)
  #:use-module (gnu packages man)
  #:use-module (gnu packages m4)
  #:use-module (guix build-system gnu)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages))

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
