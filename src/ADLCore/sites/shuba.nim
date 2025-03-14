import ../context
# Begin shuba
iterator shubaGetChapter(this: var DownloaderContext, l, h: int): Chapter =
  setPage(this, this.defaultPage.split(".htm")[0] & "/")
  let chapterList: XmlNode =
    recursiveNodeSearch(this.page, parseHtml("<div id=\"catalog\" class=\"catalog\">")).child("ul")
  var
    idx: int = 
      if h < 0: len(chapterList)
      else: h
    lower: int =
      if l < 0: 0
      else: l
    nodeTrack: int = 0
  while lower < idx and nodeTrack < len(chapterList):
    let cNode = chapterList[nodeTrack]
    inc nodeTrack
    if cNode.kind != xnElement or cNode.tag != "li":
      continue
    let oChild = cNode.child("a")
    yield Chapter(metadata: MetaData(name: oChild.innerText, uri: oChild.attr("href")))
    inc lower
proc loadShubaChapters(this: var DownloaderContext) =
  var vol: Volume = this.sections[this.index]
  for chp in shubaGetChapter(this, vol.lower, vol.upper):
    vol.parts.add chp
proc loadShubaChapterData(this: var DownloaderContext) =
  var 
    chapter = this.chapter
    nodes: seq[TiNode] = @[]
  this.setdfHd()
  var resp = this.ourClient.request(chapter.metadata.uri, httpMethod = HttpGet, headers = this.defaultHeaders)
  var chpPage: XmlNode = parseHtml(resp.body)
  while chpPage.kind != xnElement:
    echo "RETRY REQUEST + " & $chpPage
    sleep(15000)
    this.setdfHd()
    resp = this.ourClient.request(chapter.metadata.uri, httpMethod = HttpGet, headers = this.defaultHeaders)
  echo $chpPage
  let s1: XmlNode = recursiveNodeSearch(chpPage, parseHtml("<div class=\"container\">"))
  for it in s1.child("div")[5].child("ul")[3].items:
    if it.kind != xnElement: continue
    if it.tag != "p": continue
    nodes.add TiNode(text: it.innerText)
  var idx: int = nodes.len
  while idx > 0:
    dec idx
    chapter.contentSeq.add nodes[idx]
proc loadShubaMetadata(this: var DownloaderContext) =
  setPage(this, this.defaultPage)
  var meta: MetaData = MetaData()
  meta.uri = this.defaultPage
  let 
    mainInfo = recursiveNodeSearch(this.page, parseHtml("<div class=\"bookbox\">"))
    allInfo = recursiveNodeSearch(mainInfo, parseHtml("<div class=\"booknav2\">"))
  echo $allInfo
  meta.name = "50000"#allInfo.child("h1").child("a").innerText
  meta.author = allInfo.child("p").child("a").innerText
  meta.coverUri = "https://69shuba.cx" & mainInfo.child("div").child("img").attr("src")
  var vol = Volume(mdat: meta, lower: -1, upper: -1)
  this.sections.add vol

downloaderList.add ("shuba", "text", @[("metadata", loadShubaMetadata), ("parts", loadShubaChapters), ("search", nil), ("content", loadShubaChapterData)])
siteList.add Site(identifier: "shuba", baseUri: "69shuba.cx", uriList: @["69shuba.cx", "shuba", "yuedu", "69yuedu.net"])