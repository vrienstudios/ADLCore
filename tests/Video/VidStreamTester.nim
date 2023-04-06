import ADLCore
import ADLCore/DownloadManager, ADLCore/genericMediaTypes
import unittest, std/[os, strutils]

suite "Video/VidStream":
  var videoObj: Video
  var resolutions: seq[MediaStreamTuple]
  test "Can generate videoObj":
    videoObj = GenerateNewVideoInstance("vidstreamAni", "https://gogoplay1.com/videos/shine-post-episode-4")
    check videoObj != nil
  test "MetaData object for Shine Post Episode 4 is correct":
    let metaData = GetMetaData(videoObj)
    echo "Name: " & metaData.name
    echo "Series: " & metaData.series
    # uri is empty but the site still works so not checking for that
    echo "uri: " & metaData.uri
    echo "Desc: " & metaData.description
    check metaData.name == "Shine Post Episode 4 English Subbed"
    check metaData.series == "Shine Post"
    check len(metaData.description) != 0
  test "Stage one stream information has at least one resolution":
    var strea = GetStream(videoObj)
    var streamInfCount = 0
    for param in strea.parts:
      echo "header: $1" % [param.header]
      if param.header == "#EXT-X-STREAM-INF:":
        inc streamInfCount
      for val in param.values:
          echo "  Key: $1\n   Value: $2" % [val.key, val.value]
    check streamInfCount > 0
  test "videoObj has at least one resolution":
    resolutions = ListResolutions(videoObj)
    for r in resolutions:
      echo r.resolution
    check resolutions.len > 0
  test "Can select first resolution":
    SelResolution(videoObj, resolutions[0])
  test "Can download a part":
    check DownloadNextVideoPart(videoObj, "./VidStreamTesterPart.ts")
  test "Part file exists":
    check fileExists("./VidStreamTesterPart.ts")
    removeFile("./VidStreamTesterPart.ts")
