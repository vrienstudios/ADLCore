import ADLCore, ADLCore/Novel/NovelTypes, ADLCore/Novel/NovelHall
import ADLCore/Video/VideoType, ADLCore/Video/VidStream, ADLCore/genericMediaTypes
import unittest, std/[os, terminal, strutils]

suite "Novel/NovelHall":
  var novelObj: Novel
  test "Can generate novelObj":
    novelObj = GenerateNewNovelInstance("NovelHall", "https://www.novelhall.com/number-one-lazy-merchant-of-the-beast-world-13138/")
  test "MetaData object for Cruel Young Master, Don't Love Me is correct":
    discard novelObj.getMetaData()
    echo "Name: " & novelObj.metaData.name
    # author is probably escaped so it's empty
    echo "Author: " & novelObj.metaData.author
    # not too sure about url tho
    echo "Uri: " & novelObj.metaData.uri
    echo "Desc: " & novelObj.metaData.description
    echo "Status: " & $novelObj.metaData.statusType
    check novelObj.metaData.name == "Number One Lazy Merchant of the Beast World"
    check len(novelObj.metaData.description) > 0
    check novelObj.metaData.statusType == Status.Complete
