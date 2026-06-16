;;; Guix extension for exposing common bugs
;;; SPDX-FileCopyrightText: 2026 Nguyễn Gia Phong
;;; SPDX-License-Identifier: GPL-3.0-or-later

(define-module (guix scripts expose)
  #:use-module (gnu packages)
  #:use-module (guix packages)
  #:use-module (guix scripts)
  #:use-module ((guix scripts build)
                #:select (%standard-build-options))
  #:use-module (guix store)
  #:use-module (guix ui)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-26)
  #:use-module (srfi srfi-37)
  #:export (guix-expose))

(define %packages
  `(("binutils"
     (("CVE-2017-6965" "2.27" "asan")
      ("readelf" "-w ~a"
       "cve/2017/6965/bug_3"
       "cve/2017/6965/bug_4"
       "cve/2017/6965/bug_6"
       "cve/2017/6965/bug_7"
       "cve/2017/6965/bug_8"
       "cve/2017/6965/bug_12"))
     (("CVE-2017-6966" "2.27" "asan")
      ("readelf" "-w ~a"
       "cve/2017/6965/bug_2"
       "cve/2017/6965/bug_5"
       "cve/2017/6965/bug_9"
       "cve/2017/6965/bug_10"
       "cve/2017/6965/bug_11"))
     (("CVE-2017-14745" "2.29")
      ("objdump -d ~a" "cve/2017/14745/crash_1"))
     (("CVE-2017-14939" "2.29" "asan")
      ("nm" "-l ~a" "cve/2017/14939/heapoverflow"))
     (("CVE-2017-14940" "2.29")
      ("nm" "-l ~a" "cve/2017/14940/nullderef"))
     (("CVE-2017-15020" "2.29" "asan")
      ("nm" "-l ~a" "cve/2017/15020/reproducer"))
     (("CVE-2017-15025" "2.29")
      ("nm" "-l ~a" "cve/2017/15025/3899.crashes.bin")
      ("objdump" "-S ~a" "cve/2017/15025/floatexception.elf"))
     (("CVE-2017-15938" "2.29" "asan")
      ("nm" "-l ~a" "cve/2017/15938/invalidread"))
     (("CVE-2018-10372" "2.30" "asan")
      ("readelf" "-w ~a" "cve/2018/10372/bug3"))
     (("CVE-2019-9077" "2.32" "asan")
      ("readelf" "-a ~a" "cve/2019/9077/hbo2")))
    ("jasper"
     (("CVE-2016-8691" "1.900.3")
      ("imginfo" "-f ~a" "cve/2016/8691/11.crash"))
     (("CVE-2016-9387" "1.900.5")
      ("imginfo" "-f ~a" "cve/2016/9387/jas_matrix.jp2"))
     (("CVE-2016-9557" "1.900.19" "ubsan")
      ("imginfo" "-f ~a" "cve/2016/9557/signed-int-overflow.jp2")))
    ("jq"
     (("CVE-2023-50246" "1.7" "asan")
      ("jq" ". ~a" "cve/2023/50246/heap-buffer-overflow.json"))
     (("CVE-2023-50268" "1.7" "ubsan")
      ("jq" "'.[0] != .[1]' ~a" "cve/2023/50268/119.json"))
     (("CVE-2024-23337" "1.7.1")
      ("jq" "-nf ~a" "cve/2024/23337/3262.json"))
     (("CVE-2024-53427" "1.7.1" "asan")
      ("jq" "'.[0] != .[1]' ~a"
       "cve/2024/53427/3196.json"
       "cve/2024/53427/3246.json"))
     (("CVE-2025-48060" "1.7.1" "asan")
      ("jq" "-nf ~a" "cve/2025/48060/3272.jq" "cve/2025/48060/3327.jq")))
    ("libarchive"
     (("CVE-2016-5844" "3.2.0" "ubsan")
      ("bsdtar" "-tf ~a" "cve/2016/5844/libarchive-signed-int-overflow.iso")))
    ("libjpeg-turbo"
     (("CVE-2012-2806" "1.2.0" "asan")
      ("djpeg" "~a" "cve/2012/2806/cnode0006-heap-buffer-overflow-796.jpg"))
     (("CVE-2017-15232" "1.5.2")
      ("djpeg" ,(string-join '("-crop 1x1+16+16" "-onepass" "-dither ordered"
                               "-dct float" "-colors 8" "-targa" "-grayscale"
                               "-outfile /dev/null" "~a")
                             " ")
       "cve/2017/15232/1.jpg"
       "cve/2017/15232/2.jpg"))
     (("CVE-2018-14498" "1.5.3" "asan")
      ("cjpeg" "-outfile /dev/null ~a"
       "cve/2018/14498/hbo_rdbmp.c:209_1.bmp"
       "cve/2018/14498/hbo_rdbmp.c:209_2.bmp"
       "cve/2018/14498/hbo_rdbmp.c:210_1.bmp"
       "cve/2018/14498/hbo_rdbmp.c:211_1.bmp"
       "cve/2018/14498/hbo_rdbmp.c:211_2.bmp"))
     (("CVE-2018-19664" "2.0.1" "asan")
      ("djpeg" "-colors 256 -bmp ~a"
       "cve/2018/19664/heap-buffer-overflow-2.jpg")))
    ("libming"
     (("CVE-2016-9265" "0.4.7")
      ("listmp3" "~a" "cve/2016/9265/34.mp3" "cve/2016/9265/45.mp3"))
     (("CVE-2018-8806" "0.4.8" "asan")
      ("swftophp" "~a" "cve/2018/8806/heap-use-after-free.swf"))
     (("CVE-2018-8964" "0.4.8" "asan")
      ("swftophp" "~a" "cve/2018/8964/heap-use-after-free.swf")))
    ("libtiff"
     (("CVE-2014-8128" "4.0.3")
      ("thumbnail" "~a /dev/null" "cve/2014/8128/03_thumbnail.tiff"))
     (("CVE-2016-3186" "4.0.6")
      ("gif2tiff" "~a -" "cve/2016/3186/crash.gif"))
     (("CVE-2016-3623" "4.0.6")
      ("rgb2ycbcr" "-v 0 ~a /dev/null"
       "tiff-4.0.6/test/images/logluv-3c-16b.tiff"))
     (("CVE-2016-5314" "4.0.6" "asan")
      ("rgb2ycbcr" "~a /dev/null" "cve/2016/5314/oobw.tiff"))
     (("CVE-2016-5321" "4.0.6")
      ("tiffcrop" "~a /dev/null" "cve/2016/5321/ill-read.tiff"))
     (("CVE-2016-9273" "4.0.6" "asan")
      ("tiffsplit" "~a" "cve/2016/9273/test049.tiff"))
     (("CVE-2016-9532" "4.0.6" "asan")
      ("tiffcrop" "~a /dev/null" "cve/2016/9532/heap-buffer-overflow.tiff"))
     (("CVE-2016-10092" "4.0.7" "asan")
      ("tiffcrop" "-i ~a /dev/null" "cve/2016/10092/heapoverflow.tiff"))
     (("CVE-2016-10093" "4.0.7" "asan")
      ("tiffcp" "-i ~a /dev/null" "cve/2016/10093/heapoverflow.tiff"))
     (("CVE-2016-10094" "4.0.7" "asan")
      ("tiff2pdf" "~a -o /dev/null" "cve/2016/10094/heapoverflow.tiff"))
     (("CVE-2016-10266" "4.0.7")
      ("tiffcp" "~a /dev/null" "cve/2016/10266/fpe.tiff"))
     (("CVE-2016-10267" "4.0.7")
      ("tiffmedian" "~a /dev/null" "cve/2016/10267/fpe.tiff"))
     (("CVE-2016-10268" "4.0.7" "asan")
      ("tiffcp" "-i ~a /dev/null" "cve/2016/10268/heapoverflow.tiff"))
     (("CVE-2016-10271" "4.0.7" "asan")
      ("tiffcrop" "-i ~a /dev/null" "cve/2016/10271/heapoverflow.tiff"))
     (("CVE-2016-10272" "4.0.7" "asan")
      ("tiffcrop" "-i ~a /dev/null" "cve/2016/10272/heapoverflow.tiff"))
     (("CVE-2017-5225" "4.0.7" "asan")
      ("tiffcp" "-p separate ~a /dev/null" "cve/2017/5225/2656.tiff")
      ("tiffcp" "-p contig ~a /dev/null" "cve/2017/5225/2657.tiff"))
     (("CVE-2017-7595" "4.0.7")
      ("tiffcp" "-i ~a /dev/null" "cve/2017/7595/fpe.tiff"))
     (("CVE-2017-7599" "4.0.7" "ubsan-float-cast-overflow")
      ("tiffcp" "-i ~a /dev/null" "cve/2017/7599/outside-short.tiff"))
     (("CVE-2017-7600" "4.0.7" "ubsan-float-cast-overflow")
      ("tiffcp" "-i ~a /dev/null" "cve/2017/7600/outside-unsigned-char.tiff"))
     (("CVE-2017-7601" "4.0.7" "ubsan")
      ("tiffcp" "-i ~a /dev/null" "cve/2017/7601/shift-long.tiff")))
    ("libxml2"
     (("CVE-2012-5134" "2.9.0" "asan")
      ("xmllint" "~a" "cve/2012/5134/bad.xml"))
      (("CVE-2016-1838" "2.9.3" "asan")
       ("xmllint" "~a" "cve/2016/1838/attachment_316158"))
      (("CVE-2016-1839" "2.9.3" "asan")
       ("xmllint" "--html ~a" "cve/2016/1839/asan_heap-oob"))
      (("CVE-2017-5969" "2.9.4")
       ("xmllint" "--recover ~a" "cve/2017/5969/crash-libxml2-recover.xml")))
    ("potrace"
     (("CVE-2013-7437" "1.11")
      ("potrace" "~a" "cve/2013/7437/1.bmp" "cve/2013/7437/2.bmp")))
    ("zziplib"
     (("CVE-2017-5974" "0.13.62" "asan")
      ("unzzipcat-mem" "~a" "cve/2017/5974/heap-overflow.zip"))
     (("CVE-2017-5975" "0.13.62" "asan")
      ("unzzipcat-mem" "~a" "cve/2017/5975/heap-overflow.zip"))
     (("CVE-2017-5976" "0.13.62" "asan")
      ("unzzipcat-mem" "~a" "cve/2017/5976/heap-overflow.zip"))
     (("CVE-2017-5977" "0.13.62" "asan")
      ("unzzipcat-mem" "~a" "cve/2017/5977/invalid-read.zip"))
     (("CVE-2017-5978" "0.13.62")
      ("unzzipcat-mem" "~a" "cve/2017/5978/oob-read.zip"))
     (("CVE-2017-5979" "0.13.62" "asan")
      ("unzzipcat-seeko" "~a" "cve/2017/5979/null-deref.zip"))
     (("CVE-2017-5980" "0.13.62")
      ("unzzipcat-mem" "~a" "cve/2017/5980/null-deref.zip"))
     (("CVE-2017-5981" "0.13.62")
      ("unzzipcat-seeko" "~a" "cve/2017/5981/fail-assert.zip")))))

(define (show-help)
  (display "Usage: guix expose BUG
Reproduce BUG.

  -l, --list             list supported bug identifiers
                         and their corresponding package specification
  -a, --static           use the statically-linked package variant
  -s, --sans-sans        use the package variant without sanitizers
  -p, --procedure=FILE   instead of printing the command that reproduce
                         the bug, run (proc prog args poc) with proc
                         defined in the Scheme module FILE as a lambda
  -L, --load-path=DIR    prepend DIR to the package module search path
  -h, --help             display this help and exit

Report bugs to: <https://github.com/UNIST-LOFT/loftix>
"))

(define %options
  (list (option '(#\l "list") #f #f
                (lambda _
                  (for-each (lambda (package)
                              (for-each (lambda (bug)
                                          (simple-format #t "~a\t~a@~a\n"
                                            (caar bug)
                                            (car package)
                                            (cadar bug)))
                                        (cdr package)))
                            %packages)
                  (exit 0)))
        (option '(#\p "procedure") #t #f
                (lambda (opt name arg result)
                  (alist-cons 'procedure
                              (if (string=? "-" arg)
                                  (read/eval (current-input-port))
                                  (call-with-input-file arg read/eval))
                              result)))
        (option '(#\a "static") #f #f
                (lambda (opt name arg result)
                  (alist-cons 'static? #t result)))
        (option '(#\s "sans-sans") #f #f
                (lambda (opt name arg result)
                  (alist-cons 'sans-sans? #t result)))
        (find (lambda (option)
                (member "load-path" (option-names option)))
              %standard-build-options)
        (option '(#\h "help") #f #f
                (lambda _
                   (leave-on-EPIPE (show-help))
                   (exit 0)))))

(define (search-bug packages identifier)
  (cond ((or (not identifier)
             (null? packages)) #f)
        ((find (lambda (bugs)
                 (string=? identifier (caar bugs)))
               (cdar packages))
         => (lambda (bug)
              (cons (cons (caar packages)
                          (cdar bug))
                    (cdr bug))))
        (else (search-bug (cdr packages)
                          identifier))))

(define %default-procedure
  (cons 'procedure
        (lambda (prog args poc)
          (simple-format #t "~a ~a\n" prog (simple-format #f args poc)))))

(define-command (guix-expose . args)
                (category extension)
                (synopsis "expose common bugs")
  (let* ((opts (parse-command-line args %options `((,%default-procedure))))
         (static? (assq-ref opts 'static?))
         (san? (not (assq-ref opts 'sans-sans?)))
         (proc (assq-ref opts 'procedure))
         (id (assq-ref opts 'argument))
         (bug (search-bug %packages id)))
    (unless id (leave (G_ "missing argument: no bug identifier given~%")))
    (unless bug (leave (G_ "'~a' is not a supported bug~%")
                       id))
    (with-store store
      (let* ((bux (package-output store (specification->package "bux")))
             (name (cond (static? (string-append (caar bug) "-static"))
                         (san? (string-join (cons (caar bug)
                                                  (cddar bug))
                                            "-with-"))
                         (else (caar bug))))
             (version (cadar bug))
             (spec (simple-format #f "~a@~a" name version))
             (out (package-output store (specification->package spec))))
        (build-things store (list bux out))
        (for-each (lambda (cmd)
                    (let ((prog (string-append out "/bin/" (car cmd)))
                          (rest (cadr cmd)))
                      (for-each (lambda (poc)
                                  (proc prog rest
                                        (string-append bux "/share/bux/" poc)))
                                (cddr cmd))))
                (cdr bug))))))
