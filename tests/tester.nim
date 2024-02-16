import ADLCore
import sugar
import unittest

var ctx: DownloaderContext
suite "Novel/NovelHall":
    test "Instance Creation":
        ctx = generateContext("www.novelhall.com", "https://www.novelhall.com/333under-the-oak-tree2022-15910/")
        check ctx != nil
        check (not isNil(ctx))
    test "MetaData":
        ctx.setMetadata()
        var vol: Volume
        vol = ctx.sections[^1]
        check vol.mdat.name == "Under the Oak Tree"
        check vol.mdat.author == "Sooji Kim"
suite "Video/Embtaku":
    test "Instance Creation":
        ctx = generateContext("embtaku.pro", "https://embtaku.pro/videos/majo-to-yajuu-episode-6")
        check ctx != nil
        check (not isNil(ctx))
    test "MetaData":
        var vol: Volume
        ctx.setMetadata()
        vol = ctx.sections[^1]
        check vol.mdat.name == "Majo to Yajuu Episode 6 English Subbed"
        check vol.mdat.series == "Majo to Yajuu"
        check vol.mdat.description == "Guideau a feral girl with long fangs and the eyes of a beast Ashaf a softspoken man with delicate features and a coffin strapped to his back This ominous pair appears one day in a town thats in thrall to a witch who has convinced the townsfolk shes their hero But Ashaf and Guideau know better They have scores to settle and they wont hesitate to remove anyone in their way"
    test "Sequence Gathering":
        ctx.setParts()
        check ctx.sections[ctx.index].parts.len > 0
    test "Stream Gathering":
        ctx.setContent()
        let section = ctx.sections[ctx.index]
        let parts = section.parts
        check parts[section.index].mainStream.subStreams.len > 0