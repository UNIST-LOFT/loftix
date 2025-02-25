# Bug reproducers

## binutils

- CVE-2017-6965: [heap buffer overflow][sourceware-21137]

      guix shell -e '(@@ (loftix bugs) binutils-2.27-asan)'
      readelf -w cve/2017/6965/bug_3

- CVE-2017-14745: [integer overflow][sourceware-22148]

      guix shell -e '(@@ (loftix bugs) binutils-2.29)'
      objdump -d cve/2017/14745/crash_1

- CVE-2017-15020: [heap buffer overflow][sourceware-22202]

      guix shell -e '(@@ (loftix bugs) binutils-2.29-asan)'
      nm -l cve/2017/15020/reproducer

- CVE-2017-15025: [division by zero][sourceware-22186]

      guix shell -e '(@@ (loftix bugs) binutils-2.29)'
      nm -l cve/2017/15025/3899.crashes.bin
      nm -l cve/2017/15025/floatexception.elf
      objdump -S cve/2017/15025/floatexception.elf

- CVE-2019-9077: [heap buffer overflow][sourceware-24243]

      guix shell -e '(@@ (loftix bugs) binutils-2.32-asan)'
      readelf -a cve/2019/9077/hbo2

## JasPer

- CVE-2016-8691: [divide-by-zero][jasper-22]

      guix shell -e '(@@ (loftix bugs) jasper-1.900.3)'
      imginfo -f cve/2016/8691/11.crash

- CVE-2016-9557: [signed integer overflow][jasper-67]

      guix shell -e '(@@ (loftix bugs) jasper-1.900.19)'
      imginfo -f cve/2016/9557/signed-int-overflow.jp2

## libarchive

- CVE-2016-5844: [signed integer overflow][libarchive-717]

      guix shell -e '(@@ (loftix bugs) libarchive-3.2.0-ubsan)'
      bsdtar -tf cve/2016/5844/libarchive-signed-int-overflow.iso

## libjpeg-turbo

- CVE-2012-2806: [heap buffer overflow][chromium-40058947]

      guix shell -e '(@@ (loftix bugs) libjpeg-turbo-1.2.0-asan)'
      djpeg cve/2012/2806/cnode0006-heap-buffer-overflow-796.jpg

- CVE-2017-15232: [null pointer dereference][mozjpeg-268]

      guix shell -e '(@@ (loftix bugs) libjpeg-turbo-1.5.2)'
      djpeg -crop "1x1+16+16" -onepass -dither ordered -dct float -colors 8\
        -targa -grayscale -outfile /dev/null cve/2017/15232/1.jpg
      djpeg -crop "1x1+16+16" -onepass -dither ordered -dct float -colors 8\
        -targa -grayscale -outfile /dev/null cve/2017/15232/2.jpg

- CVE-2018-14498: [heap buffer overflow][libjpeg-turbo-258]

      guix shell -e '(@@ (loftix bugs) libjpeg-turbo-1.5.3-asan)'
      cjpeg -outfile /dev/null cve/2018/14498/hbo_rdbmp.c:209_1.bmp
      cjpeg -outfile /dev/null cve/2018/14498/hbo_rdbmp.c:209_2.bmp
      cjpeg -outfile /dev/null cve/2018/14498/hbo_rdbmp.c:210_1.bmp
      cjpeg -outfile /dev/null cve/2018/14498/hbo_rdbmp.c:211_1.bmp
      cjpeg -outfile /dev/null cve/2018/14498/hbo_rdbmp.c:211_2.bmp

- CVE-2018-19664: [heap buffer overflow][libjpeg-turbo-305]

      guix shell -e '(@@ (loftix bugs) libjpeg-turbo-2.0.1-asan)'
      djpeg -colors 256 -bmp cve/2018/19664/heap-buffer-overflow-2.jpg

## libtiff

- CVE-2016-3186: [buffer overflow][redhat-1319503]

      guix shell -e '(@@ (loftix bugs) libtiff-4.0.6)'
      echo y | gif2tiff cve/2016/3186/crash.gif /dev/null

- CVE-2016-5314: [heap buffer overflow][maptools-2554]

      guix shell -e '(@@ (loftix bugs) libtiff-4.0.6-asan)'
      rgb2ycbcr cve/2016/5314/oobw.tiff /dev/null

- CVE-2016-5321: [invalid read][maptools-2558]

      guix shell -e '(@@ (loftix bugs) libtiff-4.0.6)'
      tiffcrop cve/2016/5321/ill-read.tiff /dev/null

- CVE-2016-9273: [heap buffer overflow][maptools-2587]

      guix shell -e '(@@ (loftix bugs) libtiff-4.0.6-asan)'
      tiffsplit cve/2016/9273/test049.tiff

- CVE-2016-9532: [heap buffer overflow][maptools-2592]

      guix shell -e '(@@ (loftix bugs) libtiff-4.0.6)'
      tiffcrop cve/2016/9532/heap-buffer-overflow.tiff /dev/null

- CVE-2016-10092: [heap buffer overflow][maptools-2622]

      guix shell -e '(@@ (loftix bugs) libtiff-4.0.7-asan)'
      tiffcrop -i cve/2016/10092/heapoverflow.tiff /dev/null

- CVE-2016-10093: [heap buffer overflow][maptools-2610]

      guix shell -e '(@@ (loftix bugs) libtiff-4.0.7-asan)'
      tiffcp -i cve/2016/10093/heapoverflow.tiff /dev/null

- CVE-2016-10094: [heap buffer overflow][maptools-2640]

      guix shell -e '(@@ (loftix bugs) libtiff-4.0.7-asan)'
      tiff2pdf cve/2016/10094/heapoverflow.tiff -o /dev/null

- CVE-2016-10266: [division by zero][maptools-2596]

      guix shell -e '(@@ (loftix bugs) libtiff-4.0.7)'
      tiffcp cve/2016/10266/fpe.tiff /dev/null

- CVE-2016-10267: [division by zero][maptools-2611]

      guix shell -e '(@@ (loftix bugs) libtiff-4.0.7)'
      tiffmedian cve/2016/10267/fpe.tiff /dev/null

- CVE-2016-10268: [heap buffer overflow][maptools-2598]

      guix shell -e '(@@ (loftix bugs) libtiff-4.0.7-asan)'
      tiffcp -i cve/2016/10268/heapoverflow.tiff /dev/null

- CVE-2016-10271: [heap buffer overflow][maptools-2620]

      guix shell -e '(@@ (loftix bugs) libtiff-4.0.7-asan)'
      tiffcrop -i cve/2016/10271/heapoverflow.tiff /dev/null

- CVE-2016-10272: [heap buffer overflow][maptools-2624]

      guix shell -e '(@@ (loftix bugs) libtiff-4.0.7-asan)'
      tiffcrop -i cve/2016/10272/heapoverflow.tiff /dev/null

- CVE-2017-5225: [heap buffer overflow][maptools-2656]

      guix shell -e '(@@ (loftix bugs) libtiff-4.0.7-asan)'
      tiffcp -p separate cve/2017/5225/2656.tiff /dev/null
      tiffcp -p contig cve/2017/5225/2657.tiff /dev/null

- CVE-2017-7595: [division by zero][maptools-2653]

      guix shell -e '(@@ (loftix bugs) libtiff-4.0.7)'
      tiffcp -i cve/2017/7595/fpe.tiff /dev/null

- cve-2017-7599: [float cast overflow][maptools-2646]

      guix shell -e '(@@ (loftix bugs) libtiff-4.0.7-ubsan-float-cast-overflow)'
      tiffcp -i cve/2017/7599/outside-short.tiff /dev/null

- cve-2017-7600: [float cast overflow][maptools-2647]

      guix shell -e '(@@ (loftix bugs) libtiff-4.0.7-ubsan-float-cast-overflow)'
      tiffcp -i cve/2017/7600/outside-unsigned-char.tiff /dev/null

- CVE-2017-7601: [signed integer overflow][maptools-2648]

      guix shell -e '(@@ (loftix bugs) libtiff-4.0.7-ubsan)'
      tiffcp -i cve/2017/7601/shift-long.tiff /dev/null

## libxml2

- CVE-2012-5134: [heap buffer overflow][chromium-40076524]

      guix shell -e '(@@ (loftix bugs) libxml2-2.9.0-asan)'
      xmllint cve/2012/5134/bad.xml

- CVE-2016-1838: [heap buffer overflow][chromium-42452154]

      guix shell -e '(@@ (loftix bugs) libxml2-2.9.3-asan)'
      xmllint cve/2016/1838/attachment_316158

- CVE-2016-1839: [heap buffer overflow][chromium-42452152]

      guix shell -e '(@@ (loftix bugs) libxml2-2.9.3-asan)'
      xmllint --html cve/2016/1839/asan_heap-oob

- CVE-2017-5969: [null pointer derefence][oss-sec-20161105-3]

      guix shell -e '(@@ (loftix bugs) libxml2-2.9.4
      xmllint --recover cve/2017/5969/crash-libxml2-recover.xml

## potrace

- CVE-2013-7437: [possible heap overflow][redhat-955808]

      guix shell -e '(@@ (loftix bugs) potrace-1.11)'
      potrace cve/2013/7437/1.bmp
      potrace cve/2013/7437/2.bmp

[chromium-40058947]: https://issues.chromium.org/issues/40058947
[chromium-40076524]: https://issues.chromium.org/issues/40076524
[chromium-42452152]: https://project-zero.issues.chromium.org/issues/42452152
[chromium-42452154]: https://project-zero.issues.chromium.org/issues/42452154
[jasper-22]: https://github.com/jasper-software/jasper/issues/22
[jasper-67]: https://github.com/jasper-software/jasper/issues/67
[libarchive-717]: https://github.com/libarchive/libarchive/issues/717
[libjpeg-turbo-258]: https://github.com/libjpeg-turbo/libjpeg-turbo/issues/258
[libjpeg-turbo-305]: https://github.com/libjpeg-turbo/libjpeg-turbo/issues/305
[maptools-2554]: https://bugzilla.maptools.org/show_bug.cgi?id=2554
[maptools-2558]: https://bugzilla.maptools.org/show_bug.cgi?id=2558
[maptools-2587]: https://bugzilla.maptools.org/show_bug.cgi?id=2587
[maptools-2592]: https://bugzilla.maptools.org/show_bug.cgi?id=2592
[maptools-2596]: https://bugzilla.maptools.org/show_bug.cgi?id=2596
[maptools-2598]: https://bugzilla.maptools.org/show_bug.cgi?id=2598
[maptools-2610]: https://bugzilla.maptools.org/show_bug.cgi?id=2610
[maptools-2611]: https://bugzilla.maptools.org/show_bug.cgi?id=2611
[maptools-2620]: https://bugzilla.maptools.org/show_bug.cgi?id=2620
[maptools-2622]: https://bugzilla.maptools.org/show_bug.cgi?id=2622
[maptools-2624]: https://bugzilla.maptools.org/show_bug.cgi?id=2624
[maptools-2640]: https://bugzilla.maptools.org/show_bug.cgi?id=2640
[maptools-2646]: https://bugzilla.maptools.org/show_bug.cgi?id=2646
[maptools-2647]: https://bugzilla.maptools.org/show_bug.cgi?id=2647
[maptools-2648]: https://bugzilla.maptools.org/show_bug.cgi?id=2648
[maptools-2653]: https://bugzilla.maptools.org/show_bug.cgi?id=2653
[maptools-2656]: https://bugzilla.maptools.org/show_bug.cgi?id=2656
[mozjpeg-268]: https://github.com/mozilla/mozjpeg/issues/268
[oss-sec-20161105-3]: https://www.openwall.com/lists/oss-security/2016/11/05/3
[redhat-955808]: https://bugzilla.redhat.com/show_bug.cgi?id=955808
[redhat-1319503]: https://bugzilla.redhat.com/show_bug.cgi?id=1319503
[sourceware-21137]: https://sourceware.org/bugzilla/show_bug.cgi?id=21137
[sourceware-22148]: https://sourceware.org/bugzilla/show_bug.cgi?id=22148
[sourceware-22186]: https://sourceware.org/bugzilla/show_bug.cgi?id=22186
[sourceware-22202]: https://sourceware.org/bugzilla/show_bug.cgi?id=22202
[sourceware-24243]: https://sourceware.org/bugzilla/show_bug.cgi?id=24243
