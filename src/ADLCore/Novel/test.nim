import ./NovelTypes
import ../genericMediaTypes
import EPUB/Types/genericTypes
import std/[asyncdispatch, httpclient, htmlparser, xmltree, strutils, strtabs, parseutils, sequtils]

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
        for a in n.items:
          if a.kind == xnText:
            f.add(TiNode(text: a.innerText))
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
                    var i: int = skipUntil(bookTagEl.innerText, "???"[0]) + 3
                    cMetaData.author = newString(len(mString) + 3)
                    while i < len(mString) - 1:
                      cMetaData.author[i] = mString[i]
                      inc i
                  elif bookTagEl.innerText.contains("Status"):
                    let mString = bookTagEl.innerText
                    # NIM hack, since it doesn't play well with full-width semicolon literal.
                    var i: int = skipUntil(bookTagEl.innerText, "???"[0]) + 3
                    var d: int = 0
                    var k = newString(6)
                    while i < len(mString):
                      k[d] = mString[i]
                      inc i
                      inc d
                    echo k
                    cMetaData.statusType = parseEnum[Status](k)
            of "intro":
              let seqNodes: seq[XmlNode] = bookInfoEl.items.toSeq()
              let interest = seqNodes[len(seqNodes) - 1]
              cMetaData.description = interest.items.toSeq()[0].innerText
              return cMetaData
              # No need to continue iteration after getting final element.
            else:
              continue
  return cMetaData

proc GetHomePage*(this: Novel): seq[Novel] {.nimcall.} =
  var novels: seq[Novel]
  return novels

proc GetChapterSequence*(this: Novel): seq[Chapter] {.nimcall.} =
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
                                chapters.add(Chapter(name: child.innerText, uri: "https://www.novelhall.com" & child.attr("href")))
                        return chapters

# Initialize the client and add default headers.
proc Init*(uri: string): HeaderTuple {.nimcall.} =
    let defaultHeaders = newHttpHeaders({
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:101.0) Gecko/20100101 Firefox/101.0",
        "Referer": "https://www.novelhall.com",
        "Host": "www.novelhall.com",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8"
    })
    return (headers: defaultHeaders, defaultPage: uri, getNodes: GetNodes, getMetaData: GetMetaData, getChapterSequence: GetChapterSequence, getHomeCarousel: GetHomePage, searchDownloader: nil)