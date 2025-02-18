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

[Guix channel]: https://guix.gnu.org/manual/devel/en/html_node/Channels.html
[AFLRun]: https://trong.loang.net/~cnx/afl++/log?h=run
[AFL++]: https://github.com/AFLplusplus/AFLplusplus
[afl-dyninst]: https://trong.loang.net/~cnx/afl-dyninst/about
[e9patch]: https://github.com/GJDuck/e9patch
[python-pacfix]: https://github.com/hsh814/pacfix-python
[taosc]: https://trong.loang.net/~cnx/taosc/about
