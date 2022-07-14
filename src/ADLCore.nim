import ./ADLCore/Novel/NovelTypes
import ./ADLCore/Novel/NovelHall
import ./ADLCore/Novel/test
import./ADLCore/Video/VidStream
import std/[asyncdispatch, strutils]
import ./ADLCore/genericMediaTypes
import EPUB

proc onProgressChanged(total, progress, speed: BiggestInt) {.async,cdecl.} =
    echo("Downloaded ", progress, " of ", total)
    echo("Rate: ", speed, "b/s")

#echo "Making Object"
#var NHall = NovelHall()
#waitFor NHall.Init("https://www.novelhall.com/the-rise-of-the-empire-21939/")
#echo "Getting MetaData"
#waitFor NHall.SetMetaData()
#echo "Author: " & NHall.metaData.author
#echo "Description: " & NHall.metaData.description
#echo "Getting Chapter Sequence"
#waitFor NHall.GetChapterSequence(onProgressChanged)
#let b = NHall.chapters
#let d = waitFor NHall.GetChapterNodes(NHall.chapters[0])
#assert len(d) > 10
#echo "Found $1 Chapters From NovelHall" % [$len(b)]

#echo "Making Object"

proc GenerateNewNovelInstance*(site: string, uri: string): Novel =
  var novelObj: Novel
  case site:
    of "NovelHall":
      let hTuple = NovelHall.Init(uri)
      novelObj = Novel()
      novelObj.Init(hTuple)
    else:
      discard
  assert novelObj != nil
  return novelObj

#discard GenerateNewNovelInstance("NovelHall", "https://www.novelhall.com/the-rise-of-the-empire-21939/")
#var b = novelObj.getHomeCarousel(novelObj)
#discard GenerateNewNovelInstance("NovelHall", "")
#let b = novelObj.searchDownloader(novelObj, "Martial")
#for n in b:
#  echo n.name

#proc GeneratePageFromChapter*(this: Chapter): Page =
#  return GeneratePage(this.contentSeq, this.name)

#discard GenerateNewNovelInstance("NovelHall", "https://www.novelhall.com/the-rise-of-the-empire-21939/")
#novelObj.Init()
#var mdata: MetaData = novelObj.getMetaData(novelObj)
#echo "name: " & mdata.name
#echo "author: " & mdata.author

#proc GetNextChapterWithText(novel: Novel): Chapter =
#  if(novel.currChapter >= novel.chapters.len()):
#    return nil
#  var chp: Chapter = novel.chapters[novel.currChapter]
#  chp.contentSeq = waitFor GetChapterNodes(NovelHall(novel), chp)
#  inc novel.currChapter
#  return chp


#var vidyaStream = VidStream()
#waitFor vidyaStream.Init("https://gogoplay1.com/videos/koi-wa-sekai-seifuku-no-ato-de-episode-1")
#waitFor vidyaStream.SetHLSStream()
#
#for param in vidyaStream.stream.parts:
#    echo "header: $1" % [param.header]
#    for val in param.values:
#        echo "  Key: $1\n   Value: $2" % [val.key, val.value]
