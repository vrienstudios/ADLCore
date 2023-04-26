import std/strutils
import std/[xmlparser, htmlparser, xmltree, sequtils, parseutils, strutils, strtabs]
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
  var newStr: string = ""
  var idx: int = 0
  for chr in oS:
    inc idx
    if (chr == ' ' or chr == '\n') and
      (oS[if idx >= oS.len - 1: oS.len - 1 else: idx] == ' ' or
      oS[if idx >= oS.len - 1: oS.len - 1 else: idx] == '\n'):
      continue
    if chr >= '0' and chr <= '9' or chr >= 'A' and chr <= 'Z' or chr >= 'a' and chr <= 'z' or chr == ' ' or chr == '\n': # Preserve newLn
      newStr.add(chr)
  return newStr

proc attrEquivalenceCheck*(a, b: XmlNode): bool =
  if a.attrs == nil and b.attrs == nil:
    return true
  if a.attrs == nil or b.attrs == nil:
    return false
  if a.attrs.len != b.attrs.len:
    return false
  for k in a.attrs.keys:
    if b.attrs.hasKey(k):
      if b.attrs[k] == a.attrs[k]:
        continue
    return false
  return true
proc checkEquivalence*(a, b: XmlNode): bool =
  if a.kind == b.kind:
    if a.kind == xnElement:
      # Text comparison can happen somewhere else
      if attrEquivalenceCheck(a, b) and a.tag == b.tag:
        return true
  return false
proc recursiveNodeSearch*(x: XmlNode, n: XmlNode): XmlNode =
  if $x == $n or checkEquivalence(x, n):
    return x
  for item in x.items:
    if $item == $n or checkEquivalence(item, n):
      return item
    if item.kind != xnElement:
      continue
    let ni = recursiveNodeSearch(item, n)
    if ni != nil:
      return ni
  return nil
# Using strings as a workaround of the nnkSym error.
proc SeekNode*(node: string, desiredNode: string): string =
  return $recursiveNodeSearch(parseHtml(node), parseHtml(desiredNode))