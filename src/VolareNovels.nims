# name: VolareScraper
# scraperType: novel

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
