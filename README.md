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

- [python-pacfix]: PAC-learning-based program systhesizer

## Bugs

### CVE-2016-9557

[Signed integer overflow in jas_image.c][jasper-d42b238]

    guix shell jasper@1.900.19 -- imginfo -f bugs/cve-2016-9557/reproducer

### CVE-2017-14745

[Integer overflow in elf64-x86-64.c, binutils 2.29.1][sourceware-22148]

    guix shell binutils@2.29 -- objdump -d bugs/cve-2017-14745/crash_1

### CVE-2017-15025

[Divide-by-zero in decode_line_info (dwarf2.c)][sourceware-22186]

    guix shell binutils@2.29 -- nm -l bugs/cve-2017-15025/3899.crashes.bin

### CVE-2017-15232

[NULL pointer dereference in quantize_ord_dither function][mozjpeg-268]

    guix shell libjpeg-turbo@1.5.2 --\
      djpeg -crop "1x1+16+16" -onepass -dither ordered -dct float -colors 8\
        -targa -grayscale -outfile o bugs/cve-2017-15232/1.jpg
    guix shell libjpeg-turbo@1.5.2 --\
      djpeg -crop "1x1+16+16" -onepass -dither ordered -dct float -colors 8\
        -targa -grayscale -outfile o bugs/cve-2017-15232/2.jpg

[Guix channel]: https://guix.gnu.org/manual/devel/en/html_node/Channels.html
[AFLRun]: https://trong.loang.net/~cnx/afl++/log?h=run
[AFL++]: https://github.com/AFLplusplus/AFLplusplus
[afl-dyninst]: https://trong.loang.net/~cnx/afl-dyninst/about
[e9patch]: https://github.com/GJDuck/e9patch
[python-pacfix]: https://github.com/hsh814/pacfix-python
[jasper-d42b238]: https://blogs.gentoo.org/ago/2016/11/19/jasper-signed-integer-overflow-in-jas_image-c
[sourceware-22148]: https://sourceware.org/bugzilla/show_bug.cgi?id=22148
[sourceware-22186]: https://sourceware.org/bugzilla/show_bug.cgi?id=22186
[mozjpeg-268]: https://github.com/mozilla/mozjpeg/issues/268
