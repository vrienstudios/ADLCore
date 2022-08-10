import ADLCore, ADLCore/Novel/NovelTypes, ADLCore/Novel/NovelHall, ADLCore/genericMediaTypes
import EPUB, EPUB/genericHelpers
import unittest, std/[os, strutils]

suite "Novel/NovelHall":
  var novelObj: Novel
  test "Can generate novelObj without url":
    novelObj = GenerateNewNovelInstance("NovelHall", "")
  test "Search for Outrageous returns at least one result":
    var search = novelObj.searchDownloader("Outrageous")
    for result in search:
      echo result.name
    check search.len > 0
  test "MetaData object for Number One Lazy Merchant of the Beast World is correct":
    novelObj = GenerateNewNovelInstance("NovelHall", "https://www.novelhall.com/number-one-lazy-merchant-of-the-beast-world-13138/")
    discard novelObj.getMetaData()
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
    discard novelObj.getChapterSequence
    var epb: Epub = Epub(title: novelObj.metaData.name, author: novelObj.metaData.author)
    discard epb.StartEpubExport("./" & novelObj.metaData.name)
    for chapter in novelObj.chapters:
      echo chapter.name & " " & chapter.uri
      var nodes = novelObj.getNodes(chapter)
      echo $nodes.len & " Nodes"
      for node in nodes:
        echo "Text: " & node.text
        for image in node.images:
          echo "Image: " & image.name
      discard epb.AddPage(GeneratePage(nodes, chapter.name))
    discard epb.EndEpubExport("001001", "ADLCore", "")
    check fileExists("./Number One Lazy Merchant of the Beast World.epub")
