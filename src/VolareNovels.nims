import std/[htmlparser, xmltree]
var defaultHeaders: seq[tuple[key: string, value: string]] = @[]
var page: XmlNode
var currPage: string

proc GetMetaData*(uri: string): MetaData =
  var cMetaData: MetaData = MetaData()
  cMetaData.name = "Hello, World!"
  page = parseHtml(processHttpRequest(uri, defaultHeaders))
  currPage = uri

  return cMetaData

proc AddHeader*(k: string, v: string) =
  defaultHeaders.add((k, v))
proc getHeaders*(): seq[tuple[key: string, value: string]] =
  return defaultHeaders
proc procHttpTest*(): string =
  return processHttpRequest("newtab", defaultHeaders)

proc Info*(): InfoTuple =
  AddHeader("User-Agent", "Mozilla/5.0 (X11; Linux x86_64; rv:101.0) Gecko/20100101 Firefox/101.0")
  AddHeader("Referer", "https://www.volarenovels.com/")
  AddHeader("Host", "www.volarenovels.com")
  AddHeader("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8")
  return (name: "VolareScraper",
          cover: "", scraperType: "novel",
          version: "", projectUri: "",
          siteUri: "")
