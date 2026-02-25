;;; Packages for model checking
;;;
;;; SPDX-FileCopyrightText: 2026 Nguyễn Gia Phong
;;; SPDX-License-Identifier: GPL-3.0-or-later

(define-module (loftix model-checking)
  #:use-module (gnu packages java)
  #:use-module (gnu packages maths)
  #:use-module (guix build-system ant)
  #:use-module (guix gexp)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages)
  #:use-module (guix svn-download))

(define-public civl
  (package
    (name "civl")
    (version "1.22")
    (source
     (origin
       (method svn-fetch)
       (uri (svn-reference
             (url (string-append "svn://vsl.cis.udel.edu/civl/tags/" version))
             (revision 5854)))
       (file-name (simple-format #f "~a-~a-checkout" name version))
       (sha256
        (base32 "19slzis0gks1g10hr826w764a5q5irl2b30r6mr28cr67lvrfpv6"))))
    (build-system ant-build-system)
    (arguments
     (list
      #:jdk openjdk
      #:use-java-modules? #t
      #:tests? #f
      #:build-target "lib"
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'set-paths
            (lambda* (#:key inputs #:allow-other-keys)
              (substitute* "common.xml"
                (("^<project .*>" all)
                 (string-append all "\n  <property environment=\"env\"/>"))
                ((".*(taskdef|jacoco).*") ""))
              (substitute* "build.xml"
                ((".*<copy file=.*")
                  "")
                (("location=.*antlr4\\.jar.*/>")
                 "path=\"${env.CLASSPATH}\"/>"))
              (substitute* (find-files "mods" "^build\\.xml$")
                (("location=.*antlr3\\.runtime.*/>")
                 (simple-format #f "location=~s/>"
                   (search-input-file inputs "share/java/antlr3-3.5.2.jar")))
                (("location=.*antlr4\\.runtime.*/>")
                 (simple-format #f "location=~s/>"
                   (search-input-file
                    inputs "share/java/java-antlr4-runtime.jar"))))
              (substitute* "mods/dev.civl.mc/grammar/Command.g4"
                (("\\\\([\\.\\+/])" all escaped)
                 escaped))
              (substitute* (find-files "mods" "^module-info\\.java$")
                (("antlr3runtime")
                 "antlr3")
                (("antlr4runtime")
                 "java.antlr4.runtime"))
              (substitute* (find-files "mods/dev.civl.sarl"
                                       "^ConfigFactory\\.java$")
                (("\"why3\"")
                 (simple-format #f "~s"
                   (search-input-file inputs "bin/why3")))
                (("\"z3\"")
                 (simple-format #f "~s"
                   (search-input-file inputs "bin/z3"))))))
          (replace 'install
            (lambda* (#:key inputs #:allow-other-keys)
              (let ((bin (string-append #$output "/bin"))
                    (bin/civl (string-append #$output "/bin/civl"))
                    (share/java (string-append #$output "/share/java")))
                (for-each
                  (lambda (jar)
                    (install-file jar share/java))
                  (find-files "lib" "\\.jar$"))
                (mkdir-p bin)
                (with-output-to-file bin/civl
                  (lambda _
                    (format #t "#!~a~%~a -cp ~a dev.civl.mc.CIVL $*~%"
                      (search-input-file inputs "bin/sh")
                      (search-input-file inputs "bin/java")
                      (string-join (apply append
                                          (find-files share/java "\\.jar$")
                                          (map (lambda (input)
                                                 (find-files (cdr input)
                                                             "\\.jar$"))
                                               inputs))
                                   ":"))))
                (chmod bin/civl #o755)))))))
    (inputs (list antlr3 antlr4 why3 z3
                  java-antlr4-runtime java-stringtemplate))
    (home-page "https://vsl.cis.udel.edu/trac/civl/wiki")
    (synopsis "Concurrency intermediate verification language")
    (description "CIVL is a framework encompassing

@itemize
@item a programming language, CIVL-C, which adds to C
a number of concurrency primitives, as well as the 
to define functions in any scope.  Together, these features
make for a very expressive concurrent language
that can faithfully represent programs using various APIs
and parallel languages, such as MPI, OpenMP, CUDA, and Chapel.
CIVL-C also provides a number of primitives supporting verification.
@item a model checker which uses symbolic execution to verify
a number of safety properties of CIVL-C programs.  The model checker
can also be used to verify that two CIVL-C programs
are functionally equivalent.
@item a number of translators from various commonly-used
concurrency languages/APIs to CIVL-C (currently, MPI, OpenMP,
Pthreads, and CUDA).
@end itemize")
    (license license:gpl3)))
