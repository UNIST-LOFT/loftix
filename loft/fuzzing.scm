(use-modules (gnu packages instrumentation)
             (gnu packages man)
             (gnu packages m4)
             (guix build-system gnu)
             (guix download)
             (guix git-download)
             ((guix licenses) #:prefix license:)
             (guix packages))

(define-public afl++
  (let ((commit "42fc9acf5bdd512608e3590a78749c2cd95ee5f3")
        (revision "0"))
    (package
      (inherit aflplusplus)
      (name "afl++")
      (version (git-version "4.22a" revision commit))
      (source (origin
                (method git-fetch)
                (uri (git-reference
                       (url "https://github.com/AFLplusplus/AFLplusplus")
                       (commit commit)))
                (sha256
                 (base32
                  "149f5r341v921lfmdr4s9yap4qrqzc41vc7rx5xlgb78m5lwprx8"))
               (patches (search-patches "afl++-keep-all-crashes.patch")))))))

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
    (inputs (list afl++ dyninst))
    (synopsis "Dyninst integration for AFL++")
    (description "Dyninst integration for AFL++")
    (home-page "https://trong.loang.net/~cnx/afl-dyninst")
    (license (list license:agpl3+ license:asl2.0))))
