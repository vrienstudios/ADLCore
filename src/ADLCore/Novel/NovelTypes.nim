import EPUB/types
import ../genericMediaTypes
import std/[asyncdispatch, httpclient, xmltree, tables]

type
  Chapter* = ref object of RootObj
      name*: string
      number*: int
      uri*: string
      contentSeq*: seq[TiNode]
  Novel* = ref object of RootObj
      isOwnedByScript*: bool

      metaData*: MetaData
      lastModified*: string

      # Ay, yayayay
      volumes*: seq[tuple[names: string, chapters: seq[Chapter]]]
      chapters*: seq[Chapter]
      currChapter*: int

      ourClient*: HttpClient
      page*: XmlNode
      defaultHeaders*: HttpHeaders
      defaultPage*: string
      currPage*: string

      # Function for initiating the lower object.
      init: proc(this: Novel, uri: string) {.nimcall.}
      # Function for returning all TiNodes associated with chapters.
      getNodes: proc(this: Novel, chapter: Chapter): seq[TiNode] {.nimcall, gcsafe.}
      # Function for setting MetaData
      getMetaData: proc(this: Novel): MetaData {.nimcall.}
      # Function for setting chapters
      getChapterSequence: proc(this: Novel): seq[Chapter] {.nimcall.}
      # Function to get the home carousel of the downloader
      getHomeCarousel: proc(this: Novel): seq[MetaData] {.nimcall.}
      # Function to get search information from
      searchDownloader: proc(this: Novel, str: string): seq[MetaData] {.nimcall.}
      # Function to get the data from the cover using ourClient
      getCover: proc (this: Novel): string {.nimcall.}