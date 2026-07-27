;;; Experiment definitions for sdfuzz directed fuzzing
;;;
;;; SPDX-License-Identifier: GPL-3.0-or-later

(define-module (loftix sdfuzz-bugs)
  #:use-module (gnu packages llvm)
  #:use-module (guix build-system gnu)
  #:use-module (guix gexp)
  #:use-module (guix packages)
  #:use-module (guix utils)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (loftix bugs)
  #:use-module (loftix fuzzing))

(define (instrumented base)
  "Build BASE with sdfuzz's afl-clang-fast compiler for LLVM pass
instrumentation (no distance targeting)."
  (package
    (inherit base)
    (name (string-append (package-name base) "-sdfuzz"))
    (native-inputs
     (modify-inputs (package-native-inputs base)
       (prepend sdfuzz clang-13 llvm-13)))
    (arguments
     (substitute-keyword-arguments (package-arguments base)
       ((#:make-flags flags #~'())
        #~(cons* (string-append
                  "CC=" #$(file-append sdfuzz "/bin/afl-clang-fast"))
                 (string-append
                  "CXX=" #$(file-append sdfuzz "/bin/afl-clang-fast++"))
                 (string-append
                  "AFL_PATH=" #$(file-append sdfuzz "/lib/afl"))
                 #$flags))
       ((#:phases phases)
        #~(modify-phases #$phases
            (add-before 'configure 'set-sdfuzz-env
              (lambda* (#:key inputs #:allow-other-keys)
          (let ((sdfuzz (assoc-ref inputs "sdfuzz")))
            (setenv "AFL_PATH" (string-append sdfuzz "/lib/afl"))
            (setenv "CC" (string-append sdfuzz "/bin/afl-clang-fast"))
            (setenv "CXX"
              (string-append sdfuzz "/bin/afl-clang-fast++")))
                (setenv "PATH"
                        (string-append (assoc-ref inputs "clang") "/bin:"
                                       (assoc-ref inputs "llvm") "/bin:"
                                       (getenv "PATH")))
          (format #t "Using SDFuzz compilers from ~a~%"
            (assoc-ref inputs "sdfuzz"))))))))
    (synopsis (string-append (package-synopsis base)
                              " (sdfuzz-instrumented)"))
    (description (string-append (package-description base)
                                " This variant is instrumented with"
                                " sdfuzz's LLVM pass for directed"
                                " fuzzing."))))

;; libtiff experiments (11 CVEs)
(define-public libtiff-sdfuzz-4.0.6
  (instrumented libtiff-4.0.6))
(define-public libtiff-sdfuzz-4.0.7
  (instrumented libtiff-4.0.7))

;; binutils experiments (4 CVEs)
(define-public binutils-sdfuzz-2.27
  (instrumented binutils-2.27))
(define-public binutils-sdfuzz-2.29
  (instrumented binutils-2.29))

;; libxml2 experiments (3 CVEs)
(define-public libxml2-sdfuzz-2.9.0
  (instrumented libxml2-2.9.0))
(define-public libxml2-sdfuzz-2.9.3
  (instrumented libxml2-2.9.3))
(define-public libxml2-sdfuzz-2.9.4
  (instrumented libxml2-2.9.4))

;; libjpeg-turbo experiments (4 CVEs)
(define-public libjpeg-turbo-sdfuzz-1.2.0
  (instrumented libjpeg-turbo-1.2.0))
(define-public libjpeg-turbo-sdfuzz-1.5.2
  (instrumented libjpeg-turbo-1.5.2))
(define-public libjpeg-turbo-sdfuzz-1.5.3
  (instrumented libjpeg-turbo-1.5.3))
(define-public libjpeg-turbo-sdfuzz-2.0.1
  (instrumented libjpeg-turbo-2.0.1))

;; jasper experiments (2 CVEs)
(define-public jasper-sdfuzz-1.900.3
  (instrumented jasper-1.900.3))
(define-public jasper-sdfuzz-1.900.19
  (instrumented jasper-1.900.19))

;; zziplib experiments (2 CVEs)
(define-public zziplib-sdfuzz-0.13.62
  (instrumented zziplib-0.13.62))

;; potrace experiment (1 CVE)
(define-public potrace-sdfuzz-1.11
  (instrumented potrace-1.11))

;; libming experiments (3 CVEs)
(define-public libming-sdfuzz-0.4.7
  (instrumented libming-0.4.7))
(define-public libming-sdfuzz-0.4.8
  (instrumented libming-0.4.8))
