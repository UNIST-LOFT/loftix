;;; Packages for software patching
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

(use-modules (gnu packages compression)
             (gnu packages elf)
             (gnu packages engineering)
             (gnu packages markup)
             (gnu packages vim)
             (guix build-system gnu)
             (guix git-download)
             ((guix licenses) #:prefix license:)
             (guix packages))

(define-public e9patch
  (let ((commit "b4e7175abb8bd49ebbb6d09c7057aa43ddacac10")
        (revision "0"))
    (package
      (name "e9patch")
      (version (git-version "1.0.0-dev" revision commit))
      (source (origin
                (method git-fetch)
                (uri (git-reference
                     (url "https://github.com/GJDuck/e9patch")
                     (commit commit)))
                (sha256
                 (base32
                  "0a9s7h43ryyl4bvn0sid0dq78v24bnbcf271smj1a8wvffsih0jy"))
                (file-name (git-file-name name version))
                (patches (search-patches
                           ;; https://github.com/GJDuck/e9patch/pull/94
                           "e9patch-devendor.patch"
                           ;; https://github.com/GJDuck/e9patch/pull/99
                           "e9patch-plugin-api-headers.patch"
                           ;; https://github.com/GJDuck/e9patch/pull/92
                           "e9patch-check.patch"
                           ;; https://github.com/GJDuck/e9patch/pull/95
                           "e9patch-check-intel-format.patch"
                           ;; https://github.com/GJDuck/e9patch/pull/88
                           "e9patch-check-mode.patch"
                           ;; https://github.com/GJDuck/e9patch/pull/93
                           "e9patch-check-mov-imm.patch"
                           ;; https://github.com/GJDuck/e9patch/issues/96
                           "e9patch-check-rflags.patch"
                           ;; https://github.com/GJDuck/e9patch/pull/97
                           "e9patch-check-same_op_2.patch"))))
      (build-system gnu-build-system)
      (arguments (list #:modules `((ice-9 string-fun) ; string-replace-substring
                                   ,@%default-gnu-modules)
                       #:phases
                       #~(modify-phases %standard-phases
                           (add-after 'unpack 'fix-prefix
                             (lambda _
                               (substitute* "Makefile"
                                 ;; https://github.com/GJDuck/e9patch/pull/87
                                 (("\\\\/usr")
                                  (string-replace-substring #$output "/" "\\/"))
                                 (("/usr") #$output))))
                           (delete 'configure))))
      (native-inputs (list markdown xxd))
      (inputs (list elfutils zycore zydis zlib))
      (home-page "https://github.com/GJDuck/e9patch")
      (synopsis "Static binary rewriting tool")
      (description
       "E9Patch is a static binary rewriting tool for x86-64 ELF binaries.
E9Patch is:
@itemize
@item Scalable: E9Patch can reliably rewrite large/complex binaries
      including web browsers (>100MB in size).
@item Compatible: The rewritten binary is a drop-in replacement of the original,
      with no additional dependencies.
@item Fast: E9Patch can rewrite most binaries in a few seconds.
@item Low Overheads: Both performance and memory.
@item Programmable: E9Patch is designed so that it can be easily integrated
      into other projects.
@end itemize")
      (license (list license:expat ;src/e9patch/e9loader_*.cpp
                     license:gpl3+))))) ;rest
