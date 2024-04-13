# Site: https://www.braflix.app/
import ../context

iterator braflixGetChapter(this: var DownloaderContext, l, h: int): Chapter =
  setPage(this, this.defaultPage)
  var videoList: XmlNode =
    recursiveNodeSearch(this.page, parseHtml("<div class=\"mt-16\">"))
  var mdata: MetaData = MetaData()
  mdata.name = $videoList
  yield Chapter(metadata: mdata)
proc loadEmbtakuMetadata(this: var DownloaderContext) =
  setPage(this, this.defaultPage)
  var 
    meta: MetaData = MetaData()
    videoInfoPanel: XmlNode
 
  var vol = Volume(mdat: meta, lower: -1, upper: -1)
  this.sections.add vol

# Add self
downloaderList.add ("braflix", "text", @[("metadata", nil), ("parts", nil), ("search", nil), ("content", nil)])
siteList.add Site(identifier: "braflix", baseUri: "www.braflix.app", uriList: @["https://www.braflix.app", "https://www.braflix.app", "braflix", "braflix.app", "www.braflix.app"])