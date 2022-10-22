import std/strutils

type
  InfoTuple* = tuple[name: string, scraperType: string, version: string,
  projectUri: string, siteUri: string]

type
    Status* {.pure.} = enum
        Active = "Active", Hiatus = "Hiatus", Dropped = "Dropped", Completed = "Completed"
    LanguageType* = enum
        original, translated, machine, mix, unknown
    MetaData* = ref object of RootObj
        name*: string
        series*: string
        author*: string
        rating*: string
        genre*: seq[string]
        novelType*: string
        uri*: string
        description*: string
        languageType*: LanguageType
        statusType*: Status
        coverUri*: string
    SourceObj* = ref object of RootObj
        bkUp: bool
        uri: string
        resolution: string
proc `$`*(this: MetaData): string =
  return "name:$1\nseries:$2\nauthor:$3\nrating:$4\ngenre:$5\nnovelType:$6\nuri:$7\ndescription:$8\nlanguageType:$9\n" %
    [this.name, this.series, this.author, this.rating, $this.genre, this.novelType, this.uri, this.description, $this.languageType] &
    "statusType:$1\ncoverUri:$2" % [$this.statusType, this.coverUri]
proc sanitizeString*(str: string): string =
  var oS = str
  removePrefix(oS, '\n')
  removePrefix(oS, ' ')
  removeSuffix(oS, '\n')
  removeSuffix(oS, ' ')
  var newStr: string = ""
  for chr in oS:
    if chr >= '0' and chr <= '9' or chr >= 'A' and chr <= 'Z' or chr >= 'a' and chr <= 'z' or chr == ' ' or chr == '\n': # Preserve newLn
      newStr.add(chr)
  return newStr