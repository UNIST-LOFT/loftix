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
  #:use-module (loftix fuzzing)
  #:use-module (loftix synthesis)
  #:export (taosctha))

(define (taosctha bug-id buggy-package)
  (let* ((poc (cadr (search-bug %buggy-packages bug-id)))
         (bin (in-vicinity "bin" (car poc)))
         (args (cadr poc))
         (poc-dir (in-vicinity "share/bux" (dirname (caddr poc)))))
    (package
      (name (string-append "taoscadh-" (string-downcase bug-id)))
      (version (package-version taosc))
      (source #f)
      (build-system trivial-build-system)
      (arguments
       (list #:modules
             '((guix build utils))
             #:builder
             #~(let ((omp-threads "8")
                     (timeout "10"))
                 (use-modules (guix build utils))
                 (sigaction SIGCHLD
                   (lambda _
                     (while (false-if-exception
                             (not (= 0 (car (waitpid WAIT_ANY WNOHANG))))))))
                 (setenv "HOME" "/tmp")
                 (setenv "OMP_NUM_THREADS" omp-threads)
                 (set-path-environment-variable "PATH" '("bin")
                                                (map cdr %build-inputs))
                 (invoke "taosc-fix" timeout #$output
                         (search-input-directory %build-inputs #$poc-dir)
                         (in-vicinity #$buggy-package #$bin)
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

(define (binradared bug-id buggy-package)
  (package
    (name (string-append "binradared-taoscadh-" (string-downcase bug-id)))
    (version (package-version binradar))
    (source (taosctha bug-id buggy-package))
    (properties '((max-silent-time . 7200)))
    (build-system trivial-build-system)
    (arguments
     (list #:modules
           '((guix build utils))
           #:builder
           #~(let ((timeout (number->string
                             #$(assq-ref properties 'max-silent-time))))
               (use-modules (guix build utils))
               (set-path-environment-variable "PATH" '("bin")
                                              (map cdr %build-inputs))
               (let* ((source (assoc-ref %build-inputs "source"))
                      (bench
                       (search-input-directory
                        %build-inputs "share/binradar/benchmarks/loftix"))
                      (configs
                       (find-files
                        bench (lambda (path stat)
                                (string-suffix?
                                 (string-append #$bug-id "/config.env")
                                 path)))))
                 (copy-recursively source "workdir")
                 (for-each make-file-writable (find-files "workdir"))
                 (copy-file (car configs) "config.env"))
               (for-each
                (lambda (subcmd)
                  (invoke "binradar-setup" subcmd)
                  (invoke "binradar" "-w" "workdir" "-t" timeout subcmd))
                '("--generate-concrete" "--generate-binradar"))
               (copy-recursively "workdir/out" #$output))))
    (inputs (list (taosctha bug-id buggy-package)))
    (native-inputs (list binradar binradar-benchmarks coreutils))
    (synopsis (simple-format #f "BinRadar output of ~a in ~a@@~a"
                bug-id
                (package-name buggy-package)
                (package-version buggy-package)))
    (description (package-description buggy-package))
    (home-page (package-home-page buggy-package))
    (license (package-license buggy-package))))

(define (join-name . strings)
  (string->symbol (string-downcase (string-join strings "-"))))

(define-macro (define-binradared-taoscadh id pkg . rest)
  (let ((taoscadh (join-name "taoscadh" id))
        (binradared-taoscadh (join-name "binradared" "taoscadh" id)))
    `(begin
       (define-public ,taoscadh (taosctha ,id ,pkg))
       (define-public ,binradared-taoscadh (binradared ,id ,pkg))
       ,@(if (null? rest)
             '()
             `((define-binradared-taoscadh . ,rest))))))

(define-binradared-taoscadh
  "CVE-2017-6965" binutils-2.27
  "CVE-2017-6966" binutils-2.27
  "CVE-2017-14745" binutils-2.29
  "CVE-2017-14939" binutils-2.29
  "CVE-2017-14940" binutils-2.29
  "CVE-2017-15020" binutils-2.29
  "CVE-2017-15025" binutils-2.29
  "CVE-2018-10372" binutils-2.30
  "CVE-2019-9077" binutils-2.32
  "CVE-2016-8691" jasper-static-1.900.3
  "CVE-2016-9387" jasper-static-1.900.5
  "CVE-2016-9557" jasper-static-1.900.19
  "CVE-2016-9560" jasper-static-1.900.19
  "CVE-2023-50246" jq-static-1.7.0
  "CVE-2024-23337" jq-static-1.7.1
  "CVE-2012-2806" libjpeg-turbo-static-1.2.0
  "CVE-2017-15232" libjpeg-turbo-static-1.5.2
  "CVE-2018-14498" libjpeg-turbo-static-1.5.3
  "CVE-2018-19664" libjpeg-turbo-static-2.0.1
  "CVE-2016-9265" libming-static-0.4.7
  "CVE-2018-8806" libming-static-0.4.8
  "CVE-2018-8964" libming-static-0.4.8
  "CVE-2014-8128" libtiff-static-4.0.3
  "CVE-2016-3623" libtiff-static-4.0.6
  "CVE-2016-5314" libtiff-static-4.0.6
  "CVE-2016-5321" libtiff-static-4.0.6
  "CVE-2016-9273" libtiff-static-4.0.6
  "CVE-2016-9532" libtiff-static-4.0.6
  "CVE-2016-10092" libtiff-static-4.0.7
  "CVE-2016-10093" libtiff-static-4.0.7
  "CVE-2016-10094" libtiff-static-4.0.7
  "CVE-2016-10266" libtiff-static-4.0.7
  "CVE-2016-10267" libtiff-static-4.0.7
  "CVE-2016-10268" libtiff-static-4.0.7
  "CVE-2016-10271" libtiff-static-4.0.7
  "CVE-2016-10272" libtiff-static-4.0.7
  "CVE-2017-5225" libtiff-static-4.0.7
  "CVE-2017-7595" libtiff-static-4.0.7
  "Maptools-2633" libtiff-static-4.0.7
  "CVE-2012-5134" libxml2-static-2.9.0
  "CVE-2016-1839" libxml2-static-2.9.3
  "CVE-2017-5969" libxml2-static-2.9.4
  "CVE-2019-11411" mujs-1.0.5
  "CVE-2013-7437" potrace-1.11
  "CVE-2017-5974" zziplib-static-0.13.62
  "CVE-2017-5975" zziplib-static-0.13.62
  "CVE-2017-5978" zziplib-static-0.13.62
  "CVE-2017-5979" zziplib-static-0.13.62
  "CVE-2017-5980" zziplib-static-0.13.62
  "CVE-2017-5981" zziplib-static-0.13.62)
