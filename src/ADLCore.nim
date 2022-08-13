import ./ADLCore/Novel/NovelTypes
import ./ADLCore/Novel/NovelHall
import ./ADLCore/Video/VidStream, ./ADLCore/Video/VideoType, ./ADLCore/Video/HAnime, ./ADLCore/Novel/MangaKakalot
import std/[os, asyncdispatch, strutils, dynlib, httpclient, tables, sharedtables]
import ./ADLCore/genericMediaTypes
import EPUB
import EPUB/Types/genericTypes
import nimscripter
import ./ADLCore/Interp

proc onProgressChanged(total, progress, speed: BiggestInt) {.async,cdecl.} =
    echo("Downloaded ", progress, " of ", total)
    echo("Rate: ", speed, "b/s")

proc GenerateNewNovelInstance*(site: string, uri: string): Novel {.exportc,dynlib.} =
  var novelObj: Novel
  case site:
    of "NovelHall":
      let hTuple = NovelHall.Init(uri)
      novelObj = Novel()
      novelObj.Init(hTuple)
    of "MangaKakalot":
      let hTuple = MangaKakalot.Init(uri)
      novelObj = Novel()
      novelObj.Init(hTuple)
    else:
      discard
  assert novelObj != nil
  return novelObj
proc GenerateNewVideoInstance*(site: string, uri: string): Video =
  var aniObj: Video
  case site:
    of "vidstreamAni":
      let hTup = VidStream.Init(uri)
      aniObj = Video()
      aniObj.Init(hTup)
    of "HAnime":
      let hTup = HAnime.Init(uri)
      aniObj = Video()
      aniObj.Init(hTup)
    else: discard
  assert aniObj != nil
  return aniObj
proc ScanForScriptsAndLoad*(filePath: string): seq[NScript] =
  var scripts: seq[NScript] = @[]
  for n in walkFiles(filePath & "*.nims"):
    scripts.add(GenNewScript(n))
  return scripts

#let scripts = ScanForScriptsAndLoad("/mnt/General/work/Programming/ADLCore/src/")
#let mdata = scripts[0].GetMetaData("https://www.volarenovels.com/novel/physician-not-a-consort")