# Package

version       = "0.2.1"
author        = "ShujianDou"
description   = "Novel, Video, and Anime scraper"
license       = "GPLv3"
srcDir        = "src"

# Tasks
task test, "Test ADLCore Functionality":
  exec "rm -rf ~/.nimble/pkgs2/ADLCore-0.2.*"
  exec "rm -rf ~/.cache/nim/tester_d/*"
  exec "nimble install -Y" # Install latest version
  withDir "tests":
    exec "nim c -d:ssl --threads:on -r tester"

# Dependencies

requires "nim >= 1.6.6"
requires "halonium == 0.2.6"
requires "EPUB == 0.3.0"
requires "HLSManager"
requires "nimcrypto"
requires "nimscripter == 1.1.1"
requires "https://github.com/vrienstudios/zippy"
