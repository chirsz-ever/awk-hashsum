# Awk Hashsum

This project aims to implement command line utilities for cryptographic hash algorithms using POSIX-compliant command-line tools, primarily using awk.

The original code and ideas are from [md5.awk](https://github.com/kaworu/md5.awk). Thank you, Alexandre Perrin.

## TODO

- [ ] md5sum
  - [x] basic functionality
  - [x] support input from stdin
  - [ ] optimizition for streaming
  - [ ] support `-c` option
  - [ ] support `--tag` option
- [ ] b3sum
- [ ] shaXsum
