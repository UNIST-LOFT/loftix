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

(define-module (loftix synthesis)
  #:use-module (gnu packages debug)
  #:use-module (gnu packages elf)
  #:use-module (gnu packages instrumentation)
  #:use-module (gnu packages m4)
  #:use-module (gnu packages parallel)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-build)
  #:use-module (gnu packages python-xyz)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system pyproject)
  #:use-module (guix build-system python)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages)
  #:use-module (loftix fuzzing)
  #:use-module (loftix patching))

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

(define-public taosc
  (package
    (name "taosc")
    (version "0.0.1")
    (source
      (origin
        (method url-fetch)
        (uri (string-append
               "https://trong.loang.net/~cnx/taosc/snapshot/taosc-"
               version ".tar.gz"))
        (sha256
          (base32 "08rjivhg3brx6n5jgxfwcqbwb3ranrvjxwrdbqd8pwrpfa5jhqy2"))))
    (build-system gnu-build-system)
    (arguments
      (list #:make-flags #~(list (string-append "PREFIX=" #$output))
            #:phases
            #~(modify-phases %standard-phases
                (delete 'configure)
                (delete 'check)
                (add-after 'install 'wrap
                  (lambda* (#:key inputs outputs #:allow-other-keys)
                    (wrap-program (search-input-file outputs "bin/taosc-synth")
                      `("GUIX_PYTHONPATH" = (,(getenv "GUIX_PYTHONPATH")))))))
            #:validate-runpath? #f))
    (native-inputs (list m4))
    (inputs (list dyninst))
    (propagated-inputs (list afl-dyninst aflplusplus
                             e9patch patchelf
                             python python-pacfix
                             parallel))
    (synopsis "Emergency binary patcher")
    (description "Taosc generates emergent fixes for binaries.")
    (home-page "https://trong.loang.net/~cnx/taosc")
    (license license:agpl3+)))
