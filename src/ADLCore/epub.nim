import ./[context, utils]
import std/[os, times]

import EPUB
export EPUB

proc buildCoverAndDefaultPage*(novelObj: var DownloaderContext, epub3: Epub3) =
  # section[0] should contain all metadata information about the novel including num of chapters.
  let meta = novelObj.sections[0].mdat
  var 
    nodes: seq[TiNode] = @[]
    coverBytes: string = ""
  try:
    var host: string = meta.coverUri.split("/")[2]
    novelObj.ourClient.headers = newHttpHeaders({
      "User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:101.0) Gecko/20100101 Firefox/101.0",
      "Referer": novelObj.defaultPage,
      "Host": host,
      "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,application/json,*/*;q=0.8"
    })
    coverBytes = novelObj.ourClient.getContent(meta.coverUri)
    novelObj.ourClient.headers = novelObj.defaultHeaders
    let img = Image(fileName: "cover.jpeg", kind: ImageKind.cover, path: coverBytes, isPathData: true)
    epub3.add img
    nodes.add TiNode(kind: NodeKind.ximage, image: img, customPath: "../../cover.jpeg")
  except:
    novelObj.ourClient.headers = novelObj.defaultHeaders
  nodes.add TiNode(kind: NodeKind.paragraph, text: "Title: " & meta.name)
  nodes.add TiNode(kind: NodeKind.paragraph, text: "Author: " & meta.author)
  nodes.add TiNode(kind: NodeKind.paragraph, text: "Synopsis: " & meta.description)
  nodes.add TiNode(kind: NodeKind.paragraph, text: "Created with ADLCore (https://github.com/vrienstudios/ADLCore)")
  nodes.add TiNode(kind: NodeKind.paragraph, text: "Scraped from: " & meta.uri)
  nodes.add TiNode(kind: NodeKind.paragraph, text: "Number of pages: " & $novelObj.sections[0].parts.len)
  epub3.add Page(name: "info", nodes: nodes)
proc setupEpub*(mdataObj: MetaData): Epub3 =
  var epub: Epub3
  let appDir = getAppDir()
  let potentialPath = appDir / mdataObj.name & ".epub"
  if fileExists(potentialPath):
  # Check if DIR exists if file also exists.
    if dirExists(appDir / mdataObj.name):
      echo "loading from dir instead of file"
      epub = LoadEpubFromDir(appDir / mdataObj.name)
    else:
      echo "loading from file"
      epub = LoadEpubFile(potentialPath)
    echo "loading TOC"
    epub.loadTOC()
    epub.beginExport()
    return epub
  if dirExists(appDir / mdataObj.name):
    echo "loading from dir"
    epub = LoadEpubFromDir(appDir / mdataObj.name)
    echo "loading TOC"
    epub.loadTOC()
    epub.beginExport()
    return epub
  epub = CreateNewEpub(mdataObj.name, appDir / mdataObj.name)
  epub.beginExport() # Export while creating
  block addMeta:
    # Title
    epub.metaData.add EpubMetaData(metaType: MetaType.dc, name: "title", attrs: {"id": "title"}.toXmlAttributes(), text: mdataObj.name)
    # Author
    epub.metaData.add EpubMetaData(metaType: MetaType.dc, name: "creator", attrs: {"id": "creator"}.toXmlAttributes(), text: mdataObj.author)
    # Default Language
    epub.metaData.add EpubMetaData(metaType: MetaType.dc, name: "language", text: "en")
    # modification date
    epub.metaData.add EpubMetaData(metaType: MetaType.meta, attrs: {"property": "dcterms:modified"}.toXmlAttributes(), text: $getTime())
    # Publisher (default to us)
    epub.metaData.add EpubMetaData(metaType: MetaType.dc, name: "publisher", text: "anime-dl")
    # Build in memory -- use a different method for epub resumation.
  return epub
proc `+=`(epub: var Epub3, name: string, nodes: seq[TiNode]) =
  if fileExists("./" / epub.path / "OPF" / "Pages" / name & ".xhtml"): return
  epub.add(Page(name: name, nodes: nodes))