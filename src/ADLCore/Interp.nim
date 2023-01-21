import nimscripter
import genericMediaTypes
include ./Novel/NovelTypes
import ./Video/VideoType
import std/[httpclient, htmlparser, xmltree, strutils, strtabs, parseutils, sequtils]
import EPUB/types
import HLSManager
import options, os, halonium
import zippy

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

converter toSNovel*(x: Novel): SNovel =
  SNovel(isOwnedByScript: x.isOwnedByScript,
    metaData: x.metaData, lastModified: x.lastModified,
    volumes: x.volumes, chapters: x.chapters, currChapter: x.currChapter,
    ourClient: x.ourClient, page: x.page, defaultHeaders: x.defaultHeaders,
    defaultPage: x.defaultPage, currPage: x.currPage,
    init: x.init, GgetNodes: x.GgetNodes, getMetaData: x.getMetaData,
    getChapterSequence: x.getChapterSequence, getHomeCarousel: x.getHomeCarousel,
    searchDownloader: x.searchDownloader, getCover: x.getCover)

var NScripts: seq[NScript] = @[]
var NScriptClient: seq[ptr HttpClient] = @[]

method getNodes*(this: Nscript, chapter: Chapter): seq[TiNode] =
  return this.intr.invoke(GetNodes, chapter, returnType = seq[TiNode])
method getMetaData*(this: Nscript, page: string): MetaData =
  return this.intr.invoke(GetMetaData, page, returnType = MetaData)
method getChapterSequence*(this: Nscript, page: string): seq[Chapter] =
  return this.intr.invoke(GetChapterSequence, returnType = seq[Chapter])
# getHomeCarousel should probably return a seq[MetaData] that is later consumed by getChapterSequence to get a download
method getHomeCarousel*(this: Nscript, page: string): seq[MetaData] =
  return this.intr.invoke(GetHomeCarousel, page, returnType = seq[MetaData])
method searchDownloader*(this: Nscript, str: string): seq[MetaData] =
  return this.intr.invoke(Search, str, returnType = seq[MetaData])
# May be a bit repetitive, but those relating directly to the script, may be deprecated in the future.
method getNodes*(this: SNovel, chapter: Chapter): seq[TiNode] =
  if this.script == nil:
    return this.GgetNodes(Novel(this),  chapter)
  return this.script.intr.invoke(GetNodes, chapter, returnType = seq[TiNode])

# Video Specific
method getStream*(this: NScript): HLSStream =
  return this.intr.invoke(getStream, returnType = HLSStream)
method getEpisodeSequence*(this: NScript): seq[MetaData] =
  return this.intr.invoke(getStream, returnType = seq[MetaData])
method getResolutions*(this: NSCript): seq[MediaStreamTuple] =
  return this.intr.invoke(getResolution, returnType = seq[MediaStreamTuple])
method selResolution*(this: NScript, azul: MediaStreamTuple): bool =
  return this.intr.invoke(selResolution, azul, returnType = bool)

  # Changed to 'get' next video/audio part, since it may be better to just retrieve the data rather than writing to disk directly.
  # However, without rewriting portions of the build in functions, please don't use this.
  # It's mainly just a proof of concept right now.
method getNextVideoPart*(this: NScript): string =
  return this.intr.invoke(getNextVideoPart, returnType = string)
method getNextAudioPart*(this: NScript): string =
  return this.intr.invoke(getNextAudioPart, returnType = string)

# Video Specific SVideo functions
method setMetaData*(this: SVideo) =
  if this.script != nil:
    this.metaData = getMetaData(this.script, this.defaultPage)
    return
  this.metaData = getMetaData(this)
#method
#method setEpisodeSequence*(this: SVideo) =
#  if this.script == nil:
#method setMetaData*(this: SNovel, page: string) =
#  this.metaData = this.script.intr.invoke(GetMetaData, page, returnType = MetaData)
#method setChapterSequence*(this: SNovel, page: string) =
#  this.chapters = this.script.intr.invoke(GetChapterSequence, returnType = seq[Chapter])
method setMetaData*(this: SNovel) =
  if this.script != nil:
    this.metaData = getMetaData(this.script, this.defaultPage)
    return
  this.metaData = getMetaData(this)
method setChapterSequence*(this: SNovel) =
  if this.script != nil:
    this.chapters = getChapterSequence(this.script, "")
    return
  this.chapters = getChapterSequence(this)
# getHomeCarousel should probably return a seq[MetaData] that is later consumed by getChapterSequence to get a download
method getHomeCarousel*(this: SNovel, page: string): seq[MetaData] =
  if this.script != nil:
    return this.script.getHomeCarousel(page)
  return getHomeCarousel(this)

method searchDownloader*(this: SNovel, str: string): seq[MetaData] =
  if this.script == nil:
    return searchDownloader(this, str)
  return this.script.intr.invoke(Search, str, returnType = seq[MetaData])

method getDefHttpClient*(this: SNovel): HttpClient =
  if this.script == nil:
    return this.ourClient
  return cast[HttpClient](NScriptClient[this.script.scriptID])

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
  var g: HttpClient = cast[HttpClient](NScriptClient[scriptID])
  for i in headers:
    reqHeaders.add(i.key, i.value)
  g.headers = reqHeaders
  echo g.headers
  let request = g.request(url = uri, httpMethod = HttpGet, headers = reqHeaders)
  case request.status:
    of "404":
      return "404"
    else:
      return request.body

proc attrEquivalenceCheck*(a, b: XmlNode): bool =
  if a.attrs == nil and b.attrs == nil:
    return true
  if a.attrs == nil or b.attrs == nil:
    return false
  if a.attrs.len != b.attrs.len:
    return false
  for k in a.attrs.keys:
    if b.attrs.hasKey(k):
      if b.attrs[k] == a.attrs[k]:
        continue
    return false
  return true
proc checkEquivalence*(a, b: XmlNode): bool =
  if a.kind == b.kind:
    if a.kind == xnElement:
      # Text comparison can happen somewhere else
      if attrEquivalenceCheck(a, b) and a.tag == b.tag:
        return true
  return false
proc recursiveNodeSearch*(x: XmlNode, n: XmlNode): XmlNode =
  if $x == $n or checkEquivalence(x, n):
    return x
  for item in x.items:
    if $item == $n or checkEquivalence(item, n):
      return item
    if item.kind != xnElement:
      continue
    let ni = recursiveNodeSearch(item, n)
    if ni != nil:
      return ni
  return nil
# Using strings as a workaround of the nnkSym error.
proc SeekNode*(node: string, desiredNode: string): string =
  return $recursiveNodeSearch(parseHtml(node), parseHtml(desiredNode))

exportTo(ADLNovel,
  InfoTuple, Status, TextKind, LanguageType, MetaData,
  ImageType, Image, TiNode, Chapter,
  processHttpRequest, SeekNode)

const novelInclude = implNimScriptModule(ADLNovel)

proc GenNewScript*(path: string): NScript =
  var script: NScript = NScript()
  let scr = NimScriptPath(path)
  script.intr = loadScript(scr, novelInclude)
  script.headerInfo = ReadScriptInfoTuple(path)
  NScripts.add script
  var hClient = newHttpClient()
  GC_unref hClient
  script.intr.invoke(SetID, len(NScriptClient))
  NScriptClient.add(cast[ptr HttpClient](hClient))
  echo NScriptClient.len
  return script

proc ScanForScriptsInfoTuple*(folderPath: string): seq[Interp.InfoTuple] =
  var scripts: seq[Interp.InfoTuple] = @[]
  for n in walkFiles(folderPath / "*.nims"):
    var tup = ReadScriptInfoTuple(n)
    scripts.add(tup)
  return scripts