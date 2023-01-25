import ../DownloadManager
import ../genericMediaTypes
import EPUB/[types, genericHelpers]
import std/[httpclient, htmlparser, xmltree, strutils, strtabs, parseutils, sequtils, enumutils, json]

# Please follow this layout for any additional sites.

proc GetNodes*(this: Novel, chapter: Chapter): seq[TiNode] =
  var nodes: seq[TiNode]
  var images: seq[Image]
  var host: string = chapter.uri.split("/")[2]
  this.ourClient.headers = newHttpHeaders({
    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:101.0) Gecko/20100101 Firefox/101.0",
    "Referer": this.defaultPage,
    "Host": host,
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,application/json,*/*;q=0.8"
  })
  this.page = parseHtml(this.ourClient.getContent(chapter.uri))
  for img in this.page.findAll("img"):
    if img.kind != xnElement: continue
    if img.attr("title").endsWith("Mangakakalot.com") or img.attr("title").endsWith("MangaNato.com"):
      this.ourClient.headers = newHttpHeaders({
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:101.0) Gecko/20100101 Firefox/101.0",
        "Referer": this.defaultPage,
        "Host": img.attr("src").split("/")[2],
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,application/json,*/*;q=0.8"
      })
      var epubImg: Image = Image(bytes: this.ourClient.getContent(img.attr("src")), name: SanitizePageProp(chapter.name.split(" ").join("_") & "_" & img.attr("src").split("/")[^1]))
      images.add(epubImg)
  
  this.ourClient.headers = newHttpHeaders({
    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:101.0) Gecko/20100101 Firefox/101.0",
    "Host": this.metaData.coverUri.split("/")[2],
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,application/json,*/*;q=0.8"
  })
  nodes.add(TiNode(images: images))
  return nodes

type MangaKakalotStatus = enum Active = "Ongoing", Hiatus = "Hiatus", Dropped = "Dropped", Completed = "Completed"

proc GetMetaData*(this: Novel): MetaData =
  var cMetaData: MetaData = MetaData()
  if this.currPage != this.defaultPage:
    this.ourClient.headers = this.defaultHeaders
    this.page = parseHtml(this.ourClient.getContent(this.defaultPage))
    this.currPage = this.defaultPage
  if this.defaultPage.split("/")[2] == "mangakakalot.com":
    var mangaInfoText = this.page.findAll("ul")[1]
    cMetaData.name = mangaInfoText[1][1].innerText
    var author = mangaInfoText[3].innerText
    author.removePrefix("Author(s) :\n")
    author.removeSuffix(", ")
    cMetaData.author = author
    cMetaData.uri = this.defaultPage
    cMetaData.description = join(splitLines(this.page.findAll("div")[57].innerText)[2..^1], "\n") # I will most certainly regret this line
    var genre = mangaInfoText[13].innerText
    genre.removePrefix("Genres :\n")
    genre.removeSuffix(", ")
    cMetaData.genre = split(genre, ", ")
    var schemaJson = parseJson(this.page.findAll("script")[9].innerText)
    cMetaData.coverUri = schemaJson["itemReviewed"]["image"].getStr()
    cMetaData.rating = schemaJson["ratingValue"].getStr()
    var status = mangaInfoText[5].innerText
    status.removePrefix("Status : ")
    cMetaData.statusType = parseEnum[Status](parseEnum[MangaKakalotStatus](status).symbolName)
    return cMetaData
  
  var tds = this.page.findAll("td")
  cMetaData.name = this.page.findAll("h1")[0].innerText
  var author = tds[3].innerText
  author.removePrefix("\n")
  author.removeSuffix(", ")
  author.removeSuffix(" ")
  cMetaData.author = author
  cMetaData.uri = this.defaultPage
  var description: string
  for el in this.page.findAll("div"):
    if el.kind != xnElement: continue
    if el.attr("id") == "panel-story-info-description":
      description = el.innerText
  description.removePrefix("\nDescription :\n")
  cMetaData.description = description
  var status = tds[5].innerText
  cMetaData.statusType = parseEnum[Status](parseEnum[MangaKakalotStatus](status).symbolName)
  var genres = tds[7].innerText
  genres.removePrefix("\n")
  genres.removeSuffix("\n")
  cMetaData.genre = split(genres, " - ")
  
  for span in this.page.findAll("span"):
    if span.kind != xnElement: continue
    if span.attr("class") == "info-image":
      cMetaData.coverUri = span[1].attr("src")
  
  for em in this.page.findAll("em"):
    if em.kind != xnElement: continue
    if em.attr("property") == "v:average":
      cMetaData.rating = em.innerText
  return cMetaData


proc GetChapterSequence*(this: Novel): seq[Chapter] {.nimcall.} =
    var chapters: seq[Chapter]
    if this.currPage != this.defaultPage:
      this.ourClient.headers = this.defaultHeaders
      this.page = parseHtml(this.ourClient.getContent(this.defaultPage))
      this.currPage = this.defaultPage
    if this.defaultPage.split("/")[2] == "mangakakalot.com":
      var divs: seq[XmlNode] = this.page.findAll("div")
      var i = divs.len - 1
      while i > 0:
        var el = divs[i]
        if el.kind != xnElement: continue
        if el.attr("class") == "row":
          let chapterA = el[1][0]
          chapters.add(Chapter(name: chapterA.innerText, uri: chapterA.attr("href")))
        dec i
      return chapters
    var a: seq[XmlNode] = this.page.findAll("a")
    var i = a.len - 1
    while i > 0:
      var el = a[i]
      if el.kind != xnElement: continue
      if el.attr("class") == "chapter-name text-nowrap":
        chapters.add(Chapter(name: el.innerText, uri: el.attr("href")))
      dec i
    return chapters

proc GetHomePage*(this: Novel): seq[MetaData] =
  var novels: seq[MetaData] = @[]
  return novels

# Returns basic novel objects without MetaData.
proc Search*(this: Novel, term: string): seq[MetaData] =
  var metaDataSeq: seq[MetaData] = @[]
  var data = newMultipartData()
  data["searchword"] = term
  let content = this.ourClient.postContent("https://mangakakalot.com/home_json_search", multipart=data)
  var json = parseJson(content)
  this.currPage = "https://mangakakalot.com"
  
  for obj in json:
    var data = MetaData()
    data.name = parseHtml(obj["name"].getStr()).innerText
    data.uri = obj["story_link"].getStr()
    metaDataSeq.add(data)
  return metaDataSeq

# Initialize the client and add default headers.
proc Init*(uri: string): HeaderTuple =
    var host: string
    if uri != "": host = uri.split("/")[2]
    else: host = "mangakakalot.com"
    let defaultHeaders = newHttpHeaders({
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:101.0) Gecko/20100101 Firefox/101.0",
        "Referer": "https://mangakakalot.com/",
        "Host": host,
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,application/json,*/*;q=0.8"
    })
  #return (headers: defaultHeaders, defaultPage: uri, getNodes: GetNodes, getMetaData: GetMetaData,
  #getChapterSequence: GetChapterSequence, getHomeCarousel: GetHomePage, searchDownloader: Search)

    return (
      downloadNextAudioPart: nil,
      downloadNextVideoPart: nil,
      getChapterSequence: GetChapterSequence,
      getEpisodeSequence: nil,
      getNovelHomeCarousel: getHomeCarousel,
      getVideoHomeCarousel: nil,
      getNovelMetaData: GetMetaData,
      getVideoMetaData: nil,
      getNodes: GetNodes,
      getStream: nil,
      listResolution: nil,
      searchNovelDownloader: Search,
      searchVideoDownloader: nil,
      selResolution: nil,
      headers: defaultHeaders,
      defaultPage: uri
    )