import ADLCore, ADLCore/Novel/NovelTypes, ADLCore/genericMediaTypes, ADLCore/Novel/MangaKakalot
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
  test "MetaData object for The Angel Next Door Spoils Me Rotten is correct":
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

