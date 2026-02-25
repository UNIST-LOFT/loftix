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

- [afl-dyninst]: [Dyninst] integration for [AFL++]
- [fuzzolic]: Concolic fuzzer

### Model Checking

- [civl]: Concurrency Intermediate Verification Language

### Patching

- [e9patch]: static binary rewriting tool

### Synthesis

- [python-pacfix]: PAC-learning-based program synthesizer
- [syminfer]: Numerical invariant generation tool
- [taosc]: Makeshift binary patch generator

### Theorem Proving

- [fuzzy-sat]: Approximate solver for concolic execution

[Guix channel]: https://guix.gnu.org/manual/devel/en/html_node/Channels.html
[afl-dyninst]: https://trong.loang.net/~cnx/afl-dyninst/about
[Dyninst]: https://github.com/dyninst/dyninst
[AFL++]: https://aflplus.plus
[fuzzolic]: https://season-lab.github.io/fuzzolic
[civl]: https://vsl.cis.udel.edu/civl
[e9patch]: https://github.com/GJDuck/e9patch
[python-pacfix]: https://github.com/hsh814/pacfix-python
[syminfer]: https://github.com/dynaroars/dig
[taosc]: https://trong.loang.net/~cnx/taosc/about
[fuzzy-sat]: https://github.com/season-lab/fuzzy-sat
