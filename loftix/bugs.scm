;;; Packages with bugs
;;;
;;; SPDX-FileCopyrightText: 2012, 2014-2015 Ludovic Courtès
;;; SPDX-FileCopyrightText: 2013 Andreas Enge
;;; SPDX-FileCopyrightText: 2014 Eric Bavier
;;; SPDX-FileCopyrightText: 2015 David Thompson
;;; SPDX-FileCopyrightText: 2016 Efraim Flashner
;;; SPDX-FileCopyrightText: 2016 Tobias Geerinckx-Rice
;;; SPDX-FileCopyrightText: 2017, 2019 Marius Bakke
;;; SPDX-FileCopyrightText: 2024-2025 Nguyễn Gia Phong
;;; SPDX-License-Identifier: GPL-3.0-or-later

(define-module (loftix bugs)
  #:use-module (gnu packages base)
  #:use-module (gnu packages fontutils)
  #:use-module (gnu packages image)
  #:use-module (gnu packages xml)
  #:use-module (guix build-system gnu)
  #:use-module (guix download)
  #:use-module (guix packages))

(define-public binutils-2.32-asan
  (package
    (inherit binutils-2.33)
    (version "2.32")
    (source (origin
              (inherit (package-source binutils))
              (uri (string-append "mirror://gnu/binutils/binutils-"
                                  version ".tar.bz2"))
              (sha256
               (base32 "0b8767nyal1bc4cyzg5h9iis8kpkln1i3wkamig75cifj1fb2f6y"))
              (patches '())))
    (arguments '(#:phases (modify-phases %standard-phases
                            (add-before 'build 'set-env
                              (lambda _
                                (setenv "ASAN_OPTIONS" "detect_leaks=0"))))
                 #:make-flags '("CFLAGS=-O2 -g -fsanitize=address"
                                "LDFLAGS=-fsanitize=address")))))

(define-public binutils-2.29-asan
  (package
    (inherit binutils-2.32-asan)
    (version "2.29")
    (source (origin
              (inherit (package-source binutils))
              (uri (string-append "mirror://gnu/binutils/binutils-"
                                  version ".tar.bz2"))
              (sha256
               (base32 "1gqfyksdnj3iir5gzyvlp785mnk60g1pll6zbzbslfchhr4rb8i9"))
              (patches '())))))

(define-public binutils-2.27-asan
  (package
    (inherit binutils-2.29-asan)
    (version "2.27")
    (source (origin
              (inherit (package-source binutils))
              (uri (string-append "mirror://gnu/binutils/binutils-"
                                  version ".tar.bz2"))
              (sha256
               (base32 "125clslv17xh1sab74343fg6v31msavpmaa1c1394zsqa773g5rn"))
              (patches '())))))

(define-public jasper-1.900.19
  (package
    (inherit jasper)
    (name "jasper")
    (version "1.900.19")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://www.ece.uvic.ca/~frodo/jasper"
                                  "/software/jasper-" version ".tar.gz"))
              (sha256
               (base32
                "0dm3k0wdny3s37zxm9s9riv46p69c14bnn532fv6cv5b6l1b0pwb"))))
    (build-system gnu-build-system)
    (inputs (list ijg-libjpeg))))

(define-public libjpeg-turbo-1.5.2
  (package
    (inherit libjpeg-turbo)
    (name "libjpeg-turbo")
    (version "1.5.2")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://sourceforge/libjpeg-turbo/"
                                  version "/libjpeg-turbo-" version ".tar.gz"))
              (sha256
               (base32
                "0a5m0psfp5952y5vrcs0nbdz1y9wqzg2ms0xwrx752034wxr964h"))))
    (build-system gnu-build-system)
    (arguments '(#:make-flags '("LDFLAGS=-static")
                 #:test-target "test"))))

(define-public libxml2-2.9.4
  (package
    (inherit libxml2)
    (name "libxml2")
    (version "2.9.4")
    (source (origin
              (method url-fetch)
              (uri (string-append "ftp://xmlsoft.org/libxml2/libxml2-"
                                  version ".tar.gz"))
              (sha256
               (base32
                "0g336cr0bw6dax1q48bblphmchgihx9p1pjmxdnrd6sh3qci3fgz"))))
    ;; $XML_CATALOG_FILES lists 'catalog.xml' files found in under the 'xml'
    ;; sub-directory of any given package.
    (native-search-paths (list (search-path-specification
                                (variable "XML_CATALOG_FILES")
                                (separator " ")
                                (files '("xml"))
                                (file-pattern "^catalog\\.xml$")
                                (file-type 'regular))))
    (search-paths native-search-paths)))

(define-public potrace-1.11
  (package
    (inherit potrace)
    (name "potrace")
    (version "1.11")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://sourceforge/potrace/potrace-"
                                  version ".tar.gz"))
              (sha256
                (base32
                  "1bbyl7jgigawmwc8r14znv8lb6lrcxh8zpvynrl6s800dr4yp9as"))))
    ;; Tests are failing on newer Ghostscript versions
    (native-inputs '())
    (arguments '(#:tests? #f))))
