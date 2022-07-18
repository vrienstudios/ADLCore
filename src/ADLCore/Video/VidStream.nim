import HLSManager
import ../genericMediaTypes
import std/[asyncdispatch, httpclient, htmlparser, xmltree, strutils, strtabs, parseutils, sequtils, base64]
import nimcrypto
import std/json
import VideoType
# Please follow this layout for any additional sites.

# Grab the HLS stream for the current video, and sets the stream property for VidStream
proc SetHLSStream*(this: Video): bool {.nimcall.} =
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
    var dctx: CBC[aes256]
    var idx: int = 0
    var dText: string = newString(len(dataKey))
    dctx.init(bodyKey, wrapperIV)
    dctx.decrypt(dataKey, dText)
    var bodyUri = dText.split('&')
    assert bodyUri.len > 1
    var encID = bodyUri[0]
    dctx.clear()
    var ectx: CBC[aes256]
    var key = newString(aes256.sizeKey)
    var iv = newString(aes256.sizeBlock)
    var plainText = newString(aes256.sizeBlock)
    var encText = newString(aes256.sizeBlock * 2)

    var padLen: int = aes128.sizeBlock - (len(encID) mod aes128.sizeBlock)
    var padding: byte = byte padLen
    copyMem(addr plainText[0], addr encID[0], len(encID))
    while idx < padLen:
      copyMem(addr plainText[len(encID) + idx], addr padding, 1)
      inc idx
    copyMem(addr key[0], addr bodyKey[0], len(bodyKey))
    copyMem(addr iv[0], addr wrapperIV[0], len(wrapperIV))
    ectx.init(key, iv)
    ectx.encrypt(plainText, encText)
    ectx.clear()
    var nString: string = newString(22)
    var pText: seq[byte] = @(encText.toOpenArrayByte(0, encText.len - aes256.sizeBlock - 1))
    var str: string
    var uriArgs: string
    for strings in bodyUri[1..(len(bodyUri) - 2)]:
      uriArgs.add("&" & strings)
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
    dctx.init(videoKey, wrapperIV)
    var decVideoData: string = newString(len(jData))
    dctx.decrypt(jData, decVideoData)
    dctx.clear()
    decVideoData = decVideoData.replace("\\")
    # Error in nims json parsing, which results in {expected EOF at EOF}
    let ima = decVideoData.split('"')
    let uri = ima[5]
    let parts: seq[string] = (this.ourClient.getContent(uri)).split('\n')
    this.hlsStream = ParseManifest(parts)
    return true

proc GetMetaData(this: Video): MetaData {.nimcall.} =
  return nil

# Initialize the client and add default headers.
proc Init*(this: Video, uri: string): HeaderTuple {.nimcall.} =
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
    getStream: nil,
    setStream: SetHLSStream,
    getMetaData: GetMetaData,
    getEpisodeSequence: nil,
    getHomeCarousel: nil,
    searchDownloader: nil,)