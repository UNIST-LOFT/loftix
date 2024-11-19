(use-modules (gnu packages base)
             (guix packages))

(define-public binutils-2.29
  (package
    (inherit binutils-2.33)
    (version "2.29")
    (source (origin
              (inherit (package-source binutils))
              (uri (string-append "mirror://gnu/binutils/binutils-"
                                  version ".tar.bz2"))
              (sha256
               (base32
                "1gqfyksdnj3iir5gzyvlp785mnk60g1pll6zbzbslfchhr4rb8i9"))
              (patches '())))))
