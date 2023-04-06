import ADLCore, ADLCore/DownloadManager, ADLCore/genericMediaTypes
import EPUB/EPUB3
import unittest, std/os
import std/times

suite "Novel/MangaKakalot":
  var novelObj: Novel
  test "Can generate novelObj":
    novelObj = GenerateNewNovelInstance("MangaKakalot", "")
  test "Search for komi returns at least one result":
    var search = SearchDownloader(novelObj, "komi")
    for result in search:
      echo result.name
    check search.len > 0
  test "MetaData object for Komi-San Wa Komyushou Desu is correct":
    novelObj = GenerateNewNovelInstance("MangaKakalot", "https://readmanganato.com/manga-va953509")
    discard DownloadManager.GetMetaData(novelObj)
    echo "Name: " & novelObj.metaData.name
    echo "Author: " & novelObj.metaData.author
    echo "Uri: " & novelObj.metaData.uri
    echo "Desc: " & novelObj.metaData.description
    echo "Genre: " & $novelObj.metaData.genre
    echo "CoverUri: " & novelObj.metaData.coverUri
    echo "Rating: " & novelObj.metaData.rating
    echo "Status: " & $novelObj.metaData.statusType
    check novelObj.metaData.name == "Komi-San Wa Komyushou Desu"
    check novelObj.metaData.author == "Oda Tomohito"
    check novelObj.metaData.uri == "https://readmanganato.com/manga-va953509"
    check novelObj.metaData.description.len > 0
    check novelObj.metaData.genre.len > 0
    check novelObj.metaData.coverUri.len > 0
    check novelObj.metaData.rating.len > 0
  test "Can get chapter nodes and export EPUB file":
    discard DownloadManager.GetChapterSequence(novelObj)
    let mdataList: seq[metaDataList] = @[
      (metaType: MetaType.dc, name: "title", attrs: @[("id", "title")], text: novelObj.metaData.name),
      (metaType: MetaType.dc, name: "creator", attrs: @[("id", "creator")], text: novelObj.metaData.author),
      (metaType: MetaType.dc, name: "language", attrs: @[], text: "?"),
      (metaType: MetaType.dc, name: "identifier", attrs: @[("id", "pub-id")], text: ""),
      (metaType: MetaType.meta, name: "", attrs: @[("property", "dcterms:modified")], text: getDateStr()),
      (metaType: MetaType.dc, name: "publisher", attrs: @[], text: "animedl")]
    var epb: EPUB3 = CreateEpub3(mdataList, "./" & novelObj.metaData.name)
    #discard epb.StartEpubExport("./" & novelObj.metaData.name) (DEPRECATED)
    for chapter in novelObj.chapters[0..1]:
      echo chapter.name & " " & chapter.uri
      var nodes = DownloadManager.GetNodes(novelObj, chapter)
      echo $nodes.len & " Nodes"
      for node in nodes:
        for image in node.images:
          echo "Image: " & image.name
      AddGenPage(epb, chapter.name, nodes)
    FinalizeEpub(epb)
    check fileExists("./Komi-San Wa Komyushou Desu.epub")
  test "MetaData object for Himitsu ni shiro yo!! is correct":
    novelObj = GenerateNewNovelInstance("MangaKakalot", "https://mangakakalot.com/manga/ak928973")
    novelObj.metaData = DownloadManager.GetMetaData(novelObj)
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
    discard DownloadManager.GetChapterSequence(novelObj)
    let mdataList: seq[metaDataList] = @[
      (metaType: MetaType.dc, name: "title", attrs: @[("id", "title")], text: novelObj.metaData.name),
      (metaType: MetaType.dc, name: "creator", attrs: @[("id", "creator")], text: novelObj.metaData.author),
      (metaType: MetaType.dc, name: "language", attrs: @[], text: "?"),
      (metaType: MetaType.dc, name: "identifier", attrs: @[("id", "pub-id")], text: ""),
      (metaType: MetaType.meta, name: "", attrs: @[("property", "dcterms:modified")], text: getDateStr()),
      (metaType: MetaType.dc, name: "publisher", attrs: @[], text: "animedl")]
    var epb: EPUB3 = CreateEpub3(mdataList, "./" & novelObj.metaData.name)
    #discard epb.StartEpubExport("./" & novelObj.metaData.name)
    for chapter in novelObj.chapters:
      echo chapter.name & " " & chapter.uri
      var nodes = DownloadManager.GetNodes(novelObj, chapter)
      echo $nodes.len & " Nodes"
      for node in nodes:
        for image in node.images:
          echo "Image: " & image.name
      AddGenPage(epb, chapter.name, nodes)
    FinalizeEpub(epb)
      #discard epb.AddPage(GeneratePage(nodes, chapter.name))
    #discard epb.EndEpubExport("001001", "ADLCore", "")
    check fileExists("./Himitsu ni shiro yo!!.epub")
