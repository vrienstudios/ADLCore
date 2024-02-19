import nimscripter, nimcrypto
import EPUB
import HLSManager
import std/[os, httpclient, htmlparser, xmltree, strutils, parseutils, base64, json, sequtils]
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
    tuple[baseUri, dType: string, procs: seq[tuple[procType: string, thisProc: proc(this: var DownloaderContext){.nimcall,gcsafe.}]]]
  NScript* = ref object
    headerInfo*: InfoTuple
    scriptID: int
    intr: Option[Interpreter]
  MediaStreamTuple* = tuple[id: string, resolution: string, uri: string, language: string, isAudio: bool, bandWidth: string]
  StreamTuple* = tuple[stream: HLSStream, subStreams: seq[MediaStreamTuple]]
  Chapter* = ref object of RootObj
    metadata*: MetaData
    streamIndex*: int
    selStream*: seq[string]
    key, iv: string
    mainStream*: StreamTuple
    contentSeq*: seq[TiNode]
  Volume* = ref object of RootObj
    mdat*: MetaData
    baseUri*: string
    lower*, upper: int 
    sResult*: bool
    index*: int
    parts*: seq[Chapter]
  DownloaderContext* = ref object of RootObj
    name*: string
    downloadPath*: string
    script: NScript
    upper, lower: int
    index*: int
    sections*: seq[Volume]
    ourClient: HttpClient
    page: XmlNode
    defaultHeaders*: HttpHeaders
    defaultPage*: string
    currPage*: string
    baseUri*: string
    setMetadataP, setSearchP, setPartsP, setContentP, prepareP: proc(this: var DownloaderContext)

proc `[]`*(vol: var Volume, idx: int): var Chapter =
  return vol.parts[idx]
proc `[]`*(ctx: var DownloaderContext, idx: int): Volume =
  return ctx.sections[idx]
proc `[]`*(ctx: var DownloaderContext, x, y: int): Chapter =
  return ctx.sections[x].parts[y]
proc section*(ctx: var DownloaderContext): Volume =
  return ctx.sections[ctx.index]
proc chapter*(ctx: var DownloaderContext): Chapter =
  var vol = ctx.sections[ctx.index]
  return vol[vol.index]
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
proc isNil*(ctx: DownloaderContext): bool =
    return (ctx.setMetadataP == nil or ctx.setSearchP == nil or ctx.setPartsP == nil or ctx.setContentP == nil)
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
proc setPage(this: var DownloaderContext, page: string) =
  if this.currPage == page:
    return
  this.page = parseHtml(this.ourClient.getContent(page))
  this.currPage = page
proc setDefaultHeaders(this: var DownloaderContext) =
  this.ourClient.headers = newHttpHeaders({
    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:101.0) Gecko/20100101 Firefox/101.0",
    "Referer": this.baseUri,
    "x-requested-with": "XMLHttpRequest",
    "Accept": "*/*",
    "Accept-Encoding": "identity",
  })
proc parseSubStream(hlsBase: HLSStream): seq[MediaStreamTuple] =
  var medStream: seq[MediaStreamTuple] = @[]
  var index: int = 0
  for segment in hlsBase.parts:
    if segment.header == "#EXT-X-MEDIA:":
      var id: string
      var language: string
      var uri: string
      for param in segment.values:
        case param.key:
          of "GROUP-ID": id = param.value
          of "LANGUAGE": language = param.value
          of "URI":
            uri = param.value
          else: discard
      medStream.add((id: id, resolution: "", uri: uri, language: language, isAudio: true, bandWidth: ""))
    elif segment.header == "#EXT-X-STREAM-INF:":
      var bandwidth: string
      var resolution: string
      var id: string
      var uri: string
      for param in segment.values:
        case param.key:
          of "BANDWIDTH": bandwidth = param.value
          of "RESOLUTION": resolution = param.value
          of "AUDIO": id = param.value
          else: discard
      uri = hlsBase.parts[index + 1]["URI"]
      medStream.add((id: id, resolution: resolution, uri: uri, language: "", isAudio: false, bandWidth: bandwidth))
    inc index
  return medStream
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
proc loadHAnimeSearch(ctx: var DownloaderContext) =
  # https://search.htv-services.com/
  let mSearchData = %*{
    "blacklist": [],
    "brands": [],
    "order_by": "created_at_unix",
    "ordering": "desc",
    "page": 0,
    "search_text": ctx.name,
    "tags": [],
    "tags_mode": "AND"
  }
  let defHeaders = newHttpHeaders({
    "Content-Type": "application/json"
  })
  let response = ctx.ourClient.request("https://search.htv-services.com/", httpMethod = HttpPost, body = $mSearchData,
    headers = defHeaders)
  let jsonData = parseJson(parseJson(response.body)["hits"].getStr()).getElems()
  for i in jsonData:
    var met: MetaData = MetaData()
    met.name = i["name"].getStr()
    met.uri = "https://HAnime.tv/videos/hentai/" & i["slug"].getStr()
    met.coverUri = i["cover_url"].getStr()
    met.series = i["brand"].getStr()
    # Contains <p> html element.
    met.description = parseHtml(i["description"].getStr()).innerText
    var tags: seq[string] = @[]
    for tag in i["tags"].getElems():
      tags.add(tag.getStr())
    met.genre = tags
    ctx.sections.add Volume(mdat: met, lower: -1, upper: -1, sResult: true)
proc loadHAnimeMetadata(ctx: var DownloaderContext) =
  setPage(ctx, ctx.defaultPage)
  var
    meta: MetaData = MetaData()
    jsonData: string
  for script in ctx.page.findAll("script"):
    if script.innerText.contains("__NUXT__"):
      jsonData = script.innerText[16..^2]
      break
  var videoData = parseJson(jsonData)["state"]["data"]["video"]
  let jObj = videoData["hentai_video"]
  meta.name = jObj["name"].getStr()
  meta.description = parseHtml(jObj["description"].getStr()).innerText
  meta.author = jObj["brand"].getStr()
  meta.coverUri = jObj["cover_url"].getStr()
  meta.uri = "https://www.hanime.tv/" & jObj["slug"].getStr()
  var vol = Volume(mdat: meta, lower: -1, upper: -1)
  ctx.sections.add vol
#proc loadHAnimeChapters(ctx: var DownloaderContext) = 
iterator embtakuGetChapter(this: var DownloaderContext, l, h: int): Chapter =
  setPage(this, this.defaultPage)
  var videoList: XmlNode =
    recursiveNodeSearch(this.page, parseHtml("<ul class=\"listing items lists\">"))
  var 
    idx: int = 
      if h > len(videoList) or h < 0 or h == 0: len(videoList)
      else: h
    lower: int =
      if l < 0 or l == 0 or l > len(videoList): 0
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
proc loadEmbtakuHLS(ctx: var DownloaderContext) =
  var this: Chapter = ctx.chapter
  setPage(ctx, this.metadata.uri)
  setPage(ctx, "https:" & ctx.page.findAll("iframe")[0].attr("src"))
  let pageScripts = ctx.page.findAll("script")
  # VidStream has a very roundabout way of encrypting their content
  # Datakey is a url, which you have to use to complete the ajax request.
  var dataKey: string
  for script in pageScripts:
    if script.attr("data-name") == "episode":
      dataKey = script.attr("data-value").decode()
      break
  assert dataKey != ""
  # BodyKey is used as the key for encrypting and decrypting the ajax request.
  var bodyKey: string
  for videocontent in ctx.page.findAll("body"):
    if(videocontent.attr("class").contains("container")):
      bodyKey = videocontent.attr("class").split('-')[1]
      break
  assert bodyKey != ""
  var videoKey: string
  var wrapperIV: string
  for videocontent in ctx.page.findAll("div"):
    if(videocontent.attr("class").contains("wrapper")):
      wrapperIV = videocontent.attr("class").split('-')[1]
      continue
    if(videocontent.attr("class").contains("videocontent")):
      videoKey = videocontent.attr("class").split('-')[1]
      break
  assert wrapperIV != ""
  assert videoKey != ""
  # Get the Url params
  var 
    dctx: CBC[aes256]
    idx: int = 0
    dText: string = newString(len(dataKey))
  dctx.init(bodyKey, wrapperIV)
  dctx.decrypt(dataKey, dText)
  var bodyUri = dText.split('&') # param list
  assert bodyUri.len > 1
  var encID = bodyUri[0] # ID of the anime
  dctx.clear()
  # Setup encryption of the ID for the encrypt-ajax handler. (base64, key 128, blocksize 256)
  var 
    ectx: CBC[aes256]
    key = newString(aes256.sizeKey)
    iv = newString(aes256.sizeBlock)
    plainText = padPKSC7(encID)
    encText = newString(aes256.sizeBlock * 2)
  copyMem(addr key[0], addr bodyKey[0], len(bodyKey))
  copyMem(addr iv[0], addr wrapperIV[0], len(wrapperIV))
  ectx.init(key, iv)
  ectx.encrypt(plainText, encText)
  ectx.clear()
  # Probably shouldn't have made this of a set size, but it should be within this length.
  var pText: seq[byte] = @(encText.toOpenArrayByte(0, encText.len - aes256.sizeBlock - 1))
  var uriArgs: string
  for strings in bodyUri[1..(len(bodyUri) - 2)]:
    uriArgs.add("&" & strings)
  # Create the final url to request from.
  let mainReqUri: string = ctx.baseUri & "encrypt-ajax.php?id=" & encode(pText) & uriArgs & "&alias=" & encID
  ctx.ourClient.headers = newHttpHeaders({
      "User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:101.0) Gecko/20100101 Firefox/101.0",
      "Referer": ctx.baseUri & "streaming.php",
      "x-requested-with": "XMLHttpRequest",
      "Accept": "*/*",
      "Accept-Encoding": "identity",
  })
  let data = ctx.ourClient.getContent(mainReqUri)
  var json = parseJSon(data)
  var jData = json["data"].getStr().decode()
  # Load and decrypt the json response
  dctx.init(videoKey, wrapperIV)
  var decVideoData: string = newString(len(jData))
  dctx.decrypt(jData, decVideoData)
  dctx.clear()
  # Fix URL's within the response, '\' characters in front of '/' are replaced.
  decVideoData = decVideoData.replace("\\")
  # Error in nims json parsing, which results in {expected EOF at EOF}, so we can't load the returned json into the jsonParser.
  # Instead, I do a bit of manual, but unsafe parsing, which should be changed, when the json library is updated.
  let 
    uri = decVideoData.split('"')[5]
    parts: seq[string] = (ctx.ourClient.getContent(uri)).split('\n')
    mainStream = ParseManifest(parts, uri[0 .. ^(uri.split('/')[^1].len + 1)])
  this.mainStream = (mainStream, parseSubStream(mainStream))
proc loadEmbtakuMetadata(this: var DownloaderContext) =
  setPage(this, this.defaultPage)
  var 
    meta: MetaData = MetaData()
    videoInfoPanel: XmlNode
  for divObj in this.page.findAll("div"):
    if divObj.attr("class") != "video-info-left":
      continue
    videoInfoPanel = divObj
    break
  for class in videoInfoPanel.items:
    if class.kind != xnElement:
      continue
    if class.tag == "h1":
      meta.name = sanitizeString(class.innerText)
      continue
    if class.attr("class") == "video-details":
      meta.series = sanitizeString(class.child("span").innerText)
      meta.description = sanitizeString(class.child("div").child("div").innerText)
      break
  var vol = Volume(mdat: meta, lower: -1, upper: -1)
  this.sections.add vol
proc loadEmbtakuSearch(this: var Downloadercontext) =
  let 
    content = this.ourClient.getContent(this.baseUri / "ajax-search.html?keyword=" & this.name & "&id=-1")
    json = parseJson(content)
  var 
    results: seq[Volume] = @[]
    page = parseHtml(json["content"].getStr())
  for a in this.page.findAll("a"):
    var data = MetaData()
    data.name = a.innerText
    data.uri = this.baseUri & a.attr("href")
    results.add(Volume(mdat: data, lower: -1, upper: -1, sResult: true))
  this.sections.add(results)
proc loadEmbtakuChapters(this: var DownloaderContext) =
  var vol: Volume = this.sections[this.index]
  for chap in embtakuGetChapter(this, this.lower, this.upper):
    vol.parts.add chap
proc loadEmbtakuChapterData(this: var Downloadercontext) =
  var chapter = this.chapter
  let videoData: string = this.ourClient.getContent(chapter.selStream[chapter.streamIndex])
  inc chapter.streamIndex
  chapter.contentSeq.add TiNode(text: videoData)
proc loadNovelHallSearch(this: var DownloaderContext) =
  let 
    content = this.ourClient.getContent("https://www.novelhall.com/index.php?s=so&module=book&keyword=" & this.name.replace(' ', '&'))
    page: XmlNode = parseHtml(content)
  for node in page.findAll("section"):
    if node.attr("id") != "main":
      continue
    for tableItem in node.child("table").child("tbody").findAll("tr"):
      let tD = node.findAll("td").toSeq()
      var data = MetaData()
      data.genre = @[td[0].child("a").innerText]
      let uriBN = td[1].child("a")
      data.name = uriBN.innerText
      data.uri = "https://www.novelhall.com" & uriBN.attr("href")
      this.sections.add Volume(mdat: data, lower: -1, upper: -1, sResult: true)
    return
iterator novelhallGetChapter(this: var DownloaderContext, l, h: int): Chapter =
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
proc loadNovelHallChapters(this: var DownloaderContext) =
  var vol: Volume = this.sections[this.index]
  for chap in novelhallGetChapter(this, vol.lower, vol.upper):
    vol.parts.add chap
proc getNovelHallChapterDataFromPage(page: XmlNode): seq[TiNode] =
  var nodes: seq[TiNode] = @[]
  for i in page.findAll("div"):
    if i.attr("class") != "entry-content":
      continue
    var ourNode = TiNode(text: "")
    for text in i.items:
      if text.kind == xnText:
        ourNode.text.add text.innerText
        continue
      if text.kind == xnElement:
        nodes.add ourNode
        ourNode = TiNode(text: "")
        continue
    break
  return nodes
proc loadAllNovelHallChapterData(this: var DownloaderContext) =
  for chapter in this.section.parts:
    let page = parseHtml(this.ourClient.getContent(chapter.metadata.uri))
    chapter.contentSeq = getNovelHallChapterDataFromPage(page)
proc loadNovelHallChapter(this: var DownloaderContext) =
  var chapter = this.chapter
  let pageNode: XmlNode = parseHtml(this.ourClient.getContent(chapter.metadata.uri))
  chapter.contentSeq = getNovelHallChapterDataFromPage(pageNode)
proc loadNovelHallMetadata(this: var DownloaderContext) =
  setPage(this, this.defaultPage)
  var metadata: MetaData = MetaData()
  let 
    bookPage = recursiveNodeSearch(this.page, parseHtml("<div class=\"book-info\">"))
    underInfo = recursiveNodeSearch(bookPage, parseHtml("<div class=\"total booktag\">"))
    introInfo = recursiveNodeSearch(bookPage, parseHtml("<div class=\"intro\">"))
  metadata.name = bookPage.child("h1").innerText
  for i in underInfo.findAll("a"):
    metadata.genre.add i.innerText
  for i in underInfo.findAll("span"):
    let inner = i.innerText[0..5]
    if inner == "Author":
      metadata.author = i[0].innerText[9..^1]
      break
      # TODO: Add enum and update time later.
  metadata.coverUri = introInfo.child("img").attr("src")
  metadata.description = sanitizeString(introInfo.child("span")[0].innerText)
  var vol = Volume(mdat: metadata, lower: -1, upper: -1)
  this.sections.add vol
const downloaderList: array[5, MethodList] =
  [("embtaku.pro", "video", @[("metadata", loadEmbtakuMetadata), ("parts", loadEmbtakuChapters), ("search", loadEmbtakuSearch), ("prepare", loadEmbtakuHLS), ("content", loadEmbtakuChapterData), ("home", nil)]),
    ("hanime.tv", "video", @[("metadata", nil), ("parts", nil), ("search", nil), ("content", nil), ("home", nil)]),
    ("www.novelhall.com", "text", @[("metadata", loadNovelHallMetadata), ("parts", loadNovelHallChapters), ("search", loadNovelHallSearch), ("content", loadNovelHallChapter), ("home", nil)]),
    ("mangakakalot.com", "text", @[("metadata", nil), ("parts", nil), ("search", nil), ("content", nil), ("home", nil)]),
    ("", "script", @[("metadata", nil), ("parts", nil), ("search", nil), ("content", nil), ("home", nil)])]

#tuple[baseUri, dType: string, procs: seq[tuple[procType: string, thisProc: proc(this: RootObj)]]]
proc setupDownloader(this: MethodList, downloader: var DownloaderContext) =
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
  return
proc generateContext*(baseUri, fullUri: string): DownloaderContext =
  for uri in downloaderList:
    if baseUri == uri.baseUri:
      var downloader = DownloaderContext(ourClient: newHttpClient(), baseUri: "https://" & baseUri & "/", defaultPage: fullUri)
      setDefaultHeaders(downloader)
      uri.setupDownloader(downloader)
      return downloader
  return nil
proc shiftContext*(ctx: var DownloaderContext, baseUri, fullUri: string) =
  ctx.baseUri = baseUri
  ctx.defaultPage = fullUri
  for uri in downloaderList:
    if baseUri == uri.baseUri:
      uri.setupDownloader(ctx)
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
  return true
#let script = GenNewScript(ScanForScriptsInfoTuple("/mnt/General/work/Programming/ADLCore/src/")[0])
#let mdata = script[0].GetMetaData("https://www.volarenovels.com/novel/physician-not-a-consort")
#echo mdata.name
#echo mdata.author

# Testing code for scripts (do NOT build projects with this code included)
#var lam = ScanForScriptsInfoTuple("./")
#for l in lam:
#  var sc = GenNewScript("./" & l.name & ".nims")