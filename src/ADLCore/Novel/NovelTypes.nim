import EPUB/Types/genericTypes
import ../genericMediaTypes

type
    Chapter* = ref object of RootObj
        name*: string
        number*: int
        uri*: string
        contentSeq*: seq[TiNode]
    Novel* = ref object of RootObj
        metaData*: MetaData
        lastModified*: string