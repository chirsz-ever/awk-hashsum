# Awk Hashsum

This project aims to implement command line utilities for cryptographic hash algorithms using POSIX-compliant command-line tools, primarily using awk.

The original code and ideas are from [md5.awk](https://github.com/kaworu/md5.awk). Thank you, Alexandre Perrin.

## TODO

- [x] md5sum
  - [x] basic functionality
  - [x] support input from stdin
  - [x] support `--tag` option
  - [x] optimizition for streaming
- [x] b3sum
- [ ] support `-c` option
- [ ] shaXsum
