import ./ADLCore/Novel/NovelTypes
import ./ADLCore/Novel/NovelHall
import./ADLCore/Video/VidStream
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

var KEY: string = "37911490979715163134003223491201"
var IV: string = "3134003223491201"
var DATA: string = "MTg0MDcw"

var ectx, dctx: CBC[aes256]
var key = newString(aes256.sizeKey)
var iv = newString(aes256.sizeBlock)
var plainText = newString(aes256.sizeBlock * 2)
var encText = newString(aes256.sizeBlock * 2)

var padLen: int = aes128.sizeBlock - (len(DATA) mod aes128.sizeBlock)
echo padLen
var padding: byte = byte padLen
var idx: int = 0
copyMem(addr plainText[0], addr DATA[0], len(DATA))
while idx < padLen:
  copyMem(addr plainText[len(DATA) + idx], addr padding, 1)
  inc idx
copyMem(addr key[0], addr KEY[0], len(KEY))
copyMem(addr iv[0], addr IV[0], len(IV))
ectx.init(key, iv)
ectx.encrypt(plainText, encText)
var nString: string = newString(22)
var pText: seq[byte] = @(encText.toOpenArrayByte(0, encText.len-17))

echo "ENCODED TEXT: ", encode(pText)
#var context: CBC[aes128]
#setLen(KEY, 32)
#setLen(IV, 16)
#context.init(KEY, IV)
#setLen(DATA, aes128.sizeBlock * 2)
#var str: string = newString(aes128.sizeBlock * 2)
#context.decrypt(DATA, str)
#context.clear()
#echo encode(str)
##HnmXzfwvnoGnH7UDXCs6j67ZskBJLBLWuQe17urFKRM=
#
#
#echo KEY
#echo IV
#echo DATA
#setLen(DATA, 16)
#
#var context: CBC[aes128]
#var text: string = newString(16)
#context.init(KEY.toOpenArrayByte(0, KEY.len-1), IV.toOpenArrayByte(0, IV.len-1))
#var oua: seq[byte] = @[byte 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0]
#context.decrypt(DATA.toOpenArrayByte(0, DATA.len-1), oua)
#for b in oua:
#  echo b
#echo len(oua)
#echo encode(oua)
#var owa: seq[byte] = @[byte 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0]
#context.init(KEY, IV)
#context.encrypt(oua[0..15], owa)
#echo len(owa)
#echo encode(owa)

#rocQ6Au42n5Jwk6wHGeuig==

#var dctx: CBC[aes256]
#var idx: int = 0
#var dText: string = newString(len(dataKey))
#dctx.init(bodyKey, wrapperIV)
#dctx.decrypt(dataKey, dText)
#let bodyUri = dText.split('&')
#dctx.init(bodyKey, wrapperIV)
#var mID: string
#mID = bodyUri[0]
#setLen(mID, 16)
#echo bodyKey
#echo wrapperIV
#var rawID: string = newString(len(mID))
#dctx.encrypt(mID, rawID)
#echo len(rawID)
##setLen(rawID, 8)
#echo encode(rawID)

#rocQ6Au42n5Jwk6wHGeuig==

#var vidyaStream = VidStream()
#waitFor vidyaStream.Init("https://gogoplay1.com/videos/koi-wa-sekai-seifuku-no-ato-de-episode-1")
#waitFor vidyaStream.SetHLSStream()