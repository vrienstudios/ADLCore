import HLSManager
import ../genericMediaTypes
import std/[httpclient, xmltree]
type
  HeaderTuple* = tuple[headers: HttpHeaders, defaultPage: string,
    getStream: proc(this: Video): HLSStream {.nimcall.},
    getMetaData: proc(this: Video): MetaData {.nimcall.},
    getEpisodeSequence: proc(this: Video): seq[MetaData] {.nimcall.},
    getHomeCarousel: proc(this: Video): seq[MetaData] {.nimcall.},
    searchDownloader: proc(this: Video, str: string): seq[MetaData] {.nimcall.},
    selResolution: proc(this: Video, tul: MediaStreamTuple) {.nimcall.},
    listResolution: proc(this: Video): seq[MediaStreamTuple] {.nimcall.},
    downloadNextVideoPart: proc(this: Video, path: string) : bool {.nimcall.},
    downloadNextAudioPart: proc(this: Video, path: string) : bool {.nimcall.}]
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
    getStream: proc(this: Video): HLSStream {.nimcall.}
    # Function for gathering MetaData object for Video.
    getMetaData: proc(this: Video): MetaData {.nimcall.}
    # Function for gathering list of related episodes.
    getEpisodeSequence: proc(this: Video): seq[MetaData] {.nimcall.}
    # Function for getting the home page/carousel..
    getHomeCarousel: proc(this: Video): seq[MetaData] {.nimcall.}
    # Function for getting search information..
    searchDownloader: proc(this: Video, str: string): seq[MetaData]
    # Function for getting the cover from the downloader (Unused right now).
    getCover: proc(this: Video): string {.nimcall.}
    # Function for getting the next part or byte sequence in the stream in the form of a string.
    getNext: proc (this: Video): string {.nimcall.}
    # Select desired resolution
    selResolution: proc(this: Video, tul: MediaStreamTuple)
    # List all resolutions caught (includes video)
    listResolution: proc(this: Video): seq[MediaStreamTuple]
    # Download video/audio parts
    downloadNextVideoPart: proc(this: Video, path: string): bool
    downloadNextAudioPart: proc(this: Video, path: string): bool

# Wrappers for the functions.
method getStream*(this: Video): HLSStream =
  return this.getStream(this)
method getMetaData*(this: Video): MetaData =
  this.metaData = this.getMetaData(this)
  return this.metaData
method getEpisodeSequence*(this: Video): seq[MetaData] =
  return this.getEpisodeSequence(this)
method getHomeCarousel*(this: Video): seq[MetaData] =
  return this.getHomeCarousel(this)
method searchDownloader*(this: Video, str: string): seq[MetaData] =
  return this.searchDownloader(this, str)
method getNext*(this: Video): string {.nimcall.} =
  return this.getNext(this)
method Init*(this: Video, hTupe: HeaderTuple) =
  this.ourClient = newHttpClient()
  this.ourClient.headers = hTupe[0]
  this.defaultPage =  hTupe[1]
  this.defaultHeaders = hTupe[0]
  this.getStream = hTupe[2]
  this.getMetaData = hTupe[3]
  this.getEpisodeSequence = hTupe[4]
  this.getHomeCarousel = hTupe[5]
  this.searchDownloader = hTupe[6]
  this.selResolution = hTupe[7]
  this.listResolution = hTupe[8]
  this.downloadNextVideoPart = hTupe[9]
  this.downloadNextAudioPart = hTupe[10]
