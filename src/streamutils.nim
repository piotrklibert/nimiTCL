import streams
import strutils

const StopChar* = '\0'

proc readWhile*(stream: var StringStream, match: set[char]) : string =
  result = ""
  while stream.peekChar() != StopChar:
    let c = stream.readChar()
    if c notin match: break
    result.add(c)

proc readUntil*(stream: var StringStream, match: set[char],
               leaveLast: bool = false): string =
  result = ""
  while stream.peekChar() != StopChar and stream.peekChar() notin match:
    result.add(stream.readChar())
  if not leaveLast:
      discard stream.readChar()

proc readBalanced*(stream: var StringStream, startChar, endChar: char) : string =
  assert stream.peekChar() == startChar
  discard stream.readChar()
  var lvl = 1
  result = newStringOfCap(200)  # resizing should be less frequent thanks to this
  while lvl > 0:
    let c = stream.readChar()
    if c == StopChar:
      let msg = "Unbalanced %s, %s" % [$startChar, $endChar]
      raise newException(ValueError, msg)
    lvl += (if c == startChar: 1 elif c == endChar: -1 else: 0)
    if lvl != 0: result.add(c)
