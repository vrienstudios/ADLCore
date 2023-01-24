import HLSManager
import ../genericMediaTypes
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
    getStream: proc(this: Video): HLSStream {.nimcall.}
    # Function for gathering MetaData object for Video.
    getMetaData: proc(this: Video): MetaData {.nimcall.}
    # Function for gathering list of related episodes.
    getEpisodeSequence: proc(this: Video): seq[MetaData] {.nimcall.}
    # Function for getting the home page/carousel..
    getHomeCarousel: proc(this: Video): seq[MetaData] {.nimcall.}
    # Function for getting search information..
    searchDownloader: proc(this: Video, str: string): seq[MetaData] {.gcsafe.}
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