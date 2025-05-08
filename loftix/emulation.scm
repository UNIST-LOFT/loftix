;;; Emulator packages
;;;
;;; SPDX-FileCopyrightText: 2016 Ludovic Courtès
;;; SPDX-FileCopyrightText: 2019 Rutger Helling
;;; SPDX-FileCopyrightText: 2025 Nguyễn Gia Phong
;;; SPDX-License-Identifier: GPL-3.0-or-later

(define-module (loftix emulation)
  #:use-module (gnu packages)
  #:use-module (gnu packages commencement)
  #:use-module (gnu packages virtualization)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module (guix packages)
  #:use-module (guix utils))

(define-public qemu-for-fuzzolic
  (let ((base qemu-minimal)
        (base-version "4.1.1")
        (commit "a07b82d618b0ed16d7bf1822653a74821cf13dbd")
        (revision "symbolic"))
    (hidden-package
     (package
       (inherit base)
       (synopsis "QEMU with symbolic tracer")
       (name "qemu-for-fuzzolic")
       (version (git-version base-version revision commit))
       (home-page "https://github.com/season-lab/qemu")
       (source
        (origin
          (method url-fetch)
          (uri (string-append "https://download.qemu.org/qemu-"
                              base-version ".tar.xz"))
          (sha256
           (base32 "1lm1jndfpc5sydwrxyiz5sms414zkcg9jdl0zx318qbjsayxnvzd"))
          (patches
           (cons
             (origin
               (method url-fetch)
               (uri (string-append home-page "/compare/v" base-version
                                   ".." commit ".diff"))
               (sha256
                (base32 "1cqp0h0glz4pvq10lr7k9z5g9wjl6svlm51rapf3mbsvb1qy3rl1"))
               (file-name (string-append name ".patch")))
             (search-patches
              "patches/qemu-for-fuzzolic-test-opts-range-beyond.patch"
              "patches/qemu-for-fuzzolic-static-global.patch")))))
       (arguments
        (substitute-keyword-arguments (package-arguments base)
          ((#:configure-flags _ #~'())
           #~'("--target-list=x86_64-linux-user"))
          ((#:phases phases)
           #~(modify-phases #$phases
               (delete 'replace-firmwares)
               (delete 'patch-embedded-shebangs)
               (delete 'fix-optionrom-makefile)
               (delete 'disable-unusable-tests)
               (replace 'configure
                 (lambda* (#:key inputs outputs (configure-flags '())
                           #:allow-other-keys)
                   ;; The `configure' script doesn't understand some of the
                   ;; GNU options.  Thus, add a new phase that's compatible.
                   (let ((out (assoc-ref outputs "out")))
                     (setenv "SHELL" (which "bash"))
                     ;; The binaries need to be linked against -lrt.
                     (setenv "LDFLAGS" "-lrt")
                     (apply invoke
                            `("./configure"
                              ,(string-append "--cc=" (which "gcc"))
                              ;; Some architectures insist on using HOST_CC
                              ,(string-append "--host-cc=" (which "gcc"))
                              "--disable-debug-info" ; save build space
                              ,(string-append "--prefix=" out)
                              ,(string-append "--sysconfdir=/etc")
                              ,@configure-flags)))))
               (add-after 'install 'install-symbolic-header
                 (lambda* (#:key outputs #:allow-other-keys)
                   (install-file
                    "tcg/symbolic/symbolic-struct.h"
                    (string-append (assoc-ref outputs "out")
                                   "/include/qemu/tcg/symbolic"))))
               (delete 'delete-firmwares)))))
       (native-inputs
        (modify-inputs (package-native-inputs base)
          ;; gcc-toolchain still defaults to version 11 unless on hurd64,
          ;; which fails to include linux/mount.h in glibc>=2.36's sys/mount.h,
          ;; causing compilation failure due to redefinition:
          ;; https://gcc.gnu.org/bugzilla/show_bug.cgi?id=91085
          (prepend gcc-toolchain-14)))))))
