import HLSManager
import ../genericMediaTypes
import std/[os, asyncdispatch, httpclient, htmlparser, xmltree, strutils, strtabs, parseutils, sequtils, base64, json]
import nimcrypto
import std/json
import VideoType
# Please follow this layout for any additional sites.

# Grab the HLS stream for the current video, and sets the stream property for VidStream
proc SetHLSStream*(this: Video): HLSStream {.nimcall.} =
    let streamingUri: string = "https:" & this.page.findAll("iframe")[0].attr("src")
    this.currPage = streamingUri
    this.page = parseHtml(this.ourClient.getContent(streamingUri))
    let pageScripts = this.page.findAll("script")
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
    for videocontent in this.page.findAll("body"):
      if(videocontent.attr("class").contains("container")):
        bodyKey = videocontent.attr("class").split('-')[1]
        break
    assert bodyKey != ""
    # VideoKey is used for decrypting returned data.
    var videoKey: string
    # Wrapper IV is used for decrypting DataKey
    var wrapperIV: string
    let wrapperIVsKeys = this.page.findAll("div")
    for videocontent in wrapperIVsKeys:
      if(videocontent.attr("class").contains("wrapper")):
        wrapperIV = videocontent.attr("class").split('-')[1]
        continue
      if(videocontent.attr("class").contains("videocontent")):
        videoKey = videocontent.attr("class").split('-')[1]
        break
    assert wrapperIV != ""
    assert videoKey != ""
    # Get the Url params
    var dctx: CBC[aes256]
    var idx: int = 0
    var dText: string = newString(len(dataKey))
    dctx.init(bodyKey, wrapperIV)
    dctx.decrypt(dataKey, dText)
    var bodyUri = dText.split('&') # param list
    assert bodyUri.len > 1
    var encID = bodyUri[0] # ID of the anime
    dctx.clear()
    # Setup encryption of the ID for the encrypt-ajax handler. (base64, key 128, blocksize 256)
    var ectx: CBC[aes256]
    var key = newString(aes256.sizeKey)
    var iv = newString(aes256.sizeBlock)
    var plainText = newString(aes256.sizeBlock)
    var encText = newString(aes256.sizeBlock * 2)
    # Calculate padding length PKSC7 padding.
    var padLen: int = aes128.sizeBlock - (len(encID) mod aes128.sizeBlock)
    var padding: byte = byte padLen
    copyMem(addr plainText[0], addr encID[0], len(encID))
    # Add the calculated padding.
    while idx < padLen:
      copyMem(addr plainText[len(encID) + idx], addr padding, 1)
      inc idx
    copyMem(addr key[0], addr bodyKey[0], len(bodyKey))
    copyMem(addr iv[0], addr wrapperIV[0], len(wrapperIV))
    ectx.init(key, iv)
    ectx.encrypt(plainText, encText)
    ectx.clear()
    # Probably shouldn't have made this of a set size, but it should be within this length.
    var nString: string = newString(22)
    var pText: seq[byte] = @(encText.toOpenArrayByte(0, encText.len - aes256.sizeBlock - 1))
    var str: string
    var uriArgs: string
    for strings in bodyUri[1..(len(bodyUri) - 2)]:
      uriArgs.add("&" & strings)
    # Create the final url to request from.
    let mainReqUri: string = "https://goload.pro/encrypt-ajax.php?id=" & encode(pText) & uriArgs & "&alias=" & encID
    this.ourClient.headers = newHttpHeaders({
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:101.0) Gecko/20100101 Firefox/101.0",
        "Referer": "https://gogoplay1.com/streaming.php",
        "x-requested-with": "XMLHttpRequest",
        "Accept": "*/*",
        "Accept-Encoding": "identity",
    })
    var page: XmlNode
    let data = this.ourClient.getContent(mainReqUri)
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
    let ima = decVideoData.split('"')
    let uri = ima[5]
    let parts: seq[string] = (this.ourClient.getContent(uri)).split('\n')
    this.hlsStream = ParseManifest(parts, uri[0 .. ^(uri.split('/')[^1].len + 1)])
    return this.hlsStream

proc GetMetaData(this: Video): MetaData {.nimcall.} =
  this.metaData = MetaData()
  if this.currPage != this.defaultPage:
    this.ourClient.headers = this.defaultHeaders
    this.page = parseHtml(this.ourClient.getContent(this.defaultPage))
    this.currPage = this.defaultPage
  var videoInfoLeft: XmlNode
  for divVideo in this.page.findAll("div"):
    if divVideo.attr("class") == "video-info-left":
      videoInfoLeft = divVideo
      break
  assert videoInfoLeft != nil
  # The title of the anime is the first <h1> tag within video-info-left
  for divClass in videoInfoLeft.items:
    if divClass.kind == xnElement:
      if this.metaData.name == "" and divClass.tag == "h1":
        this.metaData.name = sanitizeString(divClass.innerText)
      elif divClass.attr("class") == "video-details":
        this.metaData.series = sanitizeString(divClass.child("span").innerText)
        this.metaData.description = sanitizeString(divclass.child("div").child("div").innerText)
        break
  return this.metaData

proc GetEpisodeMetaDataObject(this: XmlNode): MetaData {.nimcall.} =
  var metaData: MetaData = MetaData()
  let node = this.child("a")
  metaData.uri = sanitizeString(node.attr("href"))
  # OM MY GOD, WHY
  for divider in node.items:
    if divider.kind != xnElement:
      continue
    case divider.attr("class"):
      of "img":
        metaData.coverUri = sanitizeString(divider.child("div").child("img").attr("src"))
        break
      of "name":
        metaData.name = sanitizeString(divider.innerText)
        break
      else:
        discard
  return metaData

proc GetEpisodeSequence(this: Video): seq[MetaData] {.nimcall.} =
  var mDataSeq: seq[MetaData] = @[]
  if this.currPage != this.defaultPage:
    this.page = parseHtml(this.ourClient.getContent(this.defaultPage))
    this.currPage = this.defaultPage
  for nodes in this.page.findAll("ul"):
    if nodes.attr("class") == "listing items list":
      for li in nodes.findAll("li"):
        mDataSeq.add(GetEpisodeMetaDataObject(li))
      break
  return mDataSeq

proc ListResolutions(this: Video): seq[MediaStreamTuple] {.nimcall.} =
  var hlsBase = this.hlsStream
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

proc DownloadNextVideoPart(this: Video, path: string): bool {.nimcall.} =
  this.ourClient.headers = newHttpHeaders({
      "User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:101.0) Gecko/20100101 Firefox/101.0",
      "Referer": "https://gogoplay1.com/streaming.php",
      "x-requested-with": "XMLHttpRequest",
      "Accept": "*/*",
      "Accept-Encoding": "identity",
  })
  if this.videoCurrIdx >= this.videoStream.len:
    return false
  var file: File
  if fileExists(path):
    file = open(path, fmAppend)
  else:
    file = open(path, fmWrite)
  let videoData = this.ourClient.getContent(this.videoStream[this.videoCurrIdx])
  write(file, videoData)
  inc this.videoCurrIdx
  close(file)
  return true

proc DownloadNextAudioPart(this: Video, path: string): bool {.nimcall.} =
  this.ourClient.headers = newHttpHeaders({
      "User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:101.0) Gecko/20100101 Firefox/101.0",
      "Referer": "https://gogoplay1.com/streaming.php",
      "x-requested-with": "XMLHttpRequest",
      "Accept": "*/*",
      "Accept-Encoding": "identity",
  })
  if this.audioCurrIdx >= this.audioStream.len:
    return false
  var file: File
  if fileExists(path):
    file = open(path, fmAppend)
  else:
    file = open(path, fmWrite)
  let audioData = this.ourClient.getContent(this.audioStream[this.audioCurrIdx])
  write(file, audioData)
  inc this.audioCurrIdx
  close(file)
  return true

proc Search*(this: Video, str: string): seq[MetaData] {.nimcall.} =
  this.ourClient.headers = newHttpHeaders({
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:101.0) Gecko/20100101 Firefox/101.0",
        "Referer": "https://gogoplay1.com/",
        "x-requested-with": "XMLHttpRequest",
        "Accept": "*/*",
        "Accept-Encoding": "identity",
  })
  let content = this.ourClient.getContent("https://gogoplay1.com/ajax-search.html?keyword=" & str & "&id=-1")
  let json = parseJson(content)
  var results: seq[MetaData] = @[]
  this.page = parseHtml(json["content"].getStr())
  this.currPage = "https://gogoplay1.com"
  for a in this.page.findAll("a"):
    var data = MetaData()
    data.name = a.innerText
    data.uri = "https://gogoplay1.com" & a.attr("href")
    results.add(data)
  return results

proc SelectResolutionFromTuple(this: Video, tul: MediaStreamTuple) {.nimcall.} =
  var vManifest = ParseManifest(splitLines(this.ourClient.getContent(tul.uri)), this.hlsStream.baseUri)
  var vSeq: seq[string] = @[]
  for part in vManifest.parts:
    if part.header == "URI":
      vSeq.add(part.values[0].value)
  this.videoStream = vSeq
  for stream in this.mediaStreams:
    if stream.id == tul.id:
      var aManifest = ParseManifest(splitLines(this.ourClient.getContent(stream.uri)), this.hlsStream.baseUri)
      var aSeq: seq[string] = @[]
      for part in aManifest.parts:
        aSeq.add(part.values[0].value)
      this.audioStream = aSeq
      break
proc getHomeCarousel(this: Video): seq[MetaData] {.nimcall.} =
  return @[]
# Initialize the client and add default headers.
proc Init*(uri: string): HeaderTuple {.nimcall.} =
    let defaultHeaders = newHttpHeaders({
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:101.0) Gecko/20100101 Firefox/101.0",
        "Referer": "https://gogoplay1.com",
        "Accept": "*/*",
        "Origin": "https://gogoplay1.com",
        "Accept-Encoding": "identity",
        "sec-fetch-site": "same-origin",
        "sec-fetch-mode": "no-cors"
    })
    return (headers: defaultHeaders,
    defaultPage: uri,
    getStream: SetHLSStream,
    getMetaData: GetMetaData,
    getEpisodeSequence: GetEpisodeSequence,
    getHomeCarousel: nil,
    searchDownloader: Search,
    selResolution: SelectResolutionFromTuple,
    listResolution: ListResolutions,
    downloadNextVideoPart: DownloadNextVideoPart,
    downloadNextAudioPart: DownloadNextAudioPart)
