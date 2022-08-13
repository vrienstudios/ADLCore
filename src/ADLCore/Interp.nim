import nimscripter
import genericMediaTypes
import ./Novel/NovelTypes, ./Video/VideoType
import std/[httpclient, htmlparser, xmltree, strutils, strtabs, parseutils, sequtils]
import EPUB/Types/genericTypes

type
  InfoTuple* = tuple[name: string, cover: string, scraperType: string, version: string, projectUri: string, siteUri: string]
  NScript* = ref object of RootObj
    headerInfo*: InfoTuple
    scriptPath: string
    intr: Option[Interpreter]
    novelHost: Novel
    videoHost: Video

method GetMetaData*(this: Nscript, page: string): MetaData =
  return this.intr.invoke(GetMetaData, page, returnType = MetaData)

proc processHttpRequest(uri: string, headers: seq[tuple[key: string, value: string]]): string =
  var client = newHttpClient()
  var reqHeaders: HttpHeaders = HttpHeaders()
  for i in headers:
    add(reqHeaders, i.key, i.value)
  return client.getContent(uri)

exportTo(ADLNovel, InfoTuple, Status, LanguageType, MetaData,
  Image, TiNode, processHttpRequest)
const novelInclude = implNimScriptModule(ADLNovel)

proc GenNewScript*(path: string): NScript =
  var script: NScript = NScript()
  let scr = NimScriptPath(path)
  script.scriptPath = path
  script.intr = loadScript(scr, novelInclude)
  script.headerInfo = script.intr.invoke(Info, returnType = InfoTuple)
  if script.headerInfo.scraperType == "novel": script.novelHost = Novel()
  elif script.headerInfo.scraperType == "video": script.videoHost = Video()
  return script

