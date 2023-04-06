import ADLCore, ADLCore/DownloadManager, ADLCore/genericMediaTypes
import EPUB/EPUB3
import unittest, std/[os, times]

suite "Novel/NovelHall":
  var novelObj: Novel
  test "Can generate novelObj without url":
    novelObj = GenerateNewNovelInstance("NovelHall", "")
  test "Search for Outrageous returns at least one result":
    var search = SearchDownloader(novelObj, "Outrageous")
    for result in search:
      echo result.name
    check search.len > 0
  test "MetaData object for Number One Lazy Merchant of the Beast World is correct":
    novelObj = GenerateNewNovelInstance("NovelHall", "https://www.novelhall.com/number-one-lazy-merchant-of-the-beast-world-13138/")
    novelObj.metaData = GetMetaData(novelObj)
    echo "Name: " & novelObj.metaData.name
    echo "Author: " & novelObj.metaData.author
    # url is not set in getMetaData so its empty
    echo "Uri: " & novelObj.metaData.uri
    echo "Desc: " & novelObj.metaData.description
    echo "Status: " & $novelObj.metaData.statusType
    check novelObj.metaData.name == "Number One Lazy Merchant of the Beast World"
    check novelObj.metaData.author == "Metasequoia"
    check len(novelObj.metaData.description) > 0
    check novelObj.metaData.statusType == Status.Completed
  test "Can get chapter nodes and export EPUB file":
    discard GetChapterSequence(novelObj)
    let mdataList: seq[metaDataList] = @[
      (metaType: MetaType.dc, name: "title", attrs: @[("id", "title")], text: novelObj.metaData.name),
      (metaType: MetaType.dc, name: "creator", attrs: @[("id", "creator")], text: novelObj.metaData.author),
      (metaType: MetaType.dc, name: "language", attrs: @[], text: "?"),
      (metaType: MetaType.dc, name: "identifier", attrs: @[("id", "pub-id")], text: ""),
      (metaType: MetaType.meta, name: "", attrs: @[("property", "dcterms:modified")], text: getDateStr()),
      (metaType: MetaType.dc, name: "publisher", attrs: @[], text: "animedl")]
    var epb: EPUB3 = CreateEpub3(mdataList, "./" & novelObj.metaData.name)
    #var epb: Epub = Epub(title: novelObj.metaData.name, author: novelObj.metaData.author)
    #discard epb.StartEpubExport("./" & novelObj.metaData.name)
    for chapter in novelObj.chapters:
      echo chapter.name & " " & chapter.uri
      var nodes = GetNodes(novelObj, chapter)
      echo $nodes.len & " Nodes"
      for node in nodes:
        echo "Text: " & node.text
        for image in node.images:
          echo "Image: " & image.name
      AddGenPage(epb, chapter.name, nodes)
    FinalizeEpub(epb)
    #  discard epb.AddPage(GeneratePage(nodes, chapter.name))
    #discard epb.EndEpubExport("001001", "ADLCore", "")
    check fileExists("./Number One Lazy Merchant of the Beast World.epub")
