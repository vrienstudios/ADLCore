import ADLCore, ADLCore/Novel/NovelTypes, ADLCore/genericMediaTypes, ADLCore/Novel/MangaKakalot
import EPUB, EPUB/genericHelpers
import unittest, std/[os, strutils]

suite "Novel/MangaKakalot":
  var novelObj: Novel
  test "Can generate novelObj":
    novelObj = GenerateNewNovelInstance("MangaKakalot", "")
  test "Search for komi returns at least one result":
    var search = novelObj.searchDownloader("komi")
    for result in search:
      echo result.name
    check search.len > 0
  test "MetaData object for Himitsu ni shiro yo!! is correct":
    novelObj = GenerateNewNovelInstance("MangaKakalot", "https://mangakakalot.com/manga/ak928973")
    discard novelObj.getMetaData()
    echo "Name: " & novelObj.metaData.name
    echo "Author: " & novelObj.metaData.author
    echo "Uri: " & novelObj.metaData.uri
    echo "Desc: " & novelObj.metaData.description
    echo "Genre: " & $novelObj.metaData.genre
    echo "CoverUri: " & novelObj.metaData.coverUri
    echo "Rating: " & novelObj.metaData.rating
    echo "Status: " & $novelObj.metaData.statusType
    check novelObj.metaData.name == "Himitsu ni shiro yo!!"
    check novelObj.metaData.author == "Satomaru Mami"
    check novelObj.metaData.description.len > 0
    check novelObj.metaData.genre.len > 0
    check novelObj.metaData.coverUri.len > 0
    check novelObj.metaData.rating.len > 0
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
        for image in node.images:
          echo "Image: " & image.name
      discard epb.AddPage(GeneratePage(nodes, chapter.name))
    discard epb.EndEpubExport("001001", "ADLCore", "")
    check fileExists("./Himitsu ni shiro yo!!.epub")
