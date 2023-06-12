# Package

version       = "0.2.0"
author        = "ShujianDou"
description   = "Novel, Video, and Anime scraper"
license       = "GPLv3"
srcDir        = "src"

# Tasks
task test, "Test ADLCore Functionality":
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
requires "zippy == 0.10.3"
