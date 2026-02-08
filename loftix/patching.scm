;;; Packages for software patching
;;;
;;; SPDX-FileCopyrightText: 2024-2026 Nguyễn Gia Phong
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
  #:use-module (guix packages)
  #:use-module (guix utils))

(define-public e9patch
  (let ((commit "609e1347e11a679a8bd7b04996e9e7ea0f3ac63c")
        (revision "0"))
    (package
      (name "e9patch")
      (version (git-version "1.0.0" revision commit))
      (home-page "https://github.com/GJDuck/e9patch")
      (source
       (origin
         (method git-fetch)
         (uri (git-reference (url home-page)
                             (commit commit)))
         (sha256
          (base32 "1hb6v8m89wkwiig9bns94ixr3vcdhlzfnmbwk146nrj5n3gr09qx"))
         (file-name (git-file-name name version))
         (modules '((guix build utils)))
         ;; E9Patch is sensitive to Zydis version, including introduced bugs:
         ;; https://github.com/GJDuck/e9patch/pull/94#issuecomment-2525069952
         (patches (search-patches "patches/e9patch-zydis-4.1-compat.patch"))
         (snippet
          #~(begin
              ;; https://github.com/GJDuck/e9patch/pull/95
              (substitute* "test/regtest/print_intel.exp"
                (("^(lea r..,) (.*)" all prefix suffix)
                 (string-append prefix " qword ptr " suffix)))
              ;; https://github.com/GJDuck/e9patch/pull/93
              (substitute* (find-files "test/regtest" "\\.exp$")
                (("\\$0x8877665544332211")
                 "$-0x778899aabbccddef"))
              (substitute* "test/regtest/not_regex.exp"
                ((".*a.*")
                 ""))))))
      (build-system gnu-build-system)
      (arguments
       (list #:phases #~(modify-phases %standard-phases
                          (delete 'configure))
             #:make-flags #~(list (string-append "CC=" #$(cc-for-target))
                                  (string-append "PREFIX=" #$output))))
      (native-inputs (list markdown xxd))
      (inputs (list elfutils zycore zydis zlib))
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
      (license (list license:expat      ;src/e9patch/e9loader_*.cpp
                     license:gpl3+))))) ;rest
