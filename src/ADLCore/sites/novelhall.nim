import ../context
# Begin NovelHall
proc loadNovelHallSearch(this: var DownloaderContext) =
  let 
    content = this.httpGet("https://www.novelhall.com/index.php?s=so&module=book&keyword=" & this.name.replace(' ', '&'))
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
    recursiveNodeSearch(this.page, parseHtml("<div class=\"book-catalog inner mt20\">"))[7]
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
    if currentNode.kind != xnElement or currentNode.tag != "li":
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
    let page = parseHtml(this.httpGet(chapter.metadata.uri))
    chapter.contentSeq = getNovelHallChapterDataFromPage(page)
proc loadNovelHallChapter(this: var DownloaderContext) =
  var chapter = this.chapter
  let pageNode: XmlNode = parseHtml(this.httpGet(chapter.metadata.uri))
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

# Add self
downloaderList.add ("novelhall", "text", @[("metadata", loadNovelHallMetadata), ("parts", loadNovelHallChapters), ("search", loadNovelHallSearch), ("content", loadNovelHallChapter)])
siteList.add Site(identifier: "novelhall", baseUri: "www.novelhall.com", uriList: @["www.novelhall.com", "novelhall", "novelhall.com"])