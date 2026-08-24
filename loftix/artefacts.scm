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
  #:use-module (loftix synthesis))

(define (taosctha bug-id)
  (let* ((bug (search-bug %buggy-packages bug-id))
         (orig (buggy-package bug #:static? #t))
         (poc (cadr bug))
         (bin (string-append "bin/" (car poc)))
         (args (cadr poc))
         (poc-dir (string-append "share/bux/" (dirname (caddr poc))))
         (taosc-timeout "10"))
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
                 (invoke "taosc-fix" #$taosc-timeout #$output
                         (search-input-directory %build-inputs #$poc-dir)
                         (search-input-file %build-inputs #$bin)
                         (simple-format #f #$args "@@")))))
      (inputs (list orig))
      (native-inputs (list bux coreutils grep sed taosc))
      (synopsis (simple-format #f "~a@@~a with ~a patched by taosc"
                  (package-name orig)
                  (package-version orig)
                  bug-id))
      (description (package-description orig))
      (home-page (package-home-page orig))
      (license (package-license orig)))))

(define-public taoscadh-cve-2016-9273 (taosctha "CVE-2016-9273"))
