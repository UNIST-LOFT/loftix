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

(define-public aflrun
  (let ((commit "65d51e3b6dd44957c99fa57c1fb9fa4a040451a0")
        (revision "0"))
    (package
      (inherit aflplusplus)
      (name "aflrun")
      (version (git-version "2024.12.03" revision commit))
      (source
        (origin
          (method url-fetch)
          (uri (string-append
                 "https://trong.loang.net/~cnx/afl++/snapshot/afl++-"
                 commit ".tar.gz"))
          (sha256
            (base32
              "1q1smpk6l25cipszj917kvw1shfi5zznxsq4dcwlallym1s1gxqy"))
          (patches (search-patches
                     "patches/aflrun-keep-all-crashes.patch"
                     "patches/aflrun-disable-inst-checks.patch"))))
      (native-inputs (list gcc-14))
      (synopsis "Multi-target directed AFL++ with path diversity")
      (description "AFLRun is a fork of AFL++
for unbiased multiple-target fuxxing with path diversity.")
      (home-page "https://trong.loang.net/~cnx/afl++/log?h=run")
      (license license:asl2.0))))

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
