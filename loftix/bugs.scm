;;; Packages with bugs
;;;
;;; SPDX-FileCopyrightText: 2012, 2014-2015 Ludovic Courtès
;;; SPDX-FileCopyrightText: 2013 Andreas Enge
;;; SPDX-FileCopyrightText: 2014 Eric Bavier
;;; SPDX-FileCopyrightText: 2014-2015 David Thompson
;;; SPDX-FileCopyrightText: 2016 Efraim Flashner
;;; SPDX-FileCopyrightText: 2016 Tobias Geerinckx-Rice
;;; SPDX-FileCopyrightText: 2017, 2019 Marius Bakke
;;; SPDX-FileCopyrightText: 2024-2025 Nguyễn Gia Phong
;;; SPDX-License-Identifier: GPL-3.0-or-later

(define-module (loftix bugs)
  #:use-module (gnu packages)
  #:use-module (gnu packages autotools)
  #:use-module (gnu packages backup)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bison)
  #:use-module (gnu packages flex)
  #:use-module (gnu packages fontutils)
  #:use-module (gnu packages image)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages swig)
  #:use-module (gnu packages xml)
  #:use-module (guix build-system)
  #:use-module (guix build-system gnu)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages)
  #:use-module (guix utils)
  #:use-module (srfi srfi-26))

(define (at-version base version uri checksum)
  (package
    (inherit base)
    (version version)
    (source
     (origin
       (inherit (package-source base))
       (uri (uri version))
       (sha256 (base32 checksum))))))

(define (binutils-at-version base version checksum)
  (at-version
   (package
     (inherit base)
     (source
      (origin
        (inherit (package-source base))
        (patches '()))))
   version
   (cut string-append "mirror://gnu/binutils/binutils-" <> ".tar.bz2")
   checksum))

(define-public binutils-2.32
  (binutils-at-version
   binutils-2.33
   "2.32"
   "0b8767nyal1bc4cyzg5h9iis8kpkln1i3wkamig75cifj1fb2f6y"))

(define-public binutils-2.30
  (binutils-at-version
   binutils-2.33
   "2.30"
   "028cklfqaab24glva1ks2aqa1zxa6w6xmc8q34zs1sb7h22dxspg"))

(define-public binutils-2.29
  (binutils-at-version
   binutils-2.33
   "2.29"
   "1gqfyksdnj3iir5gzyvlp785mnk60g1pll6zbzbslfchhr4rb8i9"))

(define-public binutils-2.27
  (binutils-at-version
   binutils-2.33
   "2.27"
   "125clslv17xh1sab74343fg6v31msavpmaa1c1394zsqa773g5rn"))

(define (with-asan base)
  (package
    (inherit base)
    (name (string-append (package-name base) "-with-asan"))
    (arguments
     (case (build-system-name (package-build-system base))
       ((gnu)
        (substitute-keyword-arguments (package-arguments base)
          ((#:make-flags flags #~'())
           (with-imported-modules '((loftix transform))
             #~((@ (loftix transform) append-make-flag)
                #$flags
                '(("CFLAGS" "-fsanitize=address" "-O2 -g")
                  ("LDFLAGS" "-fsanitize=address")))))
          ((#:phases phases #~%standard-phases)
           #~(modify-phases #$phases
               (add-before 'build 'set-env
                 (lambda _
                   (setenv "ASAN_OPTIONS" "detect_leaks=0")))))
          ((#:tests? _ #f)
           #f)))))))

(define-public binutils-with-asan-2.32 (with-asan binutils-2.32))
(define-public binutils-with-asan-2.30 (with-asan binutils-2.30))
(define-public binutils-with-asan-2.29 (with-asan binutils-2.29))
(define-public binutils-with-asan-2.27 (with-asan binutils-2.27))

(define-public coreutils-8.27
  (package
    (inherit coreutils)
    (version "8.27")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "mirror://gnu/coreutils/coreutils-" version
                           ".tar.xz"))
       (sha256 (base32 "0sv547572iq8ayy8klir4hnngnx92a9nsazmf1wgzfc7xr4x74c8"))
       (patches (search-patches
                 "patches/coreutils-gnulib-glibc-2.28.patch"))))))

(define-public coreutils-with-asan-8.27 (with-asan coreutils-8.27))

(define (coreutils-at-version base version checksum)
  (at-version
   base
   version
   (cut string-append "mirror://gnu/coreutils/coreutils-" <> ".tar.xz")
   checksum))

(define-public coreutils-8.26
  (coreutils-at-version
   coreutils-8.27
   "8.26"
   "13lspazc7xkviy93qz7ks9jv4sldvgmwpq36ghrbrqpq93br8phm"))

(define (with-patches base . patches)
  (package
    (inherit base)
    (source
     (origin
       (inherit (package-source base))
       (patches (append (origin-patches (package-source base))
                        (map search-patch patches)))))))

(define coreutils-8.26-sans-4954f79
  (with-patches (package
                  (inherit coreutils-8.26)
                  (version "8.26-sans-4954f79"))
                "patches/bugs/coreutils-unfix-bug-25003.patch"))

(define-public coreutils-with-asan-8.26-sans-4954f79
  (with-asan coreutils-8.26-sans-4954f79))

(define-public coreutils-8.25
  (with-patches
   (coreutils-at-version
    coreutils-8.27
    "8.25"
    "11yfrnb94xzmvi4lhclkcmkqsbhww64wf234ya1aacjvg82prrii")
   "patches/coreutils-gnulib-glibc-2.25.patch"))

(define-public coreutils-with-asan-8.25 (with-asan coreutils-8.25))

(define-public coreutils-8.23
  (coreutils-at-version
    coreutils-8.25
    "8.23"
    "0bdq6yggyl7nkc2pbl6pxhhyx15nyqhz3ds6rfn448n6rxdwlhzc"))

(define-public coreutils-with-make-prime-list-with-asan-8.23
  (let ((base (with-asan coreutils-8.23)))
    (package
      (inherit base)
      (name "coreutils-with-make-prime-list-with-asan")
      (arguments
        (substitute-keyword-arguments (package-arguments base)
          ((#:phases phases #~%standard-phases)
           #~(modify-phases #$phases
              (add-after 'install 'install-make-prime-list
               (lambda* (#:key outputs #:allow-other-keys)
                 (install-file
                  "src/make-prime-list"
                  (string-append (assoc-ref outputs "out") "/bin")))))))))))

(define (jasper-at-version version checksum)
  (package
    (inherit jasper)
    (version version)
    (source (origin
              (method url-fetch)
              (uri (string-append "https://www.ece.uvic.ca/~frodo/jasper"
                                  "/software/jasper-" version ".tar.gz"))
              (sha256 (base32 checksum))
              (patches (search-patches
                        "patches/jasper-no-define-int-types.patch"))))
    (build-system gnu-build-system)
    (inputs (list ijg-libjpeg))))

(define-public jasper-1.900.19
  (jasper-at-version "1.900.19"
                     "0dm3k0wdny3s37zxm9s9riv46p69c14bnn532fv6cv5b6l1b0pwb"))

(define (with-ubsan base)
  (package
    (inherit base)
    (name (string-append (package-name base) "-with-ubsan"))
    (arguments
     (case (build-system-name (package-build-system base))
       ((gnu)
        (substitute-keyword-arguments (package-arguments base)
          ((#:make-flags flags #~'())
           (with-imported-modules '((loftix transform))
             #~((@ (loftix transform) append-make-flag)
                #$flags
                '(("CFLAGS"
                   "-fsanitize=undefined -fno-sanitize-recover=undefined"
                   "-O2 -g")
                  ("LDFLAGS" "-fsanitize=undefined")))))
          ((#:tests? _ #f)
           #f)))))))

(define-public jasper-with-ubsan-1.900.19
  (with-ubsan jasper-1.900.19))

(define-public jasper-1.900.5
  (jasper-at-version "1.900.5"
                     "1fvy4ngc6064g128q4484qpinsn05y9qw6lrccc4czhalla2w26m"))

;; TODO: static build for taosc.
(define-public jasper-1.900.3
  (jasper-at-version "1.900.3"
                     "106xwiyn40k5yrnny198mzscvyd18rza9clhd2nl6xvcsz73swrn"))

(define-public libarchive-3.2.0
  (package
    (inherit libarchive)
    (name "libarchive")
    (version "3.2.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://libarchive.org/downloads/libarchive-"
                                  version ".tar.gz"))
              (sha256
               (base32 "11xabdpmvdmcdkidigmqh4ymhra95lr7ipcys4hdq0gzf7ylbkkv"))
              (patches '())))))

(define-public libarchive-with-ubsan-3.2.0
  (with-ubsan libarchive-3.2.0))

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

(define-public libjpeg-turbo-1.5.3-asan
  (package
    (inherit libjpeg-turbo-1.5.2)
    (name "libjpeg-turbo")
    (version "1.5.3")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://sourceforge/libjpeg-turbo/"
                                  version "/libjpeg-turbo-" version ".tar.gz"))
              (sha256
               (base32
                "08r5b5mywwrxv4axvq80dm31cklz81grczlzlxr2xqa6pgi90j5j"))))
    (arguments '(#:make-flags '("CFLAGS=-O2 -g -fsanitize=address"
                                "LDFLAGS=-static -fsanitize=address")))))

(define-public libjpeg-turbo-1.2.0-asan
  (package
    (inherit libjpeg-turbo-1.5.3-asan)
    (name "libjpeg-turbo")
    (version "1.2.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://sourceforge/libjpeg-turbo/"
                                  version "/libjpeg-turbo-" version ".tar.gz"))
              (sha256
               (base32
                "13pra36wn2djw2aq5vvbaf81m9jxdjixvpd8bw71nni9n6lv57b2"))))))

(define-public libjpeg-turbo-2.0.1-asan
  (package
    (inherit libjpeg-turbo)
    (name "libjpeg-turbo")
    (version "2.0.1")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://sourceforge/libjpeg-turbo/"
                                  version "/libjpeg-turbo-" version ".tar.gz"))
              (sha256
               (base32
                "1zv6z093l3x3jzygvni7b819j7xhn6d63jhcdrckj7fz67n6ry75"))))
    (arguments '(#:phases (modify-phases %standard-phases
                            (add-before 'configure 'set-env
                              (lambda _
                                (setenv "CFLAGS" "-O2 -g -fsanitize=address")
                                (setenv "LDFLAGS" "-fsanitize=address"))))
                 #:configure-flags '("-DCMAKE_INSTALL_LIBDIR:PATH=lib")))))

(define-public libming-0.4.8-asan
  (package
    (name "libming")
    (version "0.4.8")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/libming/libming")
                    (commit "ming-0_4_8")))
              (sha256
               (base32 "0bky2spbzrlrwrj6pg8k0mn3zm1jjnyyj2b0whv29j469hpjfn5m"))
              (file-name (git-file-name name version))
              (patches (search-patches
                         "patches/libming-parallel-make.patch"))))
    (build-system gnu-build-system)
    (arguments '(#:make-flags '("CFLAGS=-O2 -g -fcommon -fsanitize=address"
                                "LDFLAGS=-static -fsanitize=address")
                 #:tests? #f))
    (native-inputs (list autoconf automake bison flex libtool pkgconf swig))
    (inputs (list freetype giflib libpng))
    (synopsis "SWF output library")
    (description "Ming is a Flash (SWF) output library.
It can be used from PHP, Perl, Ruby, Python, C, C++ and Java.")
    (home-page "https://github.com/libming/libming")
    (license (list license:lgpl2.1+ license:gpl2+))))

(define-public libming-0.4.7-asan
  (package
    (inherit libming-0.4.8-asan)
    (name "libming")
    (version "0.4.7")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/libming/libming")
                    (commit "ming-0_4_7")))
              (sha256
               (base32 "17ngz1n1mnknixzchywkhbw9s3scad8ajmk97gx14xbsw1603gd2"))
              (file-name (git-file-name name version))
              (patches (search-patches
                         "patches/libming-parallel-make.patch"))))))

(define-public libtiff-4.0.3
  (package
    (inherit libtiff)
    (version "4.0.3")
    (source (origin
             (method url-fetch)
             (uri (string-append "ftp://ftp.remotesensing.org/pub/libtiff/tiff-"
                    version ".tar.gz"))
             (sha256
              (base32 "0wj8d1iwk9vnpax2h29xqc2hwknxg3s0ay2d5pxkg59ihbifn6pa"))))
    (outputs '("out"))))

(define-public libtiff-4.0.6
  (package
    (inherit libtiff)
    (version "4.0.6")
    (source (origin
              (method url-fetch)
              (uri (string-append
                     "ftp://ftp.remotesensing.org/pub/libtiff/tiff-" version
                     ".tar.gz"))
              (sha256
               (base32
                "136nf1rj9dp5jgv1p7z4dk0xy3wki1w0vfjbk82f645m0w4samsd"))))
    (arguments '(#:make-flags '("LDFLAGS=-static")))
    (outputs '("out"))))

(define-public libtiff-4.0.6-asan
  (package
    (inherit libtiff-4.0.6)
    (arguments '(#:make-flags '("CFLAGS=-O2 -g -fsanitize=address"
                                "LDFLAGS=-static -fsanitize=address")))))

(define-public libtiff-4.0.7
  (package
    (inherit libtiff)
    (version "4.0.7")
    (source (origin
              (method url-fetch)
              (uri (string-append "ftp://download.osgeo.org/libtiff/tiff-"
                                  version ".tar.gz"))
              (sha256
               (base32
                "06ghqhr4db1ssq0acyyz49gr8k41gzw6pqb6mbn5r7jqp77s4hwz"))))
    (outputs '("out"))))

(define-public libtiff-4.0.7-asan
  (package
    (inherit libtiff-4.0.7)
    (arguments '(#:make-flags '("CFLAGS=-O2 -g -fsanitize=address"
                                "LDFLAGS=-static -fsanitize=address")))))

(define-public libtiff-4.0.7-ubsan
  (package
    (inherit libtiff-4.0.7)
    (arguments '(#:make-flags
                 (list (string-append
                         "CFLAGS=-O2 -g -fsanitize=undefined"
                         " -fno-sanitize-recover=undefined")
                       "LDFLAGS=-static -fsanitize=undefined")
                 ;; Tests fail with ubsan enabled^
                 #:tests? #f))))

(define-public libtiff-4.0.7-ubsan-float-cast-overflow
  (package
    (inherit libtiff-4.0.7)
    (arguments '(#:make-flags
                 (list (string-append
                         "CFLAGS=-O2 -g -fsanitize=float-cast-overflow"
                         " -fno-sanitize-recover=float-cast-overflow")
                       "LDFLAGS=-static -fsanitize=float-cast-overflow")))))

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
    (arguments '(#:make-flags '("LDFLAGS=-static")))
    ;; $XML_CATALOG_FILES lists 'catalog.xml' files found in under the 'xml'
    ;; sub-directory of any given package.
    (native-search-paths (list (search-path-specification
                                (variable "XML_CATALOG_FILES")
                                (separator " ")
                                (files '("xml"))
                                (file-pattern "^catalog\\.xml$")
                                (file-type 'regular))))
    (search-paths native-search-paths)))

(define-public libxml2-2.9.3-asan
  (package
    (inherit libxml2-2.9.4)
    (name "libxml2")
    (version "2.9.3")
    (source (origin
              (method url-fetch)
              (uri (string-append "ftp://xmlsoft.org/libxml2/libxml2-"
                                  version ".tar.gz"))
              (sha256
               (base32
                "0bd17g6znn2r98gzpjppsqjg33iraky4px923j3k8kdl8qgy7sad"))))
    (arguments '(#:make-flags '("CFLAGS=-O2 -g -fsanitize=address"
                                "LDFLAGS=-static -fsanitize=address")
                 ;; Tests fail with ASan enabled^
                 #:tests? #f))))

(define-public libxml2-2.9.0-asan
  (package
    (inherit libxml2-2.9.3-asan)
    (name "libxml2")
    (version "2.9.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "ftp://xmlsoft.org/libxml2/libxml2-"
                                  version ".tar.gz"))
              (sha256
               (base32
                "10ib8bpar2pl68aqksfinvfmqknwnk7i35ibq6yjl8dpb0cxj9dd"))))))

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
