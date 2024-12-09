;;; Packages for software fuzzing
;;; Copyright © 2024 Nguyễn Gia Phong
;;;
;;; This file is part of Loftix.
;;;
;;; Loftix is free software; you can redistribute it and/or modify it
;;; under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 3 of the License, or (at
;;; your option) any later version.
;;;
;;; Loftix is distributed in the hope that it will be useful, but
;;; WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with Loftix.  If not, see <http://www.gnu.org/licenses/>.

(define-module (loftix fuzzing)
  #:use-module (gnu packages)
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
  (let ((commit "2ae8a8631c031ee2b50fb91e11d9b77d8c0147ff")
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
              "187j6qyvrmm5jb4v870dl7abp5yaqbl7c2qzk06pyl2x96irakc7"))
          (file-name (git-file-name name version))
          (patches (search-patches
                     "patches/aflrun-keep-all-crashes.patch"
                     "patches/aflrun-disable-inst-checks.patch"))))
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
