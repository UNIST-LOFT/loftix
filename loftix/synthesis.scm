;;; Packages for software systhesis
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

(use-modules (gnu packages python)
             (gnu packages python-build)
             (gnu packages python-xyz)
             (guix build-system pyproject)
             (guix download)
             ((guix licenses) #:prefix license:)
             (guix packages))

(define-public python-pacfix
  (package
    (name "python-pacfix")
    (version "0.0.3")
    (source
      (origin
        (method url-fetch)
        (uri (pypi-uri "pacfix" version))
        (sha256
          (base32 "1gpr410gfwab5mg3k57r001mddqgxk9d5rbn89v1wczi51ljlsc5"))))
    (build-system pyproject-build-system)
    (native-inputs (list python-flit-core))
    (propagated-inputs (list python-pysmt))
    (arguments '(#:phases
                 (modify-phases %standard-phases
                   (replace 'check
                     (lambda* (#:key tests? #:allow-other-keys)
                       (when tests?
                         (invoke "python" "-m" "unittest" "-v")))))))
    (home-page "https://github.com/hsh814/pacfix-python")
    (synopsis "PAC-learning-based program systhesizer")
    (description "Pacfix systhesizes predicate expressions for program repair
from values in possitive and negative examples using a PAC learning algorithm.")
    (license license:expat)))
