import std/strutils
type
    Status* {.pure.} = enum
        Active = "Active", Hiatus, Dropped, Complete
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

proc sanitizeString*(str: string): string =
  var oS = str
  removePrefix(oS, '\n')
  removePrefix(oS, ' ')
  removeSuffix(oS, '\n')
  removeSuffix(oS, ' ')
  var newStr: string = ""
  for chr in oS:
    if ord(chr) >= 32 and ord(chr) <= 126 or chr == '\n': # Preserve newLn
      newStr.add(chr)
  return newStr