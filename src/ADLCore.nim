import ./ADLCore/Novel/NovelHall
import ./ADLCore/Video/VidStream, ./ADLCore/Video/Membed, ./ADLCore/Video/HAnime, ./ADLCore/Novel/MangaKakalot
import std/[os, asyncdispatch, strutils, dynlib, httpclient, tables, sharedtables]
import ./ADLCore/genericMediaTypes
import ADLCore/DownloadManager
import EPUB/EPUB3

export NovelHall, MangaKakalot
export Vidstream, Membed, HAnime
export genericMediaTypes
export DownloadManager

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
    of "Membed":
      let hTup = Membed.Init(uri)
      aniObj = Video()
      aniObj.Init(hTup)
    of "HAnime":
      let hTup = HAnime.Init(uri)
      aniObj = Video()
      aniObj.Init(hTup)
    else: discard
  assert aniObj != nil
  return aniObj

#let script = GenNewScript(ScanForScriptsInfoTuple("/mnt/General/work/Programming/ADLCore/src/")[0])
#let mdata = script[0].GetMetaData("https://www.volarenovels.com/novel/physician-not-a-consort")
#echo mdata.name
#echo mdata.author

# Testing code for scripts (do NOT build projects with this code included)
#var lam = ScanForScriptsInfoTuple("./")
#for l in lam:
#  var sc = GenNewScript("./" & l.name & ".nims")
