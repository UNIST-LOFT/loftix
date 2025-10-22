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

(define-public qemu-for-aflplusplus
  (let ((base qemu-minimal)
        (commit "d3e827420061a11debc2d4baca3518de42177e3d")
        (revision "0"))
    (hidden-package
     (package
       (inherit base)
       (name "qemu")
       (version (git-version "5.2.50" revision commit))
       (source
        (origin
          (method git-fetch)
          (uri (git-reference (url "https://github.com/AFLplusplus/qemuafl")
                              (commit commit)
                              (recursive? #t)))
          (file-name (git-file-name name version))
          (sha256
           (base32 "1wffly2aphny0wvcmwlyvq73b6gwglgchvjx8m8gj3gkdrcgwark"))))
       (arguments
        (substitute-keyword-arguments (package-arguments base)
          ((#:configure-flags _ #~'())
           #~(list (string-append
                    "--target-list="
                    ;; AFL++ only supports using a single afl-qemu-trace,
                    ;; so we only build qemu for the native target.
                    (match #$(let-system system system)
                      ("aarch64-linux"  "aarch64-linux-user")
                      ("armhf-linux"    "arm-linux-user")
                      ("i686-linux"     "i386-linux-user")
                      ("mips64el-linux" "mips64el-linux-user")
                      ("powerpc-linux"  "ppc-linux-user")
                      ("riscv64-linux"  "riscv64-linux-user")
                      ("x86_64-linux"   "x86_64-linux-user")))))
          ((#:phases phases)
           #~(modify-phases #$phases
               (delete 'replace-firmwares)
               (delete 'patch-embedded-shebangs)
               (delete 'fix-optionrom-makefile)
               (delete 'disable-unusable-tests)
               (replace 'configure
                 (lambda* (#:key configure-flags #:allow-other-keys)
                   ;; The `configure' script doesn't understand some of the
                   ;; GNU options.  Thus, add a new phase that's compatible.
                   (setenv "SHELL" (which "bash"))
                   ;; The binaries need to be linked against -lrt.
                   (setenv "LDFLAGS" "-lrt")
                   (apply invoke
                          "./configure"
                          (string-append "--cc=" #$(cc-for-target))
                          ;; Some architectures insist on using HOST_CC
                          (string-append "--host-cc=" #$(cc-for-target))
                          "--disable-debug-info" ; save build space
                          (string-append "--prefix=" #$output)
                          (string-append "--sysconfdir=/etc")
                          configure-flags)))
               (add-after 'install 'install-qasan-header
                 (lambda _
                   (install-file "qemuafl/qasan.h"
                                 (string-append #$output "/include"))))
               (delete 'delete-firmwares)))))
       (home-page "https://github.com/AFLplusplus/qemuafl")
       (synopsis "QEMU for AFL++")))))

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
                       "./configure"
                       (string-append "--cc=" (which "gcc"))
                       ;; Some architectures insist on using HOST_CC
                       (string-append "--host-cc=" (which "gcc"))
                       "--disable-debug-info" ; save build space
                       (string-append "--prefix=" out)
                       (string-append "--sysconfdir=/etc")
                       configure-flags))))
               (add-after 'install 'install-symbolic-header
                 (lambda* (#:key outputs #:allow-other-keys)
                   (install-file
                    "tcg/symbolic/symbolic-struct.h"
                    (string-append (assoc-ref outputs "out")
                                   "/include/qemu/tcg/symbolic"))))
               (delete 'install-plugins)
               (delete 'delete-firmwares)))))
       (native-inputs
        (modify-inputs (package-native-inputs base)
          ;; gcc-toolchain still defaults to version 11 unless on hurd64,
          ;; which fails to include linux/mount.h in glibc>=2.36's sys/mount.h,
          ;; causing compilation failure due to redefinition:
          ;; https://gcc.gnu.org/bugzilla/show_bug.cgi?id=91085
          (prepend gcc-toolchain-14)))))))
