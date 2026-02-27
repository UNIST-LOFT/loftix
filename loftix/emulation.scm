;;; Emulator packages
;;;
;;; SPDX-FileCopyrightText: 2016 Ludovic Courtès
;;; SPDX-FileCopyrightText: 2019 Rutger Helling
;;; SPDX-FileCopyrightText: 2025 Nguyễn Gia Phong
;;; SPDX-License-Identifier: GPL-3.0-or-later

(define-module (loftix emulation)
  #:use-module (gnu packages)
  #:use-module (gnu packages commencement)
  #:use-module (gnu packages debug)
  #:use-module (gnu packages virtualization)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module (guix packages)
  #:use-module (guix utils))

(define-public qemu-for-fuzzolic
  (let ((base qemu-minimal)
        (base-version "4.1.1")
        (commit "5dd13fc54ade8ebeedfddf10a98dd2d672467bfd")
        (revision "0"))
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
                (base32 "0z36g2qq0ssqhhcqdzd03wqf21rbpvwwkzz545il32yh8wgdznib"))
               (file-name (string-append name ".patch")))
             (search-patches
              "patches/qemu-for-fuzzolic-test-opts-range-beyond.patch")))))
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
               ;; The `configure' script doesn't understand some of the
               ;; GNU options.  Thus, add a new phase that's compatible.
               (replace 'configure
                 (lambda* (#:key inputs configure-flags #:allow-other-keys)
                   (setenv "LDFLAGS" "-lrt")
                   (apply invoke
                     "./configure"
                     (string-append "--cc=" #$(cc-for-target))
                     ;; Some architectures insist on using HOST_CC.
                     (string-append "--host-cc=" #$(cc-for-target))
                     "--disable-debug-info" ; save build space
                     (string-append "--prefix=" #$output)
                     (string-append "--sysconfdir=/etc")
                     configure-flags)))
               (add-after 'install 'install-symbolic-header
                 (lambda* (#:key outputs #:allow-other-keys)
                   (install-file
                    "tcg/symbolic/symbolic-struct.h"
                    (string-append (assoc-ref outputs "out")
                                   "/include/qemu/tcg/symbolic"))))
               (delete 'install-plugins)
               (delete 'delete-firmwares)))))))))
