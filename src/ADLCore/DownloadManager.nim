import genericMediaTypes
import EPUB/types
import HLSManager
import Novel/NovelTypes, Video/VideoType
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
    getStream*: proc(this: Video): HLSStream {.nimcall.}
    # Function for gathering MetaData object for Video.
    getMetaData*: proc(this: Video): MetaData {.nimcall.}
    # Function for gathering list of related episodes.
    getEpisodeSequence*: proc(this: Video): seq[MetaData] {.nimcall.}
    # Function for getting the home page/carousel..
    getHomeCarousel*: proc(this: Video): seq[MetaData] {.nimcall.}
    # Function for getting search information..
    searchDownloader*: proc(this: Video, str: string): seq[MetaData] {.gcsafe.}
    # Function for getting the cover from the downloader (Unused right now).
    getCover*: proc(this: Video): string {.nimcall.}
    # Function for getting the next part or byte sequence in the stream in the form of a string.
    getNext*: proc (this: Video): string {.nimcall.}
    # Select desired resolution
    selResolution*: proc(this: Video, tul: MediaStreamTuple)
    # List all resolutions caught (includes video)
    listResolution*: proc(this: Video): seq[MediaStreamTuple]
    # Download video/audio parts
    downloadNextVideoPart*: proc(this: Video, path: string): bool
    downloadNextAudioPart*: proc(this: Video, path: string): bool
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
      init*: proc(this: Novel, uri: string) {.nimcall.}
      # Function for returning all TiNodes associated with chapters.
      GgetNodes*: proc(this: Novel, chapter: Chapter): seq[TiNode] {.nimcall, gcsafe.}
      # Function for setting MetaData
      getMetaData*: proc(this: Novel): MetaData {.nimcall.}
      # Function for setting chapters
      getChapterSequence*: proc(this: Novel): seq[Chapter] {.nimcall.}
      # Function to get the home carousel of the downloader
      getHomeCarousel*: proc(this: Novel): seq[MetaData] {.nimcall.}
      # Function to get search information from
      searchDownloader*: proc(this: Novel, str: string): seq[MetaData] {.nimcall.}
      # Function to get the data from the cover using ourClient
      getCover*: proc (this: Novel): string {.nimcall.}
  HeaderTuple* = tuple[
    downloadNextAudioPart: proc(this: Video, path: string) : bool {.nimcall.},           #0
    downloadNextVideoPart: proc(this: Video, path: string) : bool {.nimcall.},           #1
    getChapterSequence: proc(this: Novel): seq[Chapter] {.nimcall.},                     #2
    getEpisodeSequence: proc(this: Video): seq[MetaData] {.nimcall.},                    #3
    getNovelHomeCarousel: proc(this: Novel): seq[MetaData] {.nimcall.},                  #4
    getVideoHomeCarousel: proc(this: Video): seq[MetaData] {.nimcall.},                  #5
    getNovelMetaData: proc(this: Novel): MetaData {.nimcall.},                           #6
    getVideoMetaData: proc(this: Video): MetaData {.nimcall.},                           #7
    getNodes: proc(this: Novel, chapter: Chapter): seq[TiNode] {.nimcall, gcsafe.},      #8
    getStream: proc(this: Video): HLSStream {.nimcall.},                                 #9
    listResolution: proc(this: Video): seq[MediaStreamTuple] {.nimcall.},                #10
    searchNovelDownloader: proc(this: Novel, str: string): seq[MetaData] {.nimcall.},    #11
    searchVideoDownloader: proc(this: Video, str: string): seq[MetaData] {.nimcall, gcsafe.},    #12
    selResolution: proc(this: Video, tul: MediaStreamTuple) {.nimcall.},                 #13
    headers: HttpHeaders, defaultPage: string]                                           #14,15

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
    this.ourClient.headers = headers[14]
    this.defaultPage = headers[15]
method Init*(this: Novel, headers: HeaderTuple) {.base.} =
    #this.downloadNextAudioPart = headers[0]
    #this.downloadNextVideoPart = headers[1]
    this.getChapterSequence = headers[2]
    #this.getEpisodeSequence = headers[3]
    this.getHomeCarousel = headers[4]
    this.getMetaData = headers[6]
    this.GgetNodes = headers[8]
    #this.getStream = headers[7]
    #this.listResolution = headers[8]
    #this.searchDownloader = headers[9]
    #this.selResolution = headers[10]

    this.ourClient = newHttpClient()
    this.ourClient.headers = headers[14]
    this.defaultPage = headers[15]