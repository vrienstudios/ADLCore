import std/[base64, strutils]
import nimcrypto
import checksums/md5

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
proc padPKSC7(data: string, padding: byte, paddingLength: int): string
  var plain: string = newString(1)
  var idx: int = 0
  while idx < paddingLength:
    copyMem(addr plain[len(data) + idx], addr padding, 1)
    inc idx
  return plain
  
proc aes256Decrypt(data, password: string): string =
  assert len(data) > 0
  assert len(password) > 0
  
  var dSplit = data.split("__")
  let salt = dSplit[1][0..7]
  let cipher = dSplit[1][8..^1]
  
  assert len.dSplait > 1

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
  
  var dContext: CBC[aes256]
  dContext.init(key, iv)
  dContext.decrypt()
  