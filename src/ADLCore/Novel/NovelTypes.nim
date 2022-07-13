import EPUB/Types/genericTypes
import ../genericMediaTypes
import std/[asyncdispatch, httpclient, xmltree, tables]

type
  HeaderTuple* = tuple[headers: HttpHeaders, defaultPage: string, getNodes: proc(this: Novel, chapter: Chapter): seq[TiNode] {.nimcall.},
    getMetaData: proc(this: Novel): MetaData {.nimcall.}, getChapterSequence: proc(this: Novel): seq[Chapter] {.nimcall.}]
  Chapter* = ref object of RootObj
      name*: string
      number*: int
      uri*: string
      contentSeq*: seq[TiNode]
  Novel* = ref object of RootObj
      metaData*: MetaData
      lastModified*: string

      chapters*: seq[Chapter]
      currChapter*: int

      ourClient*: HttpClient
      page*: XmlNode
      defaultHeaders*: HttpHeaders
      defaultPage*: string
      currPage*: string

      # Function for initiating the lower object.
      init*: proc(this: Novel, uri: string) {.nimcall.}
      # Function for returning all TiNodes associated with chapters.
      getNodes*: proc(this: Novel, chapter: Chapter): seq[TiNode] {.nimcall.}
      # Function for setting MetaData
      getMetaData*: proc(this: Novel): MetaData {.nimcall.}
      # Function for setting chapters
      getChapterSequence*: proc(this: Novel): seq[Chapter] {.nimcall.}
      # Function to get the home carousel of the downloader
      getHomeCarousel: proc(this: Novel): seq[Novel] {.nimcall.}

method Init*(this: Novel, hTuple: HeaderTuple) =
  this.setTuple(hTuple)
  this.ourClient = newHttpClient()
  this.ourClient.headers = this.defaultHeaders

method setTuple(this: Novel, hTuple: HeaderTuple) =
  this.defaultHeaders = hTuple[0]
  this.defaultPage = hTuple[1]
  this.getNodes = hTuple[2]
  this.getMetaData = hTuple[3]
  this.getChapterSequence = hTuple[4]
