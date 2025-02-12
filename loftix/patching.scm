;;; Packages for software patching
;;;
;;; SPDX-FileCopyrightText: 2024 Nguyễn Gia Phong
;;; SPDX-License-Identifier: GPL-3.0-or-later

(define-module (loftix patching)
  #:use-module (gnu packages)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages elf)
  #:use-module (gnu packages engineering)
  #:use-module (gnu packages markup)
  #:use-module (gnu packages vim)
  #:use-module (guix build-system gnu)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages))

(define-public e9patch
  (let ((commit "061f8dd6d48c3a6441d8300e697696bf415683a4")
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
                  "0l4bzkdfxhsdsjh2gk2pas4kkw8y5yrsl7hx1hlnhx2q0vp60kv6"))
                (file-name (git-file-name name version))
                (patches (search-patches
                           ;; https://github.com/GJDuck/e9patch/pull/94
                           "patches/e9patch-zydis-4.1.0.patch"
                           ;; https://github.com/GJDuck/e9patch/pull/92
                           "patches/e9patch-check.patch"
                           ;; https://github.com/GJDuck/e9patch/pull/95
                           "patches/e9patch-check-intel-format.patch"
                           ;; https://github.com/GJDuck/e9patch/pull/93
                           "patches/e9patch-check-mov-imm.patch"
                           ;; https://github.com/GJDuck/e9patch/pull/97
                           "patches/e9patch-check-same_op_2.patch"))))
      (build-system gnu-build-system)
      (arguments (list #:phases #~(modify-phases %standard-phases
                                    (delete 'configure))
                       #:make-flags #~(list (string-append
                                              "PREFIX=" #$output))))
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
