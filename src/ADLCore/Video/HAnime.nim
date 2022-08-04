import HLSManager
import ../genericMediaTypes
import std/[os, asyncdispatch, httpclient, htmlparser, xmltree, strutils, strtabs, parseutils, sequtils, base64, json]
import nimcrypto
import std/json
import VideoType

var jContent: JsonNode
var aesKey: string

proc GetMetaData*(this: Video): MetaData =
  this.metaData = MetaData()
  if this.currPage != this.defaultPage:
    this.ourClient.headers = this.defaultHeaders
    this.page = parseHtml(this.ourClient.getContent(this.defaultPage))
    this.currPage = this.defaultPage
  let jsonData = this.page.findAll("script")[0].innerText
  let jsonObject = parseJson(jsonData)
  let data = jsonObject["data"]["video"]["hentai_video"]
  jContent = data
  this.metaData.name = data["name"].getStr()
  this.metaData.description = parseHtml(data["description"].getStr()).innerText
  this.metaData.author = data["brand"].getStr()
  this.metaData.coverUri = data["cover_url"].getStr()
  this.metaData.uri = "www.hanime.tv/" & data["slug"].getStr()
  return this.metaData

proc listResolutions*(this: Video): seq[MediaStreamTuple] =
  # We will continue to refrain from exploiting their API to provide 1080P content.
  # Again, buy HAnime premiun, if you wish to watch or download 1080P content.
  # Or wait until we implement torrents; not gonna waste he bandwidth of HAnime.
  var medStreams: seq[MediaStreamTuple] = @[]
  assert jContent != nil
  let servers = jContent["videos_manifest"]["servers"][1..^1]
  for resolution in servers:
    medStreams.add(MediaStreamTuple(id: resolution["id"], uri: resolution["url"],
      resolution: resolution["width"] & "x" & resolution["height"]))
  return medStreams

proc selResolution*(this: Video, tul: MediaStreamTuple =
  return # TODO

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
  return (headers: defHeaders,
    defaultPage: uri,
    getStream: nil,
    getMetaData: nil,
    getEpisodeSequence: nil,
    getHomeCarousel: nil,
    searchDownloader: nil,
    selResolution: nil,
    listResolution: nil,
    downloadNextVideoPart: nil,
    downloadNextAudioPart: nil
  )