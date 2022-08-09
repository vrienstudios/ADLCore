import ./ADLCore/Novel/NovelTypes
import ./ADLCore/Novel/NovelHall
import ./ADLCore/Video/VidStream, ./ADLCore/Video/VideoType, ./ADLCore/Video/HAnime
import std/[asyncdispatch, strutils, dynlib]
import ./ADLCore/genericMediaTypes
import EPUB

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
# Modules Implementation Test
#type
#  initiatior = proc (str: string): HeaderTuple {.nimcall.}
#
#let lib = loadLib("./libNovelHall.so")
#assert lib != nil
#var ini = cast[initiatior](lib.symAddr("Init"))
#assert ini != nil
#var hT: HeaderTuple = ini("www.novelhall.com")
#var str: string = $hT[1]
#echo str.len
#echo str
