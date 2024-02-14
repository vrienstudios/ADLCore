import nimscripter
import EPUB
import HLSManager
import std/[os, httpclient, htmlparser, xmltree, strutils, base64, json]
import ADLCore/utils

type
  InfoTuple* = tuple[name: string, cover: string, scraperType: string, version: string, projectUri: string, siteUri: string, scriptPath: string]
  Status* {.pure.} = enum
    Active = "Active", Hiatus = "Hiatus", Dropped = "Dropped", Completed = "Completed"
  LanguageType* = enum
    original, translated, machine, mix, unknown
  MetaData* = ref object of RootObj
    name*: string
    series*: string
    author*: string
    rating*: string
    genre*: seq[string]
    novelType*: string
    uri*: string
    description*: string
    languageType*: LanguageType
    statusType*: Status
    coverUri*: string
  SourceObj* = ref object of RootObj
    bkUp: bool
    uri: string
    resolution: string
  MethodList* = 
    tuple[baseUri, dType: string, procs: seq[tuple[procType: string, thisProc: proc(this: DownloaderContext){.nimcall.}]]]
  NScript* = ref object
    headerInfo*: InfoTuple
    scriptID: int
    intr: Option[Interpreter]
  MediaStreamTuple* = tuple[id: string, resolution: string, uri: string, language: string, isAudio: bool, bandWidth: string]
  StreamTuple* = tuple[stream: HLSStream, subStreams: seq[MediaStreamTuple]]
  Chapter* = ref object of RootObj
    metadata*: MetaData
    mainStream: StreamTuple
    contentSeq*: seq[TiNode]
  Volume* = tuple[names: string, lower, upper: int, parts: seq[Chapter]]
  DownloaderContext* = ref object of RootObj
    name: string
    script: NScript
    metadata: MetaData
    sections: seq[Volume]
    ourClient: HttpClient
    page: XmlNode
    defaultHeaders: HttpHeaders
    defaultPage: string
    currPage: string
    mainStreams: seq[StreamTuple]
    baseUri: string
    setMetadata, setSearch, setParts, setContent: proc(this: DownloaderContext)

proc setPage(this: DownloaderContext, page: string) =
  if this.currPage == page:
    return
  this.page = parseHtml(this.ourClient.getContent(page))
  this.currPage = page
iterator embtakuGetChapter(this: DownloaderContext, l, h: int): Chapter =
  setPage(this, this.defaultPage)
  var videoList: XmlNode =
    recursiveNodeSearch(this.page, parseHtml("<ul class=\"listing items lists\">"))
  var 
    idx: int = 
      if h > len(videoList) or h < 0: len(videoList)
      else: h
    lower: int =
      if l < 0: 0
      else: len(videoList) - l
  while idx > lower:
    dec idx
    let node = videoList[idx]
    if node.kind != xnElement: continue
    if node.tag != "li": continue
    var mdata: MetaData = MetaData()
    mdata.uri = this.baseUri & node.child("a").attr("href")
    mdata.coverUri = recursiveNodeSearch(node, parseHtml("<div class=\"img\">")).child("div").child("img").attr("href")
    mdata.name = sanitizeString(recursiveNodeSearch(node, parseHtml("<div class=\"name\">")).innerText)
    yield Chapter(metadata: mdata)
iterator novelhallGetChapter(this: DownloaderContext, l, h: int): Chapter =
  setPage(this, this.defaultPage)
  let chapterList: XmlNode =
    recursiveNodeSearch(this.page, parseHtml("<div class=\"book-catalog inner mt20\">"))
  var
    idx: int = 
      if h < 0: len(chapterList)
      else: h
    lower: int =
      if l < 0: 0
      else: l
    nodeTrack: int = 0
  while lower < idx and nodeTrack < len(chapterList):
    let currentNode = chapterList[nodeTrack]
    inc nodeTrack
    if currentNode.kind != xnElement or currentNode.tag != "ul":
      continue
    let ourChild = currentNode.child("a")
    yield Chapter(metadata: MetaData(name: sanitizeString(ourChild.innerText), uri: "https://www.novelhall.com" & ourChild.attr("href")))
    inc lower
proc loadEmbtakuChapters(this: DownloaderContext) =
  var vol: Volume = this.sections[^1]
  for chap in embtakuGetChapter(this, vol.lower, vol.upper):
    vol.parts.add chap
proc loadNovelHallChapters(this: DownloaderContext) =
  var vol: Volume = this.sections[^1]
  for chap in novelhallGetChapter(this, vol.lower, vol.upper):
    vol.parts.add chap
const downloaderList: seq[MethodList] =
  @[("embtaku.pro", "video", @[("metadata", nil), ("parts", loadEmbtakuChapters), ("search", nil), ("content", nil)]),
    ("hanime.tv", "video", @[("metadata", nil), ("parts", nil), ("search", nil), ("content", nil)]),
    ("novelhall.com", "text", @[("metadata", nil), ("parts", loadNovelHallChapters), ("search", nil), ("content", nil)]),
    ("mangakakalot.com", "text", @[("metadata", nil), ("parts", nil), ("search", nil), ("content", nil)]),
    ("", "script", @[("metadata", nil), ("parts", nil), ("search", nil), ("content", nil)])]

#tuple[baseUri, dType: string, procs: seq[tuple[procType: string, thisProc: proc(this: RootObj)]]]
proc setupDownloader(this: MethodList, downloader: var DownloaderContext) =
  for meth in this.procs:
    case meth.procType:
      of "metadata":
        downloader.setMetadata = meth.thisProc
      of "parts":
        downloader.setParts = meth.thisProc
      of "search":
        downloader.setSearch = meth.thisProc
      of "content":
        downloader.setContent = meth.thisProc
      else:
        continue
  return
proc generateInstance*(baseUri: string): DownloaderContext =
  for uri in downloaderList:
    if baseUri == uri.baseUri:
      var downloader = DownloaderContext()
      uri.setupDownloader(downloader)
      return downloader
  return nil


#let script = GenNewScript(ScanForScriptsInfoTuple("/mnt/General/work/Programming/ADLCore/src/")[0])
#let mdata = script[0].GetMetaData("https://www.volarenovels.com/novel/physician-not-a-consort")
#echo mdata.name
#echo mdata.author

# Testing code for scripts (do NOT build projects with this code included)
#var lam = ScanForScriptsInfoTuple("./")
#for l in lam:
#  var sc = GenNewScript("./" & l.name & ".nims")