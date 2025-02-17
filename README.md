# Loftix

Loftix is a Guix channel containing packages
used and made by UNIST Lab of Software.

## Installation

Add the [Guix channel] to `~/.config/guix/channels.scm`:

    (cons* (channel
            (name 'loftix)
            (url "https://trong.loang.net/~cnx/loftix")
            (branch "main")
            (introduction
             (make-channel-introduction
              "1b5437ce217590545f7a7319a5c62b6300aee6c4"
              (openpgp-fingerprint
               "838A FE0D 55DC 074E 360F  943A 84B6 9CE6 F3F6 B767"))))
           %default-channels)

Then run `guix pull`.

## Packages

### Fuzzing

- [AFLRun]: multi-target directed [AFL++] with path diversity
- [afl-dyninst]: Dyninst integration for AFL++

### Patching

- [e9patch]: static binary rewriting tool

### Synthesis

- [python-pacfix]: PAC-learning-based program synthesizer
- [taosc]: Makeshift binary patch generator

## Bugs

### CVE-2013-7437

[potrace: possible heap overflow][redhat-955808]

    guix shell potrace@1.11
    potrace bugs/cve/2013/7437/1.bmp
    potrace bugs/cve/2013/7437/2.bmp

### CVE-2016-9557

[JasPer: signed integer overflow][jasper-d42b238]

    guix shell jasper@1.900.19
    imginfo -f bugs/cve/2016/9557/signed-int-overflow.jp2

### CVE-2017-5969

[libxml2: null pointer derefence][oss-sec-20161105-3]

    guix shell libxml2@2.9.4
    xmllint --recover bugs/cve/2017/5969/crash-libxml2-recover.xml

### CVE-2017-6965

[binutils: heap buffer overflow][sourceware-21137]

    guix shell binutils@2.27
    readelf -w bugs/cve/2017/6965/bug_3

### CVE-2017-14745

[binutils: integer overflow][sourceware-22148]

    guix shell binutils@2.29
    objdump -d bugs/cve/2017/14745/crash_1

### CVE-2017-15020

[binutils: heap buffer overflow][sourceware-22202]

    guix shell binutils@2.29
    nm -l bugs/cve/2017/15020/reproducer

### CVE-2017-15025

[binutils: divide-by-zero][sourceware-22186]

    guix shell binutils@2.29
    nm -l bugs/cve/2017/15025/3899.crashes.bin
    nm -l bugs/cve/2017/15025/floatexception.elf
    objdump -S bugs/cve/2017/15025/floatexception.elf

### CVE-2017-15232

[libjpeg-turbo: NULL pointer dereference][mozjpeg-268]

    guix shell libjpeg-turbo@1.5.2
    djpeg -crop "1x1+16+16" -onepass -dither ordered -dct float -colors 8\
      -targa -grayscale -outfile o bugs/cve/2017/15232/1.jpg
    djpeg -crop "1x1+16+16" -onepass -dither ordered -dct float -colors 8\
      -targa -grayscale -outfile o bugs/cve/2017/15232/2.jpg

[Guix channel]: https://guix.gnu.org/manual/devel/en/html_node/Channels.html
[AFLRun]: https://trong.loang.net/~cnx/afl++/log?h=run
[AFL++]: https://github.com/AFLplusplus/AFLplusplus
[afl-dyninst]: https://trong.loang.net/~cnx/afl-dyninst/about
[e9patch]: https://github.com/GJDuck/e9patch
[python-pacfix]: https://github.com/hsh814/pacfix-python
[taosc]: https://trong.loang.net/~cnx/taosc/about
[redhat-955808]: https://bugzilla.redhat.com/show_bug.cgi?id=955808
[jasper-d42b238]: https://blogs.gentoo.org/ago/2016/11/19/jasper-signed-integer-overflow-in-jas_image-c
[oss-sec-20161105-3]: https://www.openwall.com/lists/oss-security/2016/11/05/3
[sourceware-21137]: https://sourceware.org/bugzilla/show_bug.cgi?id=21137
[sourceware-22148]: https://sourceware.org/bugzilla/show_bug.cgi?id=22148
[sourceware-22202]: https://sourceware.org/bugzilla/show_bug.cgi?id=22202
[sourceware-22186]: https://sourceware.org/bugzilla/show_bug.cgi?id=22186
[mozjpeg-268]: https://github.com/mozilla/mozjpeg/issues/268
