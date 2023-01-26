import ../DownloadManager
import ../genericMediaTypes
import EPUB/types
import std/[httpclient, htmlparser, xmltree, strutils, strtabs, parseutils, sequtils]

# Please follow this layout for any additional sites.

proc GetNodes(this: Novel, chapter: Chapter): seq[TiNode] {.nimcall.} =
    let ret: string = this.ourClient.getContent(chapter.uri)
    this.currPage = chapter.uri
    this.page = parseHtml(ret)
    var sequence: seq[XmlNode]
    var f: seq[TiNode]
    this.page.findall("div", sequence)
    for n in sequence:
      if n.attr("class") == "entry-content":
        var tinode: TiNode = TiNode(text: "")
        for a in n.items:
          if a.kind == xnText:
            tinode.text.add a.innerText
          elif a.kind == xnElement:
            f.add tinode
            tinode = TiNode(text: "")
        break
    return f

proc GetMetaData*(this: Novel): MetaData {.nimcall.} =
  var cMetaData: MetaData = MetaData()
  if this.currPage != this.defaultPage:
    this.page = parseHtml(this.ourClient.getContent(this.defaultPage))
    this.currPage = this.defaultPage
  for element in this.page.findall("div"):
    if(element.attr("class") == "book-main inner mt30"):
      for bookEl in element.items:
        if bookEl.kind != xnElement:
          continue
        if bookEl.attr("class") == "book-img hidden-xs":
          cMetaData.coverUri = bookEl.child("img").attr("src")
        elif bookEl.attr("class") == "book-info":
          cMetaData.name = sanitizeString(bookEl.child("h1").innerText)
          for bookInfoEl in bookEl.items:
            if bookInfoEl.kind != xnElement:
              continue
            case bookInfoEl.attr("class")
            of "total booktag":
              for bookTagEl in bookInfoEl.items:
                if bookTagEl.kind != xnElement:
                  continue
                if bookTagEl.attr("class") == "red":
                  cMetaData.genre.add(bookTagEl.innerText)
                elif bookTagEl.attr("class") == "blue":
                  if bookTagEl.innerText.contains("Author"):
                    let mString = bookTagEl.innerText.split('\n')[0]
                    # NIM hack, since it doesn't play well with full-width semicolon literal.
                    var i: int = skipUntil(bookTagEl.innerText, "："[0]) + 3
                    cMetaData.author = newString(len(mString) + 3)
                    while i < len(mString) - 1:
                      cMetaData.author[i] = mString[i]
                      inc i
                    cMetaData.author = sanitizeString(cMetaData.author)
                  elif bookTagEl.innerText.contains("Status"):
                    let mString = bookTagEl.innerText
                    # NIM hack, since it doesn't play well with full-width semicolon literal.
                    var i: int = skipUntil(bookTagEl.innerText, "："[0]) + 3
                    var d: int = 0
                    var k = ""
                    while i < len(mString):
                      k.add(mString[i])
                      inc i
                      inc d
                    cMetaData.statusType = parseEnum[Status](sanitizeString(k))
            of "intro":
              let seqNodes: seq[XmlNode] = bookInfoEl.items.toSeq()
              let interest = seqNodes[len(seqNodes) - 1]
              cMetaData.description = sanitizeString(interest.items.toSeq()[0].innerText)
              return cMetaData
              # No need to continue iteration after getting final element.
            else:
              continue
  return cMetaData


proc GetChapterSequence*(this: Novel): seq[Chapter] {.nimcall.} =
    if this.currPage != this.defaultPage:
      this.page = parseHtml(this.ourClient.getContent(this.defaultPage))
      this.currPage = this.defaultPage
    var sequence: seq[XmlNode]
    this.page.findall("div", sequence)
    var chapters: seq[Chapter]
    for n in sequence:
        if n.attr("class") == "book-catalog inner mt20":
            for items in n.items:
                if items.kind == xnElement:
                    if items.tag == "ul":
                        #items.child("ul").items
                        for textEl in items.findall("ul")[1].items:
                            if textEl.kind == xnElement and textEl.tag == "li":
                                #FINALLY
                                let child: XmlNode = textEl.child("a")
                                chapters.add(Chapter(name: sanitizeString(child.innerText), uri: "https://www.novelhall.com" & child.attr("href")))
                        return chapters

proc ParseCarouselNodeToNovel(node: XmlNode): MetaData {.nimcall.} =
  var meta: MetaData = MetaData()
  for nodes in node.items:
    if nodes.kind == xnElement and nodes.attr("class") == "book-img":
      let b = nodes.child("a")
      meta.uri = "https://novelhall.com" & b.attr("href")
      let img = b.child("img")
      meta.coverUri = b.attr("src")
      meta.name = b.attr("alt")
    elif nodes.kind == xnElement and nodes.attr("class") == "book-info":
      let metaInfo = nodes.child("div")
      meta.author = metaInfo.child("span").innerText
      meta.description = nodes.child("p").innerText
      return meta
    else:
      continue
  return meta

proc GetHomePage*(this: Novel): seq[MetaData] {.nimcall.} =
  var novels: seq[MetaData] = @[]
  if this.currPage != "https://www.novelhall.com":
    let content = this.ourClient.getContent("https://www.novelhall.com")
    this.page = parseHtml(content)
    this.currPage = "https://www.novelhall.com"
  var homeSel: XmlNode
  for n in this.page.findall("div"):
    if n.kind == xnElement and n.attr("class") == "section1 inner mt30":
      homeSel = n.child("ul")
      break
  for n in homeSel.items:
    if n.kind == xnElement and n.tag == "li":
      novels.add(ParseCarouselNodeToNovel(n))
  return novels

# Returns basic novel objects without MetaData.
proc Search*(this: Novel, term: string): seq[MetaData] {.nimcall.} =
  var metaDataSeq: seq[MetaData] = @[]
  let content = this.ourClient.getContent("https://www.novelhall.com/index.php?s=so&module=book&keyword=" & term.replace(' ', '&'))
  this.page = parseHtml(content)
  this.currPage = "https://www.novelhall.com/index.php"
  var container: XmlNode
  for nodes in this.page.findAll("section"):
    if nodes.attr("id") == "main":
      container = nodes.findAll("div")[1]
      break
  assert container != nil
  container = container.child("table")
  container = container.child("tbody")
  assert container != nil
  for node in container.findAll("tr"):
    let tD = node.findAll("td").toSeq()
    var data = MetaData()
    data.genre = @[td[0].child("a").innerText]
    let uriBN = td[1].child("a")
    data.name = uriBN.innerText
    data.uri = "https://www.novelhall.com" & uriBN.attr("href")
    metaDataSeq.add(data)
  return metaDataSeq

# Initialize the client and add default headers.
proc Init*(uri: string): HeaderTuple =
    let defaultHeaders = newHttpHeaders({
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:101.0) Gecko/20100101 Firefox/101.0",
        "Referer": "https://www.novelhall.com",
        "Host": "www.novelhall.com",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8"
    })
    return (
      downloadNextAudioPart: nil,
      downloadNextVideoPart: nil,
      getChapterSequence: NovelHall.GetChapterSequence,
      getEpisodeSequence: nil,
      getNovelHomeCarousel: NovelHall.GetHomePage,
      getVideoHomeCarousel: nil,
      getNovelMetaData: NovelHall.GetMetaData,
      getVideoMetaData: nil,
      getNodes: NovelHall.GetNodes,
      getStream: nil,
      listResolution: nil,
      searchNovelDownloader: NovelHall.Search,
      searchVideoDownloader: nil,
      selResolution: nil,
      headers: defaultHeaders,
      defaultPage: uri
    )