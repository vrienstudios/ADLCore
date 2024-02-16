import std/[base64, strutils]
import nimcrypto
import checksums/md5
import std/[httpclient, htmlparser, xmltree, strutils, strtabs, parseutils, sequtils]

# AES-256 sizes; _password in plaintext form, and _salt in byte form.
proc evp_BytesToKey*(passwordz, saltz: string): tuple[key, iv: string] =
  var password: string = passwordz
  var salt: string = saltz

  var passwordBytes = newString(len(password))

  let pSize: int = len(password)
  let sSize: int = len(salt)

  copyMem(addr passwordBytes[0], addr password[0], pSize)
  
  var hashes: seq[uint8] = @[]
  var currentHash: MD5Digest
  var hasher: string = newString(pSize + sSize)
  
  copyMem(addr hasher[0], addr passwordBytes[0], pSize)
  copyMem(addr hasher[len(passwordBytes)], addr salt[0], sSize)
  currentHash = toMD5(hasher)
  hashes.add currentHash[0..^1]

  while len(hashes) < 48: # Key (32) + IV (16)
    let cSize: int = len(currentHash)
    hasher = newString(cSize + pSize + sSize)
    copyMem(addr hasher[0], addr currentHash[0], cSize)
    copyMem(addr hasher[cSize], addr passwordBytes[0], pSize)
    copyMem(addr hasher[cSize + pSize], addr salt[0], sSize)
    currentHash = toMD5(hasher)
    hashes.add currentHash[0..^1]

  var key: string = newString(32)
  var iv: string = newString(16)
  copyMem(addr key[0], addr hashes[0], 32)
  copyMem(addr iv[0], addr hashes[32], 16)
  return (key, iv)
# Incomplete
proc padPKSC7*(data: string): string =
  var 
    outString: string = newString(aes256.sizeBlock)
    padLen: int = aes128.sizeBlock - (len(data) mod aes128.sizeBlock)
    padding: byte = byte padLen
    idx: int = 0
  copyMem(addr outString[0], addr data[0], len(data))
  while idx < padLen:
    copyMem(addr outString[len(data) + idx], addr padding, 1)
    inc idx
  return outString
  
proc aes256Decrypt(data, password: string): string =
  assert len(data) > 0
  assert len(password) > 0
  
  var dSplit = data.split("__")
  let salt = dSplit[1][0..7]
  let cipher = dSplit[1][8..^1]
  
  assert len(dSplit) > 1

  var dContext: CBC[aes256]
  var decryptedText = newString(len(cipher))
  var kIV = evp_BytesToKey(password, salt)

  dContext.init(kIV.key, kIV.iv)
  dContext.decrypt(cipher, decryptedText)
  dContext.clear()
  return decryptedText
proc aes256Decrypt(data, key, iv: string): string =
  assert key.len == aes256.sizeKey
  assert iv.len == aes256.sizeBlock
  assert data.len > 0
  
  var 
    dContext: CBC[aes256]
    outStr: string
  dContext.init(key, iv)
  dContext.decrypt(data, outStr)
  return outStr
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
    if b.attrs == nil:
      return true
    if a.kind == xnElement:
      # Text comparison can happen somewhere else
      if attrEquivalenceCheck(a, b) and a.tag == b.tag:
        return true
  return false
proc recursiveNodeSearch*(x: XmlNode, n: XmlNode): XmlNode =
  if x == nil:
    return nil
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