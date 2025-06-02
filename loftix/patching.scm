;;; Packages for software patching
;;;
;;; SPDX-FileCopyrightText: 2024-2025 Nguyễn Gia Phong
;;; SPDX-License-Identifier: GPL-3.0-or-later

(define-module (loftix patching)
  #:use-module (gnu packages)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages elf)
  #:use-module (gnu packages engineering)
  #:use-module (gnu packages markup)
  #:use-module (gnu packages vim)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system python)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages))

(define-public e9patch
  (package
    (name "e9patch")
    (version "1.0.0-rc10")
    (home-page "https://github.com/GJDuck/e9patch")
    (source (origin
              (method git-fetch)
              (uri (git-reference (url home-page)
                                  (commit (string-append "v" version))))
              (sha256
               (base32
                "1l2pjxgr2mckpffvj7hf0sjvv3678138afjb0wc3f6c2zrcpspf8"))
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
                   license:gpl3+)))) ;rest

(define-public python-apted
  (let ((commit "828b3e3f4c053f7d35f0b55b0d5597e8041719ac")
        (revision "0"))
    (package
      (name "python-apted")
      (version (git-version "1.0.3" revision commit))
      (home-page "https://github.com/JoaoFelipe/apted")
      (source
       (origin
         (method git-fetch)
         (uri (git-reference (url home-page)
                             (commit commit)))
         (file-name (git-file-name name version))
         (sha256
          (base32 "1vw1sbn41cysmhr4ib58cw3hzs1xjxwb1d8r1yhrqgjk5q6ckjw7"))))
      (build-system python-build-system)
      (arguments
       (list #:phases #~(modify-phases %standard-phases
                          (replace 'check
                            (lambda* (#:key tests? #:allow-other-keys)
                              (when tests?
                                (invoke "python" "-m" "unittest")))))))
      (synopsis "APTED algorithm for the Tree Edit Distance")
      (description "This is a Python implementation of the APTED algorithm,
which supersedes the RTED algorithm for computing the tree edit distance.")
      (license license:expat))))
