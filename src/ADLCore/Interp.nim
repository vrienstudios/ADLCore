import nimscripter
import genericMediaTypes
import std/[httpclient, htmlparser, xmltree, strutils, strtabs, parseutils, sequtils]
import EPUB
import HLSManager
import options, os, halonium
import zippy
import DownloadManager

type
  InfoTuple* = tuple[name: string, cover: string, scraperType: string, version: string, projectUri: string, siteUri: string, scriptPath: string]
  NScript* = ref object
    headerInfo*: InfoTuple
    scriptID: int
    intr: Option[Interpreter]
  SNovel* = ref object of Novel
    script*: NScript
  SVideo* = ref object of Video
    script*: NScript

#converter psuedoToTiNode(x: PsuedoNode): TiNode =
#  result = TiNode(kind: x.kind, attrs: XmlAttributes(x.attrs, text: x.text, image: x.image)
converter toSNovel*(x: Novel): SNovel =
  SNovel(isOwnedByScript: x.isOwnedByScript,
    metaData: x.metaData, lastModified: x.lastModified,
    volumes: x.volumes, chapters: x.chapters, currChapter: x.currChapter,
    ourClient: x.ourClient, page: x.page, defaultHeaders: x.defaultHeaders,
    defaultPage: x.defaultPage, currPage: x.currPage,
    getNodes: x.getNodes, getMetaData: x.getMetaData,
    getChapterSequence: x.getChapterSequence, getHomeCarousel: x.getHomeCarousel,
    searchDownloader: x.searchDownloader, getCover: x.getCover)
converter toSVideo*(x: Video): SVideo =
  SVideo(ourClient: x.ourClient, metaData: x.metaData, page: x.page, defaultPage: x.defaultPage,
    defaultHeaders: x.defaultHeaders, currPage: x.currPage, hlsStream: x.hlsStream,
    videoCurrIdx: x.videoCurrIdx, videoStream: x.videoStream, audioCurrIdx: x.audioCurrIdx,
    audioStream: x.audioStream, mediaStreams: x.mediaStreams, getStream: x.getStream,
    getMetaData: x.getMetaData, getEpisodeSequence: x.getEpisodeSequence, getHomeCarousel: x.getHomeCarousel,
    searchDownloader: x.searchDownloader, getCover: x.getCover, getNext: x.getNext,
    selResolution: x.selResolution, listResolution: x.listResolution, downloadNextVideoPart: x.downloadNextVideoPart,
    downloadNextAudioPart: x.downloadNextAudioPart)
proc `defaultPage=`*(x: var SNovel, page: string) =
  x.defaultPage = page
  if x.script != nil:
    x.script.intr.invoke(SetDefaultPage, page)

var NScripts: seq[NScript] = @[]
var NScriptClient: HttpClient

method getDefHttpClient*(this: SNovel): HttpClient =
  if this.script == nil:
    return this.ourClient
  return NScriptClient
proc DownloadNextAudioPart*(this: SVideo, path: string): bool =
  if this.script == nil:
    return this.downloadNextAudioPart(this, path)
  return this.script.intr.invoke(DownloadNextAudioPart, path, returnType = bool)
proc DownloadNextVideoPart*(this: SVideo, path: string): bool =
  if this.script == nil:
    return this.downloadNextVideoPart(this, path)
  return this.script.intr.invoke(DownloadNextVideoPart, path, returnType = bool)
proc GetChapterSequence*(this: SNovel): seq[Chapter] =
  var chapters: seq[Chapter] = @[]
  if this.script == nil:
    chapters = this.getChapterSequence(this)
  else:
    chapters = this.script.intr.invoke(GetChapterSequence, returnType = seq[Chapter])
  this.chapters = chapters
  return chapters
proc GetEpisodeSequence*(this: SVideo): seq[MetaData] =
  if this.script == nil:
    return this.getEpisodeSequence(this)
  return this.script.intr.invoke(GetEpisodeSequence, returnType = seq[MetaData])
proc GetNovelHomeCarousel*(this: SNovel): seq[MetaData] =
  if this.script == nil:
    return this.getHomeCarousel(this)
  return this.script.intr.invoke(GetNovelHomeCarousel, returnType = seq[MetaData])
proc GetVideoHomeCarousel*(this: SVideo): seq[MetaData] =
  return this.getHomeCarousel(this)
proc GetMetaData*(this: SNovel): MetaData =
  if this.script == nil:
    this.metaData = this.getMetaData(this)
  else:  this.metaData = this.script.intr.invoke(GetMetaData, returnType = MetaData)
  return this.metaData
proc GetMetaData*(this: SVideo): MetaData =
  if this.script == nil:
    this.metaData = this.getMetaData(this)
  else:  this.metaData = this.script.intr.invoke(GetMetaData, returnType = MetaData)
  return this.metaData
proc GetNodes*(this: SNovel, chapter: Chapter): seq[TiNode] =
  if this.script == nil:
    return this.getNodes(this, chapter)
  return this.script.intr.invoke(GetNodes, chapter, returnType = seq[TiNode])

## TODO/VERIFY
proc GetStream*(this: SVideo): HLSStream =
  this.hlsStream = this.getStream(this)
  return this.hlsStream
proc ListResolutions*(this: SVideo): seq[MediaStreamTuple] =
  return this.listResolution(this)
proc SearchDownloader*(this: SNovel, str: string): seq[MetaData] =
  return this.searchDownloader(this, str)
proc SearchDownloader*(this: SVideo, str: string): seq[MetaData] =
  return this.searchDownloader(this, str)
proc SelResolution*(this: SVideo, tul: MediaStreamTuple) =
  this.selResolution(this, tul)

proc ParseInfoTuple(file: string): InfoTuple =
  var infoTuple: InfoTuple = (name: "", cover: "", scraperType: "", version: "", projectUri: "", siteUri: "", scriptPath: "")
  var lines = file.splitLines
  for line in lines:
    var str = line.strip
    if str == "": continue
    if str.startsWith("#"):
      str.removePrefix('#')
      str = str.strip
      var pair = str.split(':')
      if pair.len < 2: continue
      var key = pair[0].strip
      pair.delete(0)
      var value = pair.join(":").strip
      case key:
        of "name":
          infoTuple.name = value
        of "cover":
          infoTuple.cover = value
        of "scraperType":
          infoTuple.scraperType = value
        of "version":
          infoTuple.version = value
        of "projectUri":
          infoTuple.projectUri = value
        of "siteUri":
          infoTuple.siteUri = value
    else: break
  return infoTuple

proc ReadScriptInfoTuple*(path: string): InfoTuple =
  var infoTuple = ParseInfoTuple(readFile(path))
  infoTuple.scriptPath = path
  return infoTuple

proc processHttpRequest(uri: string, scriptID: int, headers: seq[tuple[key: string, value: string]], mimicBrowser: bool = false): string =
  if mimicBrowser:
    # TODO: When windows, verify browsers installed
    # TODO: When linux, verify browsers installed
    # TODO: Move this from where it currently sits, and have it be somewhat like http clients, assigned based on script.
    #   So we do not have to create a new browser session every request.
    # Will currenctly default to chromium, since I believe that network stack is less likely to be blocked due to fingerprinting.
    var sesh = createSession(Chromium, browserOptions=chromeOptions(args=["--headless", "--user-agent=Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/105.0.0.0 Safari/537.36"]), hideDriverConsoleWindow=true)
    sesh.navigate uri
    return sesh.pageSource()
  var reqHeaders: HttpHeaders = newHttpHeaders()
  for i in headers:
    reqHeaders.add(i.key, i.value)
  NScriptClient.headers = reqHeaders
  let request = NScriptClient.request(url = uri, httpMethod = HttpGet, headers = reqHeaders)
  case request.status:
    of "404":
      return "404"
    else:
      return request.body


exportTo(ADLNovel,
  InfoTuple, Status, NodeKind, LanguageType, MetaData,
  ImageKind, Image, TiNode, Chapter,
  processHttpRequest, SeekNode, sanitizeString)

const novelInclude = implNimScriptModule(ADLNovel)

proc GenNewScript*(path: string): NScript =
  if NScriptClient == nil:
    NScriptClient = newHttpClient()
  var script: NScript = NScript()
  let scr = NimScriptPath(path)
  script.intr = loadScript(scr, novelInclude, ["xmltree", "htmlparser"])
  script.headerInfo = ReadScriptInfoTuple(path)
  NScripts.add script
  script.intr.invoke(SetID, len(NScripts))
  return script

proc ScanForScriptsInfoTuple*(folderPath: string): seq[Interp.InfoTuple] =
  var scripts: seq[Interp.InfoTuple] = @[]
  for n in walkFiles(folderPath / "*.nims"):
    var tup = ReadScriptInfoTuple(n)
    scripts.add(tup)
  return scripts