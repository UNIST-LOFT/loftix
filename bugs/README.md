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

- CVE-2017-15025: [divide-by-zero][sourceware-22186]

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
[mozjpeg-268]: https://github.com/mozilla/mozjpeg/issues/268
[oss-sec-20161105-3]: https://www.openwall.com/lists/oss-security/2016/11/05/3
[redhat-955808]: https://bugzilla.redhat.com/show_bug.cgi?id=955808
[sourceware-21137]: https://sourceware.org/bugzilla/show_bug.cgi?id=21137
[sourceware-22148]: https://sourceware.org/bugzilla/show_bug.cgi?id=22148
[sourceware-22186]: https://sourceware.org/bugzilla/show_bug.cgi?id=22186
[sourceware-22202]: https://sourceware.org/bugzilla/show_bug.cgi?id=22202
[sourceware-24243]: https://sourceware.org/bugzilla/show_bug.cgi?id=24243
