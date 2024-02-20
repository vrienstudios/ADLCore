import ADLCore
import sugar
import unittest
import strutils

var 
    ctx: DownloaderContext
    vol: Volume
suite "Video/HAnime":
    test "Instance Creation":
        ctx = generateContext("hanime.tv", "https://hanime.tv/videos/hentai/doukyo-suru-neneki-1")
        check not ctx.isNil
    test "MetaData":
        check ctx.setMetadata()
        vol = ctx.section
        assert vol != nil
        check vol.mdat.series == "Doukyo Suru Neneki"
    test "Sequence Gathering":
        check ctx.setParts()
        for chapter in ctx.walkChapters():
            check chapter.metadata.series == vol.mdat.series
    test "Stream Gathering":
        check ctx.doPrep()
        echo $ctx.chapter.mainStream
assert ctx == nil
suite "Novel/NovelHall":
    test "Instance Creation":
        ctx = generateContext("www.novelhall.com", "https://www.novelhall.com/333under-the-oak-tree2022-15910/")
        check ctx != nil
        check (not isNil(ctx))
    test "MetaData":
        check ctx.setMetadata()
        vol = ctx.section
        check vol.mdat.name == "Under the Oak Tree"
        check vol.mdat.author == "Sooji Kim"
suite "Video/Embtaku":
    test "Instance Creation":
        ctx = generateContext("embtaku.pro", "https://embtaku.pro/videos/majo-to-yajuu-episode-6")
        check ctx != nil
        check (not isNil(ctx))
    test "MetaData":
        var vol: Volume
        check ctx.setMetadata()
        vol = ctx.section
        check vol.mdat.name == "Majo to Yajuu Episode 6 English Subbed"
        check vol.mdat.series == "Majo to Yajuu"
        check vol.mdat.description == "Guideau a feral girl with long fangs and the eyes of a beast Ashaf a softspoken man with delicate features and a coffin strapped to his back This ominous pair appears one day in a town thats in thrall to a witch who has convinced the townsfolk shes their hero But Ashaf and Guideau know better They have scores to settle and they wont hesitate to remove anyone in their way"
    test "Sequence Gathering":
        check ctx.setParts()
        check ctx.section.parts.len > 0
    test "Stream Gathering":
        check ctx.doPrep()
        check ctx.section.parts[0].mainStream.subStreams.len > 0