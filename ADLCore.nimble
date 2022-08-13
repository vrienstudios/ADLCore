# Package

version       = "0.1.5"
author        = "ShujianDou"
description   = "Novel, Video, and Anime scraper"
license       = "Proprietary"
srcDir        = "src"

# Tasks
task test, "Test ADLCore Functionality":
  withDir "tests":
    exec "nim c -d:ssl -r tester"

# Dependencies

requires "nim >= 1.6.6"
requires "EPUB"
requires "HLSManager"
requires "nimcrypto"
requires "nimscripter"
