import ./ADLCore/Novel/NovelTypes
import ./ADLCore/Novel/NovelHall
import./ADLCore/Video/VidStream
import HLSManager
import strutils
import std/terminal
import std/[os, strutils, asyncdispatch, base64]
import nimcrypto
proc onProgressChanged(total, progress, speed: BiggestInt) {.async,cdecl.} =
    echo("Downloaded ", progress, " of ", total)
    echo("Rate: ", speed, "b/s")

#echo "Making Object"
#var NHall = NovelHall()
#waitFor NHall.Init("https://www.novelhall.com/I-Become-Invincible-By-Signing-In-25249/")
#echo "Getting MetaData"
#waitFor NHall.SetMetaData()
#echo "Author: " & NHall.novel.metaData.author
#echo "Description: " & NHall.novel.metaData.description
#echo "Getting Chapter Sequence"
#waitFor NHall.GetChapterSequence(onProgressChanged)
#let b = NHall.chapters
#let d = waitFor NHall.GetChapterNodes(NHall.chapters[0])
#assert len(d) > 10
#echo "Found $1 Chapters From NovelHall" % [$len(b)]

var vidyaStream = VidStream()
waitFor vidyaStream.Init("https://gogoplay1.com/videos/koi-wa-sekai-seifuku-no-ato-de-episode-1")
waitFor vidyaStream.SetHLSStream()

for param in vidyaStream.stream.parts:
    echo "header: $1" % [param.header]
    for val in param.values:
        echo "  Key: $1\n   Value: $2" % [val.key, val.value]