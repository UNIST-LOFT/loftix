;;; Research artefacts
;;;
;;; SPDX-FileCopyrightText: 2026 Nguyễn Gia Phong
;;; SPDX-License-Identifier: GPL-3.0-or-later

(define-module (loftix artefacts)
  #:use-module (gnu packages base)
  #:use-module (guix build-system trivial)
  #:use-module (guix gexp)
  #:use-module (guix packages)
  #:use-module (guix scripts expose)
  #:use-module (loftix bugs)
  #:use-module (loftix synthesis)
  #:export (taosctha))

(define (taosctha bug-id buggy-package)
  (let* ((poc (cadr (search-bug %buggy-packages bug-id)))
         (bin (string-append "/bin/" (car poc)))
         (args (cadr poc))
         (poc-dir (string-append "share/bux/" (dirname (caddr poc))))
         (timeout "67"))
    (package
      (name (string-append "taoscadh-" (string-downcase bug-id)))
      (version (package-version taosc))
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
      (native-inputs (list bux coreutils diffutils grep sed taosc))
      (synopsis (simple-format #f "~a@@~a with ~a patched by taosc"
                  (package-name buggy-package)
                  (package-version buggy-package)
                  bug-id))
      (description (package-description buggy-package))
      (home-page (package-home-page buggy-package))
      (license (package-license buggy-package)))))

(define-public taoscadh-cve-2017-6965
  (taosctha "CVE-2017-6965" binutils-2.27))

(define-public taoscadh-cve-2017-6966
  (taosctha "CVE-2017-6966" binutils-2.27))

(define-public taoscadh-cve-2017-14745
  (taosctha "CVE-2017-14745" binutils-2.29))

(define-public taoscadh-cve-2017-14939
  (taosctha "CVE-2017-14939" binutils-2.29))

(define-public taoscadh-cve-2017-14940
  (taosctha "CVE-2017-14940" binutils-2.29))

(define-public taoscadh-cve-2017-15020
  (taosctha "CVE-2017-15020" binutils-2.29))

(define-public taoscadh-cve-2017-15025
  (taosctha "CVE-2017-15025" binutils-2.29))

(define-public taoscadh-cve-2017-15938
  (taosctha "CVE-2017-15938" binutils-2.29))

(define-public taoscadh-cve-2018-10372
  (taosctha "CVE-2018-10372" binutils-2.30))

(define-public taoscadh-cve-2019-9077
  (taosctha "CVE-2019-9077" binutils-2.32))

(define-public taoscadh-cve-2016-8691
  (taosctha "CVE-2016-8691" jasper-static-1.900.3))

(define-public taoscadh-cve-2016-9557
  (taosctha "CVE-2016-9557" jasper-static-1.900.19))

(define-public taoscadh-cve-2016-9560
  (taosctha "CVE-2016-9560" jasper-static-1.900.19))

(define-public taoscadh-cve-2012-2806
  (taosctha "CVE-2012-2806" libjpeg-turbo-static-1.2.0))

(define-public taoscadh-cve-2017-15232
  (taosctha "CVE-2017-15232" libjpeg-turbo-static-1.5.2))

(define-public taoscadh-cve-2018-14498
  (taosctha "CVE-2018-14498" libjpeg-turbo-static-1.5.3))

(define-public taoscadh-cve-2018-19664
  (taosctha "CVE-2018-19664" libjpeg-turbo-static-2.0.1))

(define-public taoscadh-cve-2016-9265
  (taosctha "CVE-2016-9265" libming-static-0.4.7))

(define-public taoscadh-cve-2018-8806
  (taosctha "CVE-2018-8806" libming-static-0.4.8))

(define-public taoscadh-cve-2018-8964
  (taosctha "CVE-2018-8964" libming-static-0.4.8))

(define-public taoscadh-cve-2014-8128
  (taosctha "CVE-2014-8128" libtiff-static-4.0.3))

(define-public taoscadh-cve-2016-3186
  (taosctha "CVE-2016-3186" libtiff-static-4.0.6))

(define-public taoscadh-cve-2016-3623
  (taosctha "CVE-2016-3623" libtiff-static-4.0.6))

(define-public taoscadh-cve-2016-5314
  (taosctha "CVE-2016-5314" libtiff-static-4.0.6))

(define-public taoscadh-cve-2016-5321
  (taosctha "CVE-2016-5321" libtiff-static-4.0.6))

(define-public taoscadh-cve-2016-9273
  (taosctha "CVE-2016-9273" libtiff-static-4.0.6))

(define-public taoscadh-cve-2016-9532
  (taosctha "CVE-2016-9532" libtiff-static-4.0.6))

(define-public taoscadh-cve-2016-10092
  (taosctha "CVE-2016-10092" libtiff-static-4.0.7))

(define-public taoscadh-cve-2016-10093
  (taosctha "CVE-2016-10093" libtiff-static-4.0.7))

(define-public taoscadh-cve-2016-10094
  (taosctha "CVE-2016-10094" libtiff-static-4.0.7))

(define-public taoscadh-cve-2016-10266
  (taosctha "CVE-2016-10266" libtiff-static-4.0.7))

(define-public taoscadh-cve-2016-10267
  (taosctha "CVE-2016-10267" libtiff-static-4.0.7))

(define-public taoscadh-cve-2016-10268
  (taosctha "CVE-2016-10268" libtiff-static-4.0.7))

(define-public taoscadh-cve-2016-10271
  (taosctha "CVE-2016-10271" libtiff-static-4.0.7))

(define-public taoscadh-cve-2016-10272
  (taosctha "CVE-2016-10272" libtiff-static-4.0.7))

(define-public taoscadh-cve-2017-5225
  (taosctha "CVE-2017-5225" libtiff-static-4.0.7))

(define-public taoscadh-cve-2017-7595
  (taosctha "CVE-2017-7595" libtiff-static-4.0.7))

(define-public taoscadh-maptools-2633
  (taosctha "Maptools-2633" libtiff-static-4.0.7))

(define-public taoscadh-cve-2012-5134
  (taosctha "CVE-2012-5134" libxml2-static-2.9.0))

(define-public taoscadh-cve-2016-1839
  (taosctha "CVE-2016-1839" libxml2-static-2.9.3))

(define-public taoscadh-cve-2017-5969
  (taosctha "CVE-2017-5969" libxml2-static-2.9.4))

(define-public taoscadh-cve-2013-7437
  (taosctha "CVE-2013-7437" potrace-1.11))

(define-public taoscadh-cve-2017-5974
  (taosctha "CVE-2017-5974" zziplib-static-0.13.62))

(define-public taoscadh-cve-2017-5975
  (taosctha "CVE-2017-5975" zziplib-static-0.13.62))

(define-public taoscadh-cve-2017-5977
  (taosctha "CVE-2017-5977" zziplib-static-0.13.62))

(define-public taoscadh-cve-2017-5978
  (taosctha "CVE-2017-5978" zziplib-static-0.13.62))

(define-public taoscadh-cve-2017-5979
  (taosctha "CVE-2017-5979" zziplib-static-0.13.62))

(define-public taoscadh-cve-2017-5980
  (taosctha "CVE-2017-5980" zziplib-static-0.13.62))

(define-public taoscadh-cve-2017-5981
  (taosctha "CVE-2017-5981" zziplib-static-0.13.62))
