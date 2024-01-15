# Site: https://www.braflix.app/
import HLSManager
import ../genericMediaTypes
import std/[os, httpclient, htmlparser, xmltree, strutils, base64, json]
import nimcrypto
import ../DownloadManager

const baseUri: string = "https://www.braflix.app/"

proc SetHLSStream(this: Video): HLSStream =
  return HLSStream()
proc GetMetaData(this: Video): MetaData =
  return MetaData()
proc GetEpisodeSequence(this: Video): seq[MetaData] =
  return @[]
proc ListResolutions(this: Video): seq[MediaStreamTuple] =
  return @[]
proc DownloadNextVideoPart(this: Video, path: string): bool =
  return false
proc DownloadNextAudioPart(this: Video, path: string): bool =
  return false
proc Search*(this: Video, str: string): seq[MetaData] =
  return @[]
proc SelectResolutionFromTuple(this: Video, tul: MediaStreamTuple) =
  return
proc Init*(uri: string): HeaderTuple {.nimcall.} =
    let defaultHeaders = newHttpHeaders({
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:101.0) Gecko/20100101 Firefox/101.0",
        "Referer": "https://membed.net",
        "Accept": "*/*",
        "Origin": "https://membed.net",
        "Accept-Encoding": "identity",
        "sec-fetch-site": "same-origin",
        "sec-fetch-mode": "no-cors"
    })
    return (
      downloadNextAudioPart: Braflix.DownloadNextAudioPart,
      downloadNextVideoPart: Braflix.DownloadNextVideoPart,
      getChapterSequence: nil,
      getEpisodeSequence: Braflix.GetEpisodeSequence,
      getNovelHomeCarousel: nil,
      getVideoHomeCarousel: nil,
      getNovelMetaData: nil,
      getVideoMetaData: Braflix.GetMetaData,
      getNodes: nil,
      getStream: Braflix.SetHLSStream,
      listResolution: Braflix.ListResolutions,
      searchNovelDownloader: nil,
      searchVideoDownloader: Braflix.Search,
      selResolution: Braflix.SelectResolutionFromTuple,
      headers: defaultHeaders,
      defaultPage: uri
    )