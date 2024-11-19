# Loftix

Loftix is a Guix channel containing packages
used and made by UNIST Lab of Software.

## Installation

Add the [Guix channel] to `~/.config/guix/channels.scm`:

    (cons* (channel
            (name 'loftix)
            (url "https://trong.loang.net/~cnx/loftix")
            (branch "main"))
           %default-channels)

Then run `guix pull`.

[Guix channel]: https://guix.gnu.org/manual/devel/en/html_node/Channels.html
