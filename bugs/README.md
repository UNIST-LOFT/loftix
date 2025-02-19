# Bug reproducers

## binutils

- CVE-2017-6965: [heap buffer overflow][sourceware-21137]

      guix shell binutils@2.27
      readelf -w cve/2017/6965/bug_3

- CVE-2017-14745: [integer overflow][sourceware-22148]

      guix shell binutils@2.29
      objdump -d cve/2017/14745/crash_1

- CVE-2017-15020: [heap buffer overflow][sourceware-22202]

      guix shell binutils@2.29
      nm -l cve/2017/15020/reproducer

- CVE-2017-15025: [divide-by-zero][sourceware-22186]

      guix shell binutils@2.29
      nm -l cve/2017/15025/3899.crashes.bin
      nm -l cve/2017/15025/floatexception.elf
      objdump -S cve/2017/15025/floatexception.elf

- CVE-2019-9077: [heap buffer overflow][sourceware-24243]

      guix shell binutils@2.32
      readelf -a cve/2019/9077/hbo2

## JasPer

- CVE-2016-8691: [divide-by-zero][jasper-22]

      guix shell jasper@1.900.3
      imginfo -f cve/2016/8691/11.crash

- CVE-2016-9557: [signed integer overflow][jasper-67]

      guix shell jasper@1.900.19
      imginfo -f cve/2016/9557/signed-int-overflow.jp2

## libjpeg-turbo

- CVE-2017-15232: [null pointer dereference][mozjpeg-268]

      guix shell libjpeg-turbo@1.5.2
      djpeg -crop "1x1+16+16" -onepass -dither ordered -dct float -colors 8\
        -targa -grayscale -outfile o cve/2017/15232/1.jpg
      djpeg -crop "1x1+16+16" -onepass -dither ordered -dct float -colors 8\
        -targa -grayscale -outfile o cve/2017/15232/2.jpg

## libxml2

- CVE-2017-5969: [null pointer derefence][oss-sec-20161105-3]

      guix shell libxml2@2.9.4
      xmllint --recover cve/2017/5969/crash-libxml2-recover.xml

## potrace

- CVE-2013-7437: [possible heap overflow][redhat-955808]

      guix shell potrace@1.11
      potrace cve/2013/7437/1.bmp
      potrace cve/2013/7437/2.bmp

[jasper-22]: https://github.com/jasper-software/jasper/issues/22
[jasper-67]: https://github.com/jasper-software/jasper/issues/67
[mozjpeg-268]: https://github.com/mozilla/mozjpeg/issues/268
[oss-sec-20161105-3]: https://www.openwall.com/lists/oss-security/2016/11/05/3
[redhat-955808]: https://bugzilla.redhat.com/show_bug.cgi?id=955808
[sourceware-21137]: https://sourceware.org/bugzilla/show_bug.cgi?id=21137
[sourceware-22148]: https://sourceware.org/bugzilla/show_bug.cgi?id=22148
[sourceware-22186]: https://sourceware.org/bugzilla/show_bug.cgi?id=22186
[sourceware-22202]: https://sourceware.org/bugzilla/show_bug.cgi?id=22202
[sourceware-24243]: https://sourceware.org/bugzilla/show_bug.cgi?id=24243
