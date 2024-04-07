import ../context
# Begin HAnime
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
proc getMetaDataFromNUXT(page: XmlNode): tuple[jDat: JsonNode, meta: MetaData] =
  var 
    meta: MetaData = MetaData()
    jsonData: string
  for script in page.findAll("script"):
    if script.innerText.contains("__NUXT__"):
      jsonData = script.innerText[16..^2]
      break
  var videoData = parseJson(jsonData)["state"]["data"]["video"]
  let jObj = videoData["hentai_video"]
  meta.name = jObj["name"].getStr()
  meta.series = videoData["hentai_franchise"]["title"].getStr()
  meta.description = parseHtml(jObj["description"].getStr()).innerText
  meta.author = jObj["brand"].getStr()
  meta.coverUri = jObj["cover_url"].getStr()
  meta.uri = "https://hanime.tv/videos/hentai" & jObj["slug"].getStr()
  return (videoData, meta)
proc loadHAnimeMetadata(ctx: var DownloaderContext) =
  setPage(ctx, ctx.defaultPage)
  var
    nuxt = getMetaDataFromNUXT(ctx.page)
  var vol = Volume(mdat: nuxt.meta, lower: -1, upper: -1, jDat: nuxt.jDat)
  if ctx.globalKey == "":
    ctx.globalKey = ctx.ourClient.getContent("https://hanime.tv/sign.bin")
  ctx.sections.add vol
proc loadHAnimeChapters(ctx: var DownloaderContext) =
  # hentai_franchise_hentai_videos
  let 
    seriesData = ctx.section.jDat["hentai_franchise_hentai_videos"].getElems()
  for episode in seriesData:
    let 
      uri = "https://hanime.tv/videos/hentai/" & episode["slug"].getStr()
      page = parseHtml(ctx.ourClient.getContent(uri))
    var nuxt = getMetaDataFromNUXT(page)
    ctx.section.parts.add Chapter(metadata: nuxt.meta, key: ctx.globalKey, jDat: nuxt.jDat)
proc loadHAnimeRes*(ctx: var Downloadercontext) =
  var 
    streams: seq[MediaStreamTuple] = @[]
    chapter = ctx.chapter
  let servers = chapter.jDat["videos_manifest"]["servers"]
  for res in servers.getElems()[0]["streams"].getElems():
    if res["url"].getStr() == "":
      continue
    streams.add (id: $res["id"].getInt(),
      resolution: $res["width"].getInt() & "x" & res["height"].getStr(),
      uri: res["url"].getStr(), language: "english",
      isAudio: false, bandWidth: "unknown")
  chapter.mainStream.subStreams = streams
proc loadHAnimeContent*(ctx: var DownloaderContext) =
  var 
    chp = ctx.chapter
    encryptedContent: string = ctx.ourClient.getContent(chp.selStream[chp.streamIndex])
    outContent = newString(len(encryptedContent))
    cIdx = $(chp.streamIndex + 1)
    iv: string = newString(aes128.sizeBlock)
    dContext: CBC[aes128]
  assert chp.selStream.len != 0
  copyMem(addr iv[0], addr cIdx[0], len(cIdx))
  dContext.init(ctx.globalKey, iv)
  dContext.decrypt(encryptedContent, outContent)
  dContext.clear()
  chp.contentSeq.add TiNode(text: outContent)
  inc chp.streamIndex

# Add self
downloaderList.add ("hanime", "video", @[("metadata", loadHAnimeMetadata), ("parts", loadHAnimeChapters), ("search", loadHAnimeSearch), ("prepare", loadHAnimeRes), ("content", loadHAnimeContent)])
siteList.add Site(identifier: "hanime", baseUri: "hanime.tv", uriList: @["hanime", "hanime.tv"])