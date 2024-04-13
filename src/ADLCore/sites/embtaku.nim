import ../context
# Begin Embtaku
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
  var 
    videoKey: string
    wrapperIV: string
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
  var 
    pText: seq[byte] = @(encText.toOpenArrayByte(0, encText.len - aes256.sizeBlock - 1))
    uriArgs: string
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
  var 
    json = parseJSon(data)
    jData = json["data"].getStr().decode()
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

# Add self
downloaderList.add ("embtaku", "video", @[("metadata", loadEmbtakuMetadata), ("parts", loadEmbtakuChapters), ("search", loadEmbtakuSearch), ("prepare", loadEmbtakuHLS), ("content", loadEmbtakuChapterData)])
siteList.add Site(identifier: "embtaku", baseUri: "embtaku.pro", uriList: @["embtaku.pro", "embtaku"])