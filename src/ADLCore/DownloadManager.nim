import genericMediaTypes
import EPUB/types
import HLSManager
import std/[httpclient, xmltree]

type
  MediaStreamTuple* = tuple[id: string, resolution: string, uri: string, language: string, isAudio: bool, bandWidth: string]
  Video* = ref object of RootObj
    ourClient*: HttpClient
    metaData*: MetaData
    page*: XmlNode
    defaultHeaders*: HttpHeaders
    defaultPage*: string
    currPage*: string
    hlsStream*: HLSStream
    videoCurrIdx*: int
    videoStream*: seq[string]
    audioCurrIdx*: int
    audioStream*: seq[string]
    mediaStreams*: seq[MediaStreamTuple]
    # Function for getting the base stream for Episode; this would, supposedly, be used for embedded video players.
    getStream*: proc(this: Video): HLSStream {.nimcall, gcsafe.}
    # Function for gathering MetaData object for Video.
    getMetaData*: proc(this: Video): MetaData {.nimcall, gcsafe.}
    # Function for gathering list of related episodes.
    getEpisodeSequence*: proc(this: Video): seq[MetaData] {.nimcall, gcsafe.}
    # Function for getting the home page/carousel..
    getHomeCarousel*: proc(this: Video): seq[MetaData] {.nimcall, gcsafe.}
    # Function for getting search information..
    searchDownloader*: proc(this: Video, str: string): seq[MetaData] {.nimcall, gcsafe.}
    # Function for getting the cover from the downloader (Unused right now).
    getCover*: proc(this: Video): string {.nimcall, gcsafe.}
    # Function for getting the next part or byte sequence in the stream in the form of a string.
    getNext*: proc (this: Video): string {.nimcall, gcsafe.}
    # Select desired resolution
    selResolution*: proc(this: Video, tul: MediaStreamTuple) {.nimcall, gcsafe.}
    # List all resolutions caught (includes video)
    listResolution*: proc(this: Video): seq[MediaStreamTuple] {.nimcall, gcsafe.}
    # Download video/audio parts
    downloadNextVideoPart*: proc(this: Video, path: string): bool {.nimcall, gcsafe.}
    downloadNextAudioPart*: proc(this: Video, path: string): bool {.nimcall, gcsafe.}
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
      init*: proc(this: Novel, uri: string) {.nimcall, gcsafe.}
      # Function for returning all TiNodes associated with chapters.
      getNodes*: proc(this: Novel, chapter: Chapter): seq[TiNode] {.nimcall, gcsafe.}
      # Function for setting MetaData
      getMetaData*: proc(this: Novel): MetaData {.nimcall, gcsafe.}
      # Function for setting chapters
      getChapterSequence*: proc(this: Novel): seq[Chapter] {.nimcall, gcsafe.}
      # Function to get the home carousel of the downloader
      getHomeCarousel*: proc(this: Novel): seq[MetaData] {.nimcall, gcsafe.}
      # Function to get search information from
      searchDownloader*: proc(this: Novel, str: string): seq[MetaData] {.nimcall, gcsafe.}
      # Function to get the data from the cover using ourClient
      getCover*: proc (this: Novel): string {.nimcall, gcsafe.}
  HeaderTuple* = tuple[
    downloadNextAudioPart: proc(this: Video, path: string) : bool {.nimcall, gcsafe.},                   #0
    downloadNextVideoPart: proc(this: Video, path: string) : bool {.nimcall, gcsafe.},                   #1
    getChapterSequence: proc(this: Novel): seq[Chapter] {.nimcall, gcsafe.},                             #2
    getEpisodeSequence: proc(this: Video): seq[MetaData] {.nimcall, gcsafe.},                            #3
    getNovelHomeCarousel: proc(this: Novel): seq[MetaData] {.nimcall, gcsafe.},                          #4
    getVideoHomeCarousel: proc(this: Video): seq[MetaData] {.nimcall, gcsafe.},                          #5
    getNovelMetaData: proc(this: Novel): MetaData {.nimcall, gcsafe.},                                   #6
    getVideoMetaData: proc(this: Video): MetaData {.nimcall, gcsafe.},                                   #7
    getNodes: proc(this: Novel, chapter: Chapter): seq[TiNode] {.nimcall, gcsafe.},              #8
    getStream: proc(this: Video): HLSStream {.nimcall, gcsafe.},                                         #9
    listResolution: proc(this: Video): seq[MediaStreamTuple] {.nimcall, gcsafe.},                        #10
    searchNovelDownloader: proc(this: Novel, str: string): seq[MetaData] {.nimcall, gcsafe.},            #11
    searchVideoDownloader: proc(this: Video, str: string): seq[MetaData] {.nimcall, gcsafe.},    #12
    selResolution: proc(this: Video, tul: MediaStreamTuple) {.nimcall, gcsafe.},                         #13
    headers: HttpHeaders, defaultPage: string]                                                   #14,15

proc DownloadNextAudioPart*(this: Video, path: string): bool {.gcsafe.} =
  return this.downloadNextAudioPart(this, path)
proc DownloadNextVideoPart*(this: Video, path: string): bool {.gcsafe.} =
  return this.downloadNextVideoPart(this, path)
proc GetChapterSequence*(this: Novel): seq[Chapter] {.gcsafe.} =
  return this.getChapterSequence(this)
proc GetEpisodeSequence*(this: Video): seq[MetaData] {.gcsafe.} =
  return this.getEpisodeSequence(this)
proc GetNovelHomeCarousel*(this: Novel): seq[MetaData] {.gcsafe.} =
  return this.getHomeCarousel(this)
proc GetVideoHomeCarousel*(this: Video): seq[MetaData] {.gcsafe.} =
  return this.getHomeCarousel(this)
proc GetMetaData*(this: Novel): MetaData {.gcsafe.} =
  return this.getMetaData(this)
proc GetMetaData*(this: Video): MetaData {.gcsafe.} =
  return this.getMetaData(this)
proc GetNodes*(this: Novel, chapter: Chapter): seq[TiNode] {.gcsafe.} =
  return this.getNodes(this, chapter)
proc GetStream*(this: Video): HLSStream {.gcsafe.} =
  return this.getStream(this)
proc ListResolutions*(this: Video): seq[MediaStreamTuple] {.gcsafe.} =
  return this.listResolution(this)
proc SearchDownloader*(this: Novel, str: string): seq[MetaData] {.gcsafe.} =
  return this.searchDownloader(this, str)
proc SearchDownloader*(this: Video, str: string): seq[MetaData] {.gcsafe.} =
  return this.searchDownloader(this, str)
proc SelResolution*(this: Video, tul: MediaStreamTuple) {.gcsafe.} =
  this.selResolution(this, tul)

method Init*(this: Video, headers: HeaderTuple) {.base.} =
    this.downloadNextAudioPart = headers[0]
    this.downloadNextVideoPart = headers[1]
    #this.getChapterSequence = headers[2]
    this.getEpisodeSequence = headers[3]
    this.getHomeCarousel = headers[5]
    this.getMetaData = headers[7]
    #this.getNodes = headers[6]
    this.getStream = headers[9]
    this.listResolution = headers[10]
    this.searchDownloader = headers[12]
    this.selResolution = headers[13]

    this.ourClient = newHttpClient()
    this.defaultHeaders = headers[14]
    this.ourClient.headers = this.defaultHeaders
    this.defaultPage = headers[15]
method Init*(this: Novel, headers: HeaderTuple) {.base.} =
    #this.downloadNextAudioPart = headers[0]
    #this.downloadNextVideoPart = headers[1]
    this.getChapterSequence = headers[2]
    #this.getEpisodeSequence = headers[3]
    this.getHomeCarousel = headers[4]
    this.getMetaData = headers[6]
    this.getNodes = headers[8]
    #this.getStream = headers[7]
    #this.listResolution = headers[8]
    #this.searchDownloader = headers[9]
    #this.selResolution = headers[10]

    this.ourClient = newHttpClient()
    this.defaultHeaders = headers[14]
    this.ourClient.headers = this.defaultHeaders
    this.defaultPage = headers[15]