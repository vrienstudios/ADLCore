import nimscripter
import ./Novel/NovelTypes

proc processHttpRequest(uri: string): string =
  return getHttp(noveObj, uri)

exportTo(ADLNovel, InfoTuple, Status, LanguageType, MetaData,
  Image, TiNode, processHttpRequest)
const includes = implNimScriptModule(ADLNovel)

proc InitNovelScript*(scriptPath: string): Novel =
  var novelObj: Novel = Novel()
  novelObj.isOwnedByScript = true
  # Load Script
  let scr = NimScriptPath(scriptPath)
  novelObj.intr = loadscript(scr, includes)
  novelObj.ourClient = newHttpClient()