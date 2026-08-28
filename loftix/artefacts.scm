;;; Research artefacts
;;;
;;; SPDX-FileCopyrightText: 2026 Nguyễn Gia Phong
;;; SPDX-License-Identifier: GPL-3.0-or-later

(define-module (loftix artefacts)
  #:use-module (gnu packages base)
  #:use-module (gnu packages gcc)
  #:use-module (guix build-system trivial)
  #:use-module (guix gexp)
  #:use-module (guix packages)
  #:use-module (guix scripts expose)
  #:use-module (loftix bugs)
  #:use-module (loftix synthesis)
  #:export (taosctha))

(define (taosctha buggy-package bug-id)
  (let* ((poc (cadr (search-bug %buggy-packages bug-id)))
         (bin (string-append "/bin/" (car poc)))
         (args (cadr poc))
         (poc-dir (string-append "share/bux/" (dirname (caddr poc))))
         (timeout "10"))
    (package
      (name "taoscadh")
      (version bug-id)
      (source #f)
      (build-system trivial-build-system)
      (arguments
       (list #:modules
             '((guix build utils))
             #:builder
             #~(begin
                 (use-modules (guix build utils))
                 (set-path-environment-variable "PATH" '("bin")
                                                (map cdr %build-inputs))
                 (mkdir #$output)
                 (invoke "taosc-fix" #$timeout #$output
                         (search-input-directory %build-inputs #$poc-dir)
                         (string-append #$buggy-package #$bin)
                         (simple-format #f #$args "@@")))))
      (inputs (list buggy-package))
      (native-inputs
       (list binutils bux coreutils diffutils findutils gcc grep sed taosc))
      (synopsis (simple-format #f "~a@@~a with ~a patched by taosc"
                  (package-name buggy-package)
                  (package-version buggy-package)
                  bug-id))
      (description (package-description buggy-package))
      (home-page (package-home-page buggy-package))
      (license (package-license buggy-package)))))

(define-public taoscadh-cve-2017-6965
  (taosctha binutils-2.27 "CVE-2017-6965"))

(define-public taoscadh-cve-2017-14745
  (taosctha binutils-2.29 "CVE-2017-14745"))

(define-public taoscadh-cve-2017-15020
  (taosctha binutils-2.29 "CVE-2017-15020"))

(define-public taoscadh-cve-2017-15025
  (taosctha binutils-2.29 "CVE-2017-15025"))

(define-public taoscadh-cve-2016-8691
  (taosctha jasper-static-1.900.3 "CVE-2016-8691"))

(define-public taoscadh-cve-2016-9557
  (taosctha jasper-static-1.900.19 "CVE-2016-9557"))

(define-public taoscadh-cve-2012-2806
  (taosctha libjpeg-turbo-static-1.2.0 "CVE-2012-2806"))

(define-public taoscadh-cve-2017-15232
  (taosctha libjpeg-turbo-static-1.5.2 "CVE-2017-15232"))

(define-public taoscadh-cve-2018-14498
  (taosctha libjpeg-turbo-static-1.5.3 "CVE-2018-14498"))

(define-public taoscadh-cve-2018-19664
  (taosctha libjpeg-turbo-static-2.0.1 "CVE-2018-19664"))

(define-public taoscadh-cve-2016-9265
  (taosctha libming-static-0.4.7 "CVE-2016-9265"))

(define-public taoscadh-cve-2018-8806
  (taosctha libming-static-0.4.8 "CVE-2018-8806"))

(define-public taoscadh-cve-2018-8964
  (taosctha libming-static-0.4.8 "CVE-2018-8964"))

(define-public taoscadh-cve-2016-5314
  (taosctha libtiff-static-4.0.6 "CVE-2016-5314"))

(define-public taoscadh-cve-2016-5321
  (taosctha libtiff-static-4.0.6 "CVE-2016-5321"))

(define-public taoscadh-cve-2016-9273
  (taosctha libtiff-static-4.0.6 "CVE-2016-9273"))

(define-public taoscadh-cve-2016-9532
  (taosctha libtiff-static-4.0.6 "CVE-2016-9532"))

(define-public taoscadh-cve-2016-10092
  (taosctha libtiff-static-4.0.7 "CVE-2016-10092"))

(define-public taoscadh-cve-2016-10094
  (taosctha libtiff-static-4.0.7 "CVE-2016-10094"))

(define-public taoscadh-cve-2016-10267
  (taosctha libtiff-static-4.0.7 "CVE-2016-10267"))

(define-public taoscadh-cve-2016-10272
  (taosctha libtiff-static-4.0.7 "CVE-2016-10272"))

(define-public taoscadh-cve-2017-5225
  (taosctha libtiff-static-4.0.7 "CVE-2017-5225"))

(define-public taoscadh-cve-2017-7595
  (taosctha libtiff-static-4.0.7 "CVE-2017-7595"))

(define-public taoscadh-maptools-2633
  (taosctha libtiff-static-4.0.7 "Maptools-2633"))

(define-public taoscadh-cve-2012-5134
  (taosctha libxml2-static-2.9.0 "CVE-2012-5134"))

(define-public taoscadh-cve-2016-1839
  (taosctha libxml2-static-2.9.3 "CVE-2016-1839"))

(define-public taoscadh-cve-2017-5969
  (taosctha libxml2-static-2.9.4 "CVE-2017-5969"))

(define-public taoscadh-cve-2013-7437
  (taosctha potrace-1.11 "CVE-2013-7437"))

(define-public taoscadh-cve-2017-5974
  (taosctha zziplib-static-0.13.62 "CVE-2017-5974"))

(define-public taoscadh-cve-2017-5975
  (taosctha zziplib-static-0.13.62 "CVE-2017-5975"))
