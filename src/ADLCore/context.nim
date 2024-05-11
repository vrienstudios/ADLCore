import std/[os, xmltree, sequtils, httpclient, json, htmlparser, uri, strutils, parseutils, base64]
import nimscripter
import nimcrypto
import EPUB
import ./utils
import ./hls
export TiNode, sequtils, os, xmltree, strutils, httpclient, htmlparser, uri, parseutils, json, utils, hls, base64, nimcrypto

type
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
  Chapter* = ref object of RootObj
    metadata*: MetaData
    streamIndex*: int
    selStream*: seq[string]
    jDat*: JsonNode
    key*, iv*: string
    mainStream*: StreamTuple
    contentSeq*: seq[TiNode]
  Volume* = ref object of RootObj
    mdat*: MetaData
    baseUri*: string
    jDat*: JsonNode
    lower*, upper*: int 
    sResult*: bool
    index*: int
    parts*: seq[Chapter]
  DownloaderContext* = ref object of RootObj
    name*: string
    downloadPath*: string
    script: NScript
    upper*, lower*: int
    index*: int
    sections*: seq[Volume]
    ourClient*: HttpClient
    globalKey*: string
    page*: XmlNode
    defaultHeaders*: HttpHeaders
    defaultPage*: string
    currPage*: string
    baseUri*: string
    setMetadataP, setSearchP, setPartsP, setContentP, prepareP: proc(this: var DownloaderContext)
  MethodList* = 
    tuple[identifier, dType: string, procs: seq[tuple[procType: string, thisProc: proc(this: var DownloaderContext){.nimcall,gcsafe.}]]]
  Site* = ref object of RootObj
    identifier*: string
    baseUri*: string
    uriList*: seq[string]
  InfoTuple* = tuple[name: string, cover: string, scraperType: string, version: string, projectUri: string, siteUri: string, scriptPath: string]
  NScript* = ref object
    headerInfo*: InfoTuple
    scriptID: int
    intr: Option[Interpreter]
method `+=`*(site: Site, str: string) =
  site.uriList.add str
var 
  siteList*: seq[Site] = @[]
  downloaderList*: seq[MethodList] = @[("", "script", @[("metadata", nil), ("parts", nil), ("search", nil), ("content", nil)])]
proc isIn*(site: Site, str: string): bool =
  for i in site.uriList:
    if str != i: continue
    return true
proc getSite*(str: string): Site =
  for site in siteList:
    if not isIn(site, str): continue
    return site
proc `[]`*(vol: var Volume, idx: int): var Chapter =
  return vol.parts[idx]
proc `[]`*(ctx: var DownloaderContext, idx: int): Volume =
  return ctx.sections[idx]
proc `[]`*(ctx: var DownloaderContext, x, y: int): Chapter =
  return ctx.sections[x].parts[y]
proc isNil*(ctx: DownloaderContext): bool =
    return (ctx.setMetadataP == nil or ctx.setSearchP == nil or ctx.setPartsP == nil or ctx.setContentP == nil)
proc section*(ctx: var DownloaderContext): Volume =
  return ctx.sections[ctx.index]
proc chapter*(ctx: var DownloaderContext): Chapter =
  var vol = ctx.sections[ctx.index]
  return vol[vol.index]
proc setupDownloader*(downloader: var Downloadercontext, this: MethodList) =
  for meth in this.procs:
    case meth.procType:
      of "metadata":
        downloader.setMetadataP = meth.thisProc
      of "parts":
        downloader.setPartsP = meth.thisProc
      of "search":
        downloader.setSearchP = meth.thisProc
      of "content":
        downloader.setContentP = meth.thisProc
      of "prepare":
        downloader.prepareP = meth.thisProc
      else:
        continue
proc setDefaultHeaders*(this: var DownloaderContext) =
  if this.defaultHeaders == nil:
    this.defaultHeaders = newHttpHeaders({
      "User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:101.0) Gecko/20100101 Firefox/101.0",
      "Referer": this.baseUri,
      "x-requested-with": "XMLHttpRequest",
      "Accept": "*/*",
      "Accept-Encoding": "identity",
    })
  this.ourClient.headers = this.defaultHeaders
proc setPage*(this: var DownloaderContext, page: string) =
  if this.currPage == page:
    return
  setDefaultHeaders(this)
  this.page = parseHtml(this.ourClient.getContent(page))
  this.currPage = page
iterator walkSections*(ctx: var DownloaderContext): Volume =
  ctx.index = 0
  while ctx.index < ctx.sections.len:
    yield ctx.section
    inc ctx.index
  ctx.index = 0
iterator walkChapters*(ctx: var DownloaderContext): Chapter =
  ctx.section.index = 0
  while ctx.section.index < ctx.section.parts.len:
    yield ctx.chapter
    inc ctx.section.index
  ctx.section.index = 0
proc isDownloader*(uriHost: string): bool =
  for site in siteList:
    if not isIn(site, uriHost): continue
    return true
proc isUrl*(uriHost: string): bool =
  let uri = parseUri(uriHost)
  return (uri.hostname != "")
proc selectResolution*(this: var DownloaderContext, id: string) =
  var mTuple: MediaStreamTuple
  var chapter: Chapter = this.chapter
  for sub in chapter.mainStream.subStreams:
    if sub.id != id:
      continue
    mTuple = sub
    break
  var vManifest = ParseManifest(splitLines(this.ourClient.getContent(mTuple.uri)), chapter.mainStream.stream.baseUri)
  var vSeq: seq[string] = @[]
  for part in vManifest.parts:
    if part.header == "URI":
      vSeq.add(part.values[0].value)
  chapter.selStream = vSeq

var scriptContextTracker*: seq[DownloaderContext] = @[]
proc processHttpRequest*(uri: string, scriptID: int, headers: seq[tuple[key: string, value: string]], mimicBrowser: bool = false): string =
  var ctx = scriptContextTracker[scriptID]
  var reqHeaders: HttpHeaders = newHttpHeaders()
  for i in headers:
    reqHeaders.add(i.key, i.value)
  let req = ctx.ourClient.request(uri, HttpGet, "", reqHeaders)
  return req.body
proc httpGet*(this: var DownloaderContext, str: Uri | string): string =
  return this.ourClient.getContent(str)
proc parseManifestInterp*(manifest: string, baseUri: string = ""): HLSStream =
  return ParseManifest(manifest.split('\n'), baseUri)
proc indexStream*(this: HLSStream, header: string): seq[Head] =
  return this[header]
proc indexStreamHead*(this: Head, key: string): string =
  return this[key]
# Author: @Tsu
proc parseInfoTuple(file: string): InfoTuple =
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
# Author: @Tsu
proc readScriptInfoTuple*(path: string): InfoTuple =
  var infoTuple = parseInfoTuple(readFile(path))
  infoTuple.scriptPath = path
  return infoTuple

exportTo(ADLScript,
  InfoTuple, Status, NodeKind, LanguageType, MetaData,
  ImageKind, Image, TiNode, Chapter, MediaStreamTuple,
  Param, Head, HLSStream, parseManifestInterp, indexStream,
  indexStreamHead, 
  processHttpRequest, SeekNode, sanitizeString)
const scriptIncludes = implNimScriptModule(ADLScript)

# Scripts
proc setScript*(ctx: var DownloaderContext, path: string) =
  var script: NScript = NScript()
  let scr = NimScriptPath(path)
  script.intr = loadScript(scr, scriptIncludes, ["json", "xmltree", "htmlparser", "strutils"])
  script.headerInfo = readScriptInfoTuple(path)
  script.intr.invoke(SetID, len(scriptContextTracker))
  ctx.script = script
proc setScriptMetadataScript*(ctx: var DownloaderContext) =
  var 
    meta: MetaData = ctx.script.intr.invoke(GetMetaData, returnType = MetaData)
    vol: Volume = Volume(mdat: meta, lower: -1, upper: -1)
  ctx.sections.add vol
proc setScriptChapters*(ctx: var DownloaderContext) =
  var metas: seq[MetaData] = ctx.script.intr.invoke(GetChapters, ctx.section, returnType = seq[MetaData])
  for meta in metas:
    ctx.section.parts.add Chapter(metadata: meta)
proc setScriptPreparation*(ctx: var DownloaderContext) =
  let stream = ctx.script.intr.invoke(GetHLSStream, ctx.chapter, returnType = HLSStream)
  ctx.chapter.mainStream = (stream, parseSubStream(stream))
proc setScriptContent*(ctx: var DownloaderContext) =
  ctx.chapter.contentSeq.add ctx.script.intr.invoke(GetNodes, ctx.chapter, returnType = seq[TiNode])

# Management
proc generateContext*(str: string): DownloaderContext =
  let pUri = parseUri(str)
  let site: Site =
    if pUri.hostname == "": getSite(str)
    else: getSite(pUri.hostname)
  var context: DownloaderContext
  for downloader in downloaderList:
    if downloader.identifier != site.identifier: continue
    var http = newHttpClient()
    context = DownloaderContext(ourClient: http, baseUri: "https://" & site.baseUri & "/", defaultPage: $pUri)
    context.setupDownloader(downloader)
    context.setDefaultHeaders()
    return context
proc shiftContext*(ctx: var DownloaderContext, site: Site, fullUri: string) =
  ctx.baseUri = site.baseUri
  ctx.defaultPage = fullUri
  for uri in downloaderList:
    if site.identifier != uri.identifier: continue
    ctx.setupDownloader(uri)
proc setMetadata*(ctx: var DownloaderContext): bool =
  if ctx.setMetadataP == nil:
    return false
  ctx.setMetadataP(ctx)
  return true
proc setSearch*(ctx: var DownloaderContext): bool =
  if ctx.setSearchP == nil:
    return false
  ctx.setSearchP(ctx)
  return true
proc setParts*(ctx: var DownloaderContext): bool =
  if ctx.setPartsP == nil:
    return false
  ctx.setPartsP(ctx)
  return true
proc setContent*(ctx: var DownloaderContext): bool =
  if ctx.setContentP == nil:
    return false
  ctx.setContentP(ctx)
  return true
proc doPrep*(ctx: var DownloaderContext): bool =
  if ctx.prepareP == nil:
    return false
  ctx.prepareP(ctx)
  return true
proc setSearch*(ctx: var DownloaderContext, query: string): bool =
  if ctx.setSearchP == nil:
    return false
  ctx.name = query
  return ctx.setSearch()
# Clears content after access
iterator walkVideoContent*(ctx: var Downloadercontext): TiNode =
  # StreamIndex automatically increased on setContent
  while ctx.chapter.streamIndex < ctx.chapter.selStream.len:
    discard ctx.setContent()
    yield ctx.chapter.contentSeq[0]
    ctx.chapter.contentSeq = @[]
iterator walkNovelContent*(ctx: var DownloaderContext): seq[TiNode] =
  for i in walkChapters(ctx):
    discard ctx.setContent()
    yield ctx.chapter.contentSeq