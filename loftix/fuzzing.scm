;;; Packages for software fuzzing
;;;
;;; SPDX-FileCopyrightText: 2024 Nguyễn Gia Phong
;;; SPDX-License-Identifier: GPL-3.0-or-later

(define-module (loftix fuzzing)
  #:use-module (gnu packages)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages debug)
  #:use-module (gnu packages instrumentation)
  #:use-module (gnu packages man)
  #:use-module (gnu packages m4)
  #:use-module (guix build-system gnu)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages)
  #:use-module (guix utils))

(define-public afl-dyninst
  (package
    (name "afl-dyninst")
    (version "1.0.0")
    (source
      (origin
        (method url-fetch)
        (uri (string-append
               "https://trong.loang.net/~cnx/afl-dyninst/snapshot/afl-dyninst-"
               version ".tar.gz"))
        (sha256
          (base32 "13gxrsn2fwh5qazqy142v6g7mxhwfpq4f07h05fd1w4r46yh1v00"))))
    (build-system gnu-build-system)
    (arguments
      (list #:make-flags
            #~(list (string-append "DYNINST_LIB="
                                   (assoc-ref %build-inputs "dyninst")
                                   "/lib")
                    (string-append "PREFIX=" #$output))
            #:phases #~(modify-phases %standard-phases
                         (delete 'configure)
                         (delete 'check))))
    (native-inputs (list m4 help2man))
    (inputs (list aflplusplus dyninst))
    (synopsis "Dyninst integration for AFL++")
    (description "Dyninst integration for AFL++")
    (home-page "https://trong.loang.net/~cnx/afl-dyninst")
    (license (list license:agpl3+ license:asl2.0))))

(define-public evocatio
  (let ((commit "fc8f6dc5bbdf5f49cf1231e746a7944efa09dcc7")
        (revision "0"))
    (package
      (inherit aflplusplus)
      (name "evocatio")
      (version (git-version "3.15a" revision commit))
      (source (origin
                (method git-fetch)
                (uri (git-reference
                      (url "https://github.com/HexHive/Evocatio")
                      (commit commit)))
                (file-name (git-file-name name version))
                (sha256
                 (base32
                  "16kc2xa4dk9lq1sg7sl5489n7r3p8kc6hmfgy0gh7i1n6h269bry"))
                (patches
                 (search-patches
                   "patches/evocatio-argv-fuzz-amd64-only.patch"))))
      (arguments
        (substitute-keyword-arguments (package-arguments aflplusplus)
          ((#:make-flags make-flags)
           #~(cons* "-C" "bug-severity-AFLplusplus"
                    "CFLAGS=-O2 -g -fcommon"
                    "NO_SPLICING=1"
                    #$make-flags))
          ((#:build-target _) "source-only")
          ((#:modules modules %default-gnu-modules)
           `((ice-9 string-fun) ,@modules))
          ((#:phases phases)
           #~(modify-phases #$phases
               (replace 'patch-gcc-path
                 (lambda* (#:key inputs #:allow-other-keys)
                   ;; AFL++ is prefixed with bug-severity-AFLplusplus
                   (substitute* "bug-severity-AFLplusplus/src/afl-cc.c"
                     (("alt_cc = \"gcc\";")
                      (format #f "alt_cc = \"~a\";"
                              (search-input-file inputs "bin/gcc")))
                     (("alt_cxx = \"g\\+\\+\";")
                      (format #f "alt_cxx = \"~a\";"
                              (search-input-file inputs "bin/g++"))))))
               (add-after 'build 'build-argv-fuzzing
                 (lambda* (#:key make-flags #:allow-other-keys)
                   (apply invoke
                     "make" "-C" "bug-severity-AFLplusplus/utils/argv_fuzzing"
                     (cdddr make-flags))))
               (add-after 'install 'install-argv-fuzzing
                 (lambda* (#:key make-flags #:allow-other-keys)
                   (apply invoke
                     "make" "-C" "bug-severity-AFLplusplus/utils/argv_fuzzing"
                     "install" (cdddr make-flags))))
               (add-after 'install 'install-scripts
                 (lambda* (#:key outputs #:allow-other-keys)
                   (let ((bin (string-append (assoc-ref outputs "out")
                                             "/bin")))
                     (for-each
                       (lambda (script)
                         (let ((file (string-append
                                       bin "/evocatio-"
                                       (string-replace-substring script
                                         "_" "-"))))
                           (copy-file (string-append "scripts/" script ".py")
                                      file)
                           (chmod file #o755)))
                       '("calculate_severity_score"
                         "gen_raw_data_for_cve")))))))))
      (home-page "https://github.com/HexHive/Evocatio")
      (description
        "Evocatio is a bug analyzer built on top of AFL++ and AddressSanitizer.
It automatically discovers a bug's capabilities: analyzing a crashing test case
(i.e., an input exposing a bug) to understand the full extent
of how an attacker can exploit a bug.

Evocatio leverages a capability-guided fuzzer to efficiently uncover
new bug capabilities (rather than only generating a single crashing test case
for a given bug, as a traditional greybox fuzzer does)."))))
