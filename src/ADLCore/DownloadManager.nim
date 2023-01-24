import Novel/NovelTypes, Video/VideoTypes

type
  HeaderTuple = tuple[headers: HttpHeaders, defaultPage: string,
    downloadNextAudioPart: proc(this: Video, path: string) : bool {.nimcall.},
    downloadNextVideoPart: proc(this: Video, path: string) : bool {.nimcall.},
    getChapterSequence: proc(this: Novel): seq[Chapter] {.nimcall.},
    getEpisodeSequence: proc(this: Video): seq[MetaData] {.nimcall.},
    getHomeCarousel: proc(this: Novel): seq[MetaData] {.nimcall.},
    getMetaData: proc(this: Novel): MetaData {.nimcall.},
    getNodes: proc(this: Novel, chapter: Chapter): seq[TiNode] {.nimcall, gcsafe.},
    getStream: proc(this: Video): HLSStream {.nimcall.},
    listResolution: proc(this: Video): seq[MediaStreamTuple] {.nimcall.},
    searchDownloader: proc(this: Novel, str: string): seq[MetaData] {.nimcall.},
    selResolution: proc(this: Video, tul: MediaStreamTuple) {.nimcall.},
    headers: HttpHeaders, defaultPage: string]

method Init*(this: Video, headers: HeaderTuple) {.base.} =
    this.downloadNextAudioPart = headers[0]
    this.downloadNextVideoPart = headers[1]
    this.getChapterSequence = headers[2]
    this.getEpisodeSequence = headers[3]
    this.getHomeCarousel = headers[4]
    this.getMetaData = headers[5]
    this.getNodes = headers[6]
    this.getStream = headers[7]
    this.listResolution = headers[8]
    this.searchDownloader = headers[9]
    this.selResolution = headers[10]

    this.ourClient = newHttpClient()
    this.ourClient.headers = headers[11]
    this.defaultPage = headers[12]
method Init*(this: Novel, headers: HeaderTuple) {.base.} =
    this.downloadNextAudioPart = headers[0]
    this.downloadNextVideoPart = headers[1]
    this.getChapterSequence = headers[2]
    this.getEpisodeSequence = headers[3]
    this.getHomeCarousel = headers[4]
    this.getMetaData = headers[5]
    this.getNodes = headers[6]
    this.getStream = headers[7]
    this.listResolution = headers[8]
    this.searchDownloader = headers[9]
    this.selResolution = headers[10]

    this.ourClient = newHttpClient()
    this.ourClient.headers = headers[11]
    this.defaultPage = headers[12]

# Function 'wrappers' to call the functions in a more logical manner.
method getNodes*(nvl: Novel, chapter: Chapter): seq[TiNode] =
  return nvl.getNodes(nvl, chapter)
method getMetaData*(this: Novel): MetaData =
  this.metaData = this.getMetaData(this)
  return this.metaData
method getChapterSequence*(this: Novel): seq[Chapter] =
  this.chapters = this.getChapterSequence(this)
  return this.chapters
method getHomeCarousel*(this: Novel): seq[MetaData] =
  return this.getHomeCarousel(this)
method searchDownloader*(this: Novel, str: string): seq[MetaData] =
  return this.searchDownloader(this, str)

# Wrappers for the functions.
method getStream*(this: Video): HLSStream {.base.} =
  this.hlsStream = this.getStream(this)
  return this.hlsStream
method listResolution*(this: Video): seq[MediaStreamTuple] {.base.} =
  return this.listResolution(this)
method selResolution*(this: Video, tul: MediaStreamTuple) {.base.} =
  this.selResolution(this, tul)
method downloadNextVideoPart*(this: Video, path: string): bool {.base.} =
  return this.downloadNextVideoPart(this, path)
method downloadNextAudioPart*(this: Video, path: string): bool {.base.} =
  return this.downloadNextAudioPart(this, path)
method getEpisodeSequence*(this: Video): seq[MetaData] {.base.} =
  return this.getEpisodeSequence(this)
method getNext*(this: Video): string {.nimcall, base.} =
  return this.getNext(this)