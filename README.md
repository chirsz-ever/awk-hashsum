# Awk Hashsum

This project aims to implement command line utilities for cryptographic hash algorithms using POSIX-compliant command-line tools, primarily using awk.

The original code and ideas are from [md5.awk](https://github.com/kaworu/md5.awk). Thank you, Alexandre Perrin.

## TODO

The primary motivation for this project is to bootstrap the [kiss](https://codeberg.org/kiss-community/kiss) package
manager on MacOS. kiss requires [b3sum](https://github.com/BLAKE3-team/BLAKE3), while I prefer to keep the base system
purely scripts. Therefore, I'm not planning to complete the remaining TODO items now. If you have requests for these or
other features, please file an issue or pull request.

- [x] md5sum
  - [x] basic functionality
  - [x] support input from stdin
  - [x] support `--tag` option
  - [x] optimizition for streaming
- [x] b3sum
- [ ] support `-c` option
- [ ] shaXsum
