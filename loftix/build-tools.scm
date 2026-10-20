;;; Build tools
;;;
;;; SPDX-FileCopyrightText: 2026 Nguyễn Gia Phong
;;; SPDX-License-Identifier: GPL-3.0-or-later

(define-module (loftix transform)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages multiprecision)
  #:use-module (guix build-system cmake)
  #:use-module (guix fossil-download)
  #:use-module (guix gexp)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages)
  #:use-module (guix utils))

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
