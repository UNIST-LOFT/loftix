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
               (base32
                "1gqfyksdnj3iir5gzyvlp785mnk60g1pll6zbzbslfchhr4rb8i9"))
              (patches '())))))
