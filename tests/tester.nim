import ADLCore
import sugar
import unittest

proc isNil(ctx: DownloaderContext): bool =
    return (ctx.setMetadata == nil or ctx.setSearch == nil or ctx.setParts == nil or ctx.setContent == nil)
suite "Video/Embtaku":
    var ctx: DownloaderContext
    test "Instance Creation":
        ctx = generateContext("embtaku.pro")
        check ctx != nil
        check isNil(ctx) == false
    ctx.defaultPage = "https://embtaku.pro/videos/majo-to-yajuu-episode-6"
    ctx.baseUri = "https://embtaku.pro/"
    test "MetaData":
        var vol: Volume
        ctx.setMetadata(ctx)
        vol = ctx.sections[^1]
        check vol.mdat.name == "Majo to Yajuu Episode 6 English Subbed"
        check vol.mdat.series == "Majo to Yajuu"
        check vol.mdat.description == "Guideau a feral girl with long fangs and the eyes of a beast Ashaf a softspoken man with delicate features and a coffin strapped to his back This ominous pair appears one day in a town thats in thrall to a witch who has convinced the townsfolk shes their hero But Ashaf and Guideau know better They have scores to settle and they wont hesitate to remove anyone in their way"
    test "Sequence Gathering":
        ctx.setParts(ctx)
        check ctx.sections[ctx.index].parts.len > 0
    test "Stream Gathering":
        ctx.setContent(ctx)
        let section = ctx.sections[ctx.index]
        let parts = section.parts
        check parts[section.index].mainStream.subStreams.len > 0