import nimscripter
import genericMediaTypes
import ./Novel/NovelTypes, ./Video/VideoType
import std/[httpclient, htmlparser, xmltree, strutils, strtabs, parseutils, sequtils]
import EPUB/types

var NScriptClient: seq[HttpClient] = @[]
type
  InfoTuple* = tuple[name: string, cover: string, scraperType: string, version: string, projectUri: string, siteUri: string, scriptPath: string]
  NScript* = ref object
    headerInfo*: InfoTuple
    scriptID: int
    intr: Option[Interpreter]
proc `=destory`(script: var NScript) =
  NScriptClient[script.scriptID] = null
  freeResource(script.headerInfo)
  freeResource(script.scriptID)
  freeResource(script.intr)

method getNodes*(this: Nscript, chapter: string): seq[TiNode] =
  return this.intr.invoke(GetNodes, chapter, returnType = seq[TiNode])
method getMetaData*(this: Nscript, page: string): MetaData =
  return this.intr.invoke(GetMetaData, page, returnType = MetaData)
method getChapterSequence*(this: Nscript, page: string): seq[Chapter] =
  return this.intr.invoke(GetChapterSequence, page, returnType = seq[Chapter])
# getHomeCarousel should probably return a seq[MetaData] that is later consumed by getChapterSequence to get a download
method getHomeCarousel*(this: Nscript, page: string): seq[MetaData] =
  return this.intr.invoke(GetHomeCarousel, page, returnType = seq[MetaData])
method searchDownloader*(this: Nscript, str: string): seq[MetaData] =
  return this.intr.invoke(Search, str, returnType = seq[MetaData])

proc ParseInfoTuple(file: string): InfoTuple =
  var infoTuple: InfoTuple = (name: "", cover: "", scraperType: "", version: "", projectUri: "", siteUri: "", scriptPath: "")
  var lines = file.splitLines
  for line in lines:
    var str = line.strip
    if str == "": continue
    if str.startsWith("#"):
      str.removePrefix('#')
      str = str.strip
      var pair = str.split(':')
      if pair.len < 2: continue
      var key = pair[0].strip
      pair.delete(0)
      var value = pair.join(":").strip
      case key:
        of "name":
          infoTuple.name = value
        of "cover":
          infoTuple.cover = value
        of "scraperType":
          infoTuple.scraperType = value
        of "version":
          infoTuple.version = value
        of "projectUri":
          infoTuple.projectUri = value
        of "siteUri":
          infoTuple.siteUri = value
    else: break
  return infoTuple
proc ReadScriptInfoTuple*(path: string): InfoTuple =
  var infoTuple = ParseInfoTuple(readFile(path))
  infoTuple.scriptPath = path
  return infoTuple
proc processHttpRequest(uri: string, scriptID: int, headers: seq[tuple[key: string, value: string]]): string =
  var reqHeaders: HttpHeaders = HttpHeaders()
  for i in headers:
    add(reqHeaders, i.key, i.value)
  NScriptClient[scriptID].defaultHeaders = reqHeaders
  return NScriptClient[scriptID].getContent(uri)

exportTo(ADLNovel, InfoTuple, Status, LanguageType, MetaData,
  Image, TiNode, processHttpRequest)
const novelInclude = implNimScriptModule(ADLNovel)


proc GenNewScript*(path: string): NScript =
  var script: NScript = NScript()
  let scr = NimScriptPath(path)
  script.intr = loadScript(scr, novelInclude)
  script.headerInfo = ReadScriptInfoTuple(path)
  return script
