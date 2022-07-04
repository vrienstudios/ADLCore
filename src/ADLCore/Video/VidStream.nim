import HLSManager
import ../genericMediaTypes
import std/[asyncdispatch, httpclient, htmlparser, xmltree, strutils, strtabs, parseutils, sequtils, base64]
import nimcrypto

# Please follow this layout for any additional sites.
type VidStream* = ref object of RootObj
    ourClient: AsyncHttpClient
    page: XmlNode
    defaultHeaders: HttpHeaders
    defaultPage: string
    currPage: string

# Initialize the client and add default headers.
method Init*(this: VidStream, uri: string) {.async.} =
    this.ourClient = newAsyncHttpClient()
    this.defaultHeaders = newHttpHeaders({
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:101.0) Gecko/20100101 Firefox/101.0",
        "Referer": "https://gogoplay1.com",
        "Accept": "*/*",
        "Origin": "https://gogoplay1.com",
        "Accept-Encoding": "identity",
        "sec-fetch-site": "same-origin",
        "sec-fetch-mode": "no-cors"
    })
    this.ourClient.headers = this.defaultHeaders
    this.defaultPage = uri
    this.currPage = uri
    this.page = parseHtml(await this.ourClient.getContent(uri))

method SetHLSStream*(this: VidStream) {.async.}=
    let streamingUri: string = "https:" & this.page.findAll("iframe")[0].attr("src")
    this.currPage = streamingUri
    this.page = parseHtml(await this.ourClient.getContent(streamingUri))
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
    # VideoIV is used for decrypting returned data.
    var videoIV: string
    # Wrapper IV is used for decrypting DataKey
    var wrapperIV: string
    let wrapperIVsKeys = this.page.findAll("div")
    for videocontent in wrapperIVsKeys:
      if(videocontent.attr("class").contains("wrapper")):
        wrapperIV = videocontent.attr("class").split('-')[1]
        continue
      if(videocontent.attr("class").contains("videocontent")):
        videoIV = videocontent.attr("class").split('-')[1]
        break
    assert wrapperIV != ""
    assert videoIV != ""
    var dctx: CBC[aes256]
    var idx: int = 0
    var dText: string = newString(len(dataKey))
    dctx.init(bodyKey, wrapperIV)
    dctx.decrypt(dataKey, dText)
    var bodyUri = dText.split('&')
    assert bodyUri.len > 1
    var mID = bodyUri[0]
    var encID = bodyUri[0]
    dctx.clear()
    var str: string
    var uriArgs: string
    for strings in bodyUri[1..(len(bodyUri) - 2)]:
      uriArgs.add("&" & strings)
    ##encrypt = "rocQ6Au42n5Jwk6wHGeuig=="
    let mainReqUri: string = "https://goload.pro/encrypt-ajax.php?id=" & "rocQ6Au42n5Jwk6wHGeuigRPBWYV8gBNdJZYVnz1dwo=" & uriArgs & "&alias=" & mID
    this.ourClient.headers = newHttpHeaders({
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:101.0) Gecko/20100101 Firefox/101.0",
        "Referer": "https://gogoplay1.com/streaming.php",
        "x-requested-with": "XMLHttpRequest",
        "Accept": "*/*",
        "Accept-Encoding": "identity",
    })
    var page: XmlNode
    echo mainReqUri
    echo await this.ourClient.getContent(mainReqUri)