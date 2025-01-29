;;; Packages with bugs
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

(define-module (loftix bugs)
  #:use-module (gnu packages base)
  #:use-module (gnu packages fontutils)
  #:use-module (gnu packages image)
  #:use-module (guix build-system gnu)
  #:use-module (guix download)
  #:use-module (guix packages))

(define-public binutils-2.29
  (package
    (inherit binutils-2.33)
    (version "2.29")
    (source (origin
              (inherit (package-source binutils))
              (uri (string-append "mirror://gnu/binutils/binutils-"
                                  version ".tar.bz2"))
              (sha256
               (base32 "1gqfyksdnj3iir5gzyvlp785mnk60g1pll6zbzbslfchhr4rb8i9"))
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
              (uri (string-append "mirror://sourceforge/" name "/" version "/"
                                  name "-" version ".tar.gz"))
              (sha256
               (base32
                "0a5m0psfp5952y5vrcs0nbdz1y9wqzg2ms0xwrx752034wxr964h"))))
    (build-system gnu-build-system)
    (arguments '(#:test-target "test"))))

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
