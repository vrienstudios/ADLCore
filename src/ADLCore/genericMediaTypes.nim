type
    Status* {.pure.} = enum
        Active = "Active", Hiatus, Dropped, Complete
    LanguageType* = enum
        original, translated, machine, mix, unknown
    MetaData* = ref object of RootObj
        name*: string
        author*: string
        rating*: string
        genre*: seq[string]
        novelType*: string
        uri*: string
        description*: string
        languageType*: LanguageType
        statusType*: Status
        coverUri*: string
    SourceObj = ref object of RootObj
        bkUp: bool
        uri: string
        resolution: string