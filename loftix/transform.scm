;;; Package recipe transformations
;;;
;;; SPDX-FileCopyrightText: 2025 Nguyễn Gia Phong
;;; SPDX-License-Identifier: GPL-3.0-or-later

(define-module (loftix transform)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages multiprecision)
  #:use-module (guix build-system cmake)
  #:use-module (guix fossil-download)
  #:use-module (guix gexp)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages)
  #:use-module (guix utils)
  #:use-module (ice-9 match)
  #:use-module (ice-9 receive)
  #:use-module (srfi srfi-1)
  #:export (append-env
            append-make-flag))

(define (append-env name addition default)
  (setenv name
          (let ((value (or (getenv name) default)))
            (if value
                (string-append value " " addition)
                addition))))

(define (append-make-flag original additions)
  (let ((orig-ls (map (lambda (flag)
                        (let ((ls (string-split flag #\=)))
                          (list (car ls)
                                (string-join (cdr ls)
                                             "="))))
                      original)))
    (receive (existing new) (partition (lambda (addition)
                                         (assoc (car addition)
                                                orig-ls))
                                       additions)
      (append (map (match-lambda
                     ((name value)
                      (match (assoc name existing)
                        ((or (addition)
                             (addition default))
                         (string-append name "=" value " " addition))
                        (else (string-append name "=" value)))))
                   orig-ls)
              (map (match-lambda
                     ((name addition)
                      (string-append name "=" addition))
                     ((name addition default)
                      (string-append name "=" default " " addition)))
                   new)))))

(define-public hellscape
  (package
    (name "hellscape")
    (version "1.0.1")
    (source
     (origin
       (method fossil-fetch)
       (uri (fossil-reference
             (uri "https://chim.loan/hellscape")
             (check-in version)))
       (sha256
        (base32 "179fi3nw2vzpijhyh15xgnrk1n5azzkm160mc37h6dlh33p9z721"))))
    (build-system cmake-build-system)
    (arguments (list #:tests? #f))      ;no tests
    (inputs (list gcc gmp))
    (home-page "https://chim.loan/hellscape")
    (synopsis "GIMPLE obfuscator")
    (description "Hellscape is a GCC plugin for GIMPLE obfuscation.")
    (license license:gpl3+)))
