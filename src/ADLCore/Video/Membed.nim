import HLSManager
import ../genericMediaTypes
import std/[os, asyncdispatch, httpclient, htmlparser, xmltree, strutils, strtabs, parseutils, sequtils, base64, json]
import nimcrypto
import std/json
import VideoType
# Please follow this layout for any additional sites.

# Grab the HLS stream for the current video, and sets the stream property for VidStream
proc SetHLSStream*(this: Video): HLSStream {.nimcall.} =
    let activePage: string = this.currPage
    let streamingUri: string = "https:" & this.page.findAll("iframe")[0].attr("src")
    this.currPage = streamingUri
    this.page = parseHtml(this.ourClient.getContent(streamingUri))
    let pageScripts = this.page.findAll("script")
    #  _0x425b80 = $(_0x4926d4(0xdd))[_0x4926d4(0xe6)](_0x4926d4(0xf3)), % getting data value from crypto element in header.
    #  _0x165ec2 = CryptoJS['AES'][_0x4926d4(0xd1)](_0x425b80, CryptoJS[_0x4926d4(0xda)][_0x4926d4(0xde)][_0x4926d4(0xe1)](_0x4405f4), {
    #      'iv': CryptoJS[_0x4926d4(0xda)]['Utf8']['parse'](_0x48af28)
    #  }),
    #      % decrypts crypto data value with iv "922567 + 90839 + 61858" pass: 25742532592 + 1384967446658 + 79883281
    # Fucking hell, is this tiresome.
    var dataKey: string
    for script in pageScripts:
      if script.attr("data-name") == "crypto":
        dataKey = script.attr("data-value").decode()
        break
    let aIV = "9225679083961858"
    let aKey = "25742532592138496744665879883281"

    var dctx: CBC[aes256]
    var dText: string = newString(len(dataKey))
    dctx.init(aKey, aIV)
    dctx.decrypt(dataKey, dText)
    dctx.clear()
    # Confirmed working, 11/29/22
    # Grabs a portion of the url we need.
    #_0x58d62f = CryptoJS[_0x4926d4(0xda)][_0x4926d4(0xde)][_0x4926d4(0xf4)](_0x165ec2), % "Stringifies" decrypted url
    #_0x525c8e = _0x58d62f[_0x4926d4(0xeb)](0x0, _0x58d62f['indexOf']('&')); % 0 -> '&'
    let andOdText: int = dText.find('&')
    var substr = dText[0..andOdText - 1]
    #$[_0x4926d4(0xc3)](_0x4926d4(0xc4) + CryptoJS[_0x4926d4(0xcf)][_0x4926d4(0xe4)](_0x525c8e, CryptoJS[_0x4926d4(0xda)][_0x4926d4(0xde)][_0x4926d4(0xe1)](_0x4405f4), {
    #'iv': CryptoJS['enc']['Utf8'][_0x4926d4(0xe1)](_0x48af28)
    # Gets Json from /encrypt-ajax.php?id= {encrypted substr}
    # Text = dText
    # Key = _0x4405f4
    #   _0x43376d + _0x5c718f + _0x344515
    #   25742532592 + 1384967446658 + 79883281 (aKey)
    # Iv = _0x48af28 or (aIV)
    var ectx: CBC[aes256]
    let paddingLength = aes128.sizeBlock - (len(substr) mod aes128.sizeBlock)
    var paddingType: byte = byte paddingLength
    var eng = newString(substr.len + paddingLength)
    copyMem(addr eng[0], addr substr[0], len(substr))
    var idx: int = 0
    while idx < paddingLength:
      copyMem(addr eng[len(substr) + idx], addr paddingType, 1)
      inc idx
    var aID: string = newString(len(eng))
    ectx.init(aKey, aIV)
    ectx.encrypt(eng, aID)
    ectx.clear()
    # + _0x58d62f[_0x4926d4(0xeb)](_0x58d62f[_0x4926d4(0xef)]('&')) + _0x4926d4(0xd4) + _0x525c8e, function(_0x38e390) {
    # + dText.substr('&') + &alias= + substr, (function for decrypting returned content?)
    var builtData: string =
      ("https://membed.net" & "/encrypt-ajax.php?id=" & aID.encode & dText[andOdText..^1] & "&refer=" & activePage & "&alias=" & substr.split('/')[0]).replace("\r", "").replace("\n", "")
    this.ourClient.headers = newHttpHeaders({
      "User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:101.0) Gecko/20100101 Firefox/101.0",
      "Referer": "https://membed.net/streaming.php",
      "x-requested-with": "XMLHttpRequest",
      "Accept": "*/*",
      "Accept-Encoding": "identity",
    })
    echo builtData
    let encJson = parseJson(this.ourClient.getContent(builtData))["data"].getStr().decode()
    #0x549f1f = JSON['parse'](CryptoJS[_0x52c834(0xda)][_0x52c834(0xde)][_0x52c834(0xf4)](CryptoJS['AES'][_0x52c834(0xd1)](_0x38e390[_0x52c834(0xe6)], CryptoJS[_0x52c834(0xda)][_0x52c834(0xde)]['parse'](_0x4405f4), {
    #    'iv': CryptoJS[_0x52c834(0xda)][_0x52c834(0xde)]['parse'](_0x48af28)
    #}))); Decrypts the json and parses it to 0x549f1f, same key/iv as others.
    dctx.init(aKey, aIV)
    var decJson: string = newString(encJson.len)
    dctx.decrypt(encJson, decJson)
    dctx.clear()
    # Encrption over.
    # Please note, there was a problem parsing this json in Vidstream, so I am assuming the problem exists here too.
    # Also, remove all the random '\' characters.
    decJson = decJson.replace("\\")
    let url = decJson.split('"')[5]
    let parts: seq[string] = this.ourClient.getContent(url).split('\n')
    this.hlsStream = ParseManifest(parts, url[0..^(url.split('/')[^1].len + 1)])
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
  metaData.uri = "https://gogoplay1.com" & node.attr("href")
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
  for nodes in this.page.findAll("div"):
    if nodes.attr("class") == "video-info-left":
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
      "Referer": "https://membed.net/streaming.php",
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
  var aLock: bool = true
  var counter: int = 0
  var videoData: string = ""
  while aLock and counter < 10:
    try:
      videoData = this.ourClient.getContent(this.videoStream[this.videoCurrIdx])
      aLock = false
    except:
      inc counter
      echo "Failed Download, Retrying $1/$2" % [$counter, "10"]
  write(file, videoData)
  inc this.videoCurrIdx
  close(file)
  return true

proc DownloadNextAudioPart(this: Video, path: string): bool {.nimcall.} =
  this.ourClient.headers = newHttpHeaders({
      "User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:101.0) Gecko/20100101 Firefox/101.0",
      "Referer": "https://membed.net/streaming.php",
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
        "Referer": "https://membed.net/",
        "x-requested-with": "XMLHttpRequest",
        "Accept": "*/*",
        "Accept-Encoding": "identity",
  })
  let content = this.ourClient.getContent("https://membed.net/search.html?keyword=" & str)
  let json = parseJson(content)
  var results: seq[MetaData] = @[]
  this.page = parseHtml(json["content"].getStr())
  this.currPage = "https://membed.net"
  for a in this.page.findAll("a"):
    var data = MetaData()
    data.name = a.innerText
    data.uri = "https://membed.net" & a.attr("href")
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
        "Referer": "https://membed.net",
        "Accept": "*/*",
        "Origin": "https://membed.net",
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
