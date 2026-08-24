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

(define (taosctha buggy-package bug-id)
  (let* ((poc (cadr (search-bug %buggy-packages bug-id)))
         (bin (string-append "bin/" (car poc)))
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
                         (search-input-file %build-inputs #$bin)
                         (simple-format #f #$args "@@")))))
      (inputs (list buggy-package))
      (native-inputs (list bux coreutils grep sed taosc))
      (synopsis (simple-format #f "~a@@~a with ~a patched by taosc"
                  (package-name buggy-package)
                  (package-version buggy-package)
                  bug-id))
      (description (package-description buggy-package))
      (home-page (package-home-page buggy-package))
      (license (package-license buggy-package)))))

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
  (taosctha libtiff-static-4.0.7 "CVE-2016-10092"))

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
