import HLSManager
import ../genericMediaTypes
import std/[os, asyncdispatch, httpclient, htmlparser, xmltree, strutils, strtabs, parseutils, sequtils, base64, json]
import nimcrypto
import std/json
import ../DownloadManager

var jContent: JsonNode
var aesKey: string

proc Search*(this: Video, str: string): seq[MetaData] {.gcsafe.} =
  # https://search.htv-services.com/
  let mSearchData = %*{
    "blacklist": [],
    "brands": [],
    "order_by": "created_at_unix",
    "ordering": "desc",
    "page": 0,
    "search_text": str,
    "tags": [],
    "tags_mode": "AND"
  }
  var data: seq[MetaData] = @[]
  let defHeaders = newHttpHeaders({
    "Content-Type": "application/json"
  })
  let response = this.ourClient.request("https://search.htv-services.com/", httpMethod = HttpPost, body = $mSearchData,
    headers = defHeaders)
  let jsonData = parseJson(parseJson(response.body)["hits"].getStr()).getElems()
  for i in jsonData:
    var met: MetaData = MetaData()
    met.name = i["name"].getStr()
    met.uri = "https://HAnime.tv/videos/hentai/" & i["slug"].getStr()
    met.coverUri = i["cover_url"].getStr()
    met.series = i["brand"].getStr()
    # Contains <p> html element.
    met.description = parseHtml(i["description"].getStr()).innerText
    var tags: seq[string] = @[]
    for tag in i["tags"].getElems():
      tags.add(tag.getStr())
    met.genre = tags
    data.add(met)
  return data
proc GetMetaData*(this: Video): MetaData =
  this.metaData = MetaData()
  if this.currPage != this.defaultPage:
    this.ourClient.headers = this.defaultHeaders
    this.page = parseHtml(this.ourClient.getContent(this.defaultPage))
    this.currPage = this.defaultPage
  let scripts = this.page.findAll("script")
  var jsonData: string
  for script in scripts:
    if script.innerText.contains("__NUXT__"):
      jsonData = script.innerText[16..^2]
  let jsonObject = parseJson(jsonData)
  #let data = jsonObject["data"].getElems["video"]["hentai_video"]
  let data = jsonObject["state"]["data"]["video"]
  jContent = data
  let mdat = data["hentai_video"]
  this.metaData.name = mdat["name"].getStr()
  this.metaData.description = parseHtml(mdat["description"].getStr()).innerText
  this.metaData.author = mdat["brand"].getStr()
  this.metaData.coverUri = mdat["cover_url"].getStr()
  this.metaData.uri = "www.hanime.tv/" & mdat["slug"].getStr()
  return this.metaData

proc GetStreamStub*(this: Video): HLSStream =
  return this.hlsStream

proc listEResolutions*(this: Video): seq[MediaStreamTuple] =
  # We will continue to refrain from exploiting their API to provide 1080P content.
  # Again, buy HAnime premiun, if you wish to watch or download 1080P content.
  # Or wait until we implement torrents; not gonna waste he bandwidth of HAnime.
  var medStreams: seq[MediaStreamTuple] = @[]
  assert jContent != nil
  let servers = jContent["videos_manifest"]["servers"]
  # skip first to ignore 1080p.
  for resolution in servers.getElems()[0]["streams"].getElems()[1..^1]:
    medStreams.add((id: $resolution["id"].getInt(), resolution: $resolution["width"].getInt() & "x" & resolution["height"].getStr(),
    uri: resolution["url"].getStr(), language: "english",
      isAudio: false, bandWidth: "unknown"))
  return medStreams

proc selEResolution*(this: Video, tul: MediaStreamTuple) {.nimcall.} =
  var vManifest = ParseManifest(splitLines(this.ourClient.getContent(tul.uri)))
  var vSeq: seq[string] = @[]
  aesKey = this.ourClient.getContent("https://hanime.tv/sign.bin")
  for part in vManifest.parts:
    if part.header == "URI":
      vSeq.add(part.values[0].value)
  this.videoStream = vSeq
  # No Audio Streams

# https://www.youtube.com/watch?v=XCrjEPjJp18
proc DownloadNextVideoPart*(this: Video, path: string): bool =
  var dContext: CBC[aes128]
  if this.videoCurrIdx >= this.videoStream.len:
    return false
  let encContent = this.ourClient.getContent(this.videoStream[this.videoCurrIdx])
  let cIdx = $(this.videoCurrIdx + 1)
  let iv: string = newString(aes128.sizeBlock)
  copyMem(unsafeAddr iv[0], unsafeAddr cIdx[0], len(cIdx))
  dContext.init(aesKey, iv)
  var dContent: string = newString(encContent.len)
  dContext.decrypt(encContent, dContent)
  dContext.clear()
  var file: File
  if fileExists(path):
    file = open(path, fmAppend)
  else:
    file = open(path, fmWrite)
  write(file, dContent)
  inc this.videoCurrIdx
  close(file)
  return true

proc Init*(uri: string): HeaderTuple =
  let defHeaders = newHttpHeaders({
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:101.0) Gecko/20100101 Firefox/101.0",
        "Referer": "https://hanime.tv",
        "Accept": "*/*",
        "Origin": "https://hanime.tv",
        "Accept-Encoding": "identity",
        "sec-fetch-site": "same-origin",
        "sec-fetch-mode": "no-cors"
  })
  return (
    downloadNextAudioPart: nil,
    downloadNextVideoPart: HAnime.DownloadNextVideoPart,
    getChapterSequence: nil,
    getEpisodeSequence: nil,
    getNovelHomeCarousel: nil,
    getVideoHomeCarousel: nil,
    getNovelMetaData: nil,
    getVideoMetaData: HAnime.GetMetaData,
    getNodes: nil,
    getStream: HAnime.GetStreamStub,
    listResolution: HAnime.listEResolutions,
    searchNovelDownloader: nil,
    searchVideoDownloader: HAnime.Search,
    selResolution: HAnime.selEResolution,
    headers: defHeaders,
    defaultPage: uri
  )