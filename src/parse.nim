import streams, strutils, sequtils
import streamutils

const
  commandSeparators = {';', '\l', '\r'}
  specialChars = {'{' , '}' , ';' , '\l' , '\r', '[', ']', '"', ' ', '$'}
  quotedSpecialChars = {'$', '[', '"'}

type
  ExprType* = enum
    Command, Substitution, Word, StringChunk, Quotation, Variable, Comment, Empty

  Expr* = ref ExprObj not nil
  ExprObj {. acyclic .} = object
    case eType*: ExprType
    of Empty: discard
    of Word:         wBody*: seq[Expr]
    of Command:      cBody*: seq[Expr]
    of StringChunk:  str*: string
    of Quotation:    qBody*: string
    of Substitution: subBody*: string
    of Comment:      content*: string
    of Variable:     varName*: string

proc `$`*(e: Expr) : string =
  case e.eType
  of Empty:        return "EmptyToken"
  of StringChunk:  return e.str
  of Quotation:    return "{Q:" & e.qBody & "}"
  of Substitution: return "[S:" & e.subBody & "]"
  of Word:         return "Str: '" & e.wBody.map(`$`).join("") & "'"
  of Comment:      return "<comment>"
  of Variable:     return "Var: " & e.varName
  of Command:      return "<Cmd: [" & e.cBody.map(`$`).join(", ") & "]>"


type Parser* = object
  insideQuotes: bool
  stream: StringStream



proc init*(p: var Parser, source: string) = p.stream = newStringStream(source)
proc initParser*(source: string): Parser = result.stream = newStringStream(source)

# Utilities and shortcuts for convenience and readability
proc peekChar(p: var Parser): char = p.stream.peekChar()
proc readChar(p: var Parser): char = p.stream.readChar()
proc discardChar(p: var Parser) = discard p.stream.readChar()
proc readUntil(p: var Parser, m: set[char], l: bool = false): string = p.stream.readUntil(m, l)
proc readWhile(p: var Parser, m: set[char]): string = p.stream.readWhile(m)
proc readBalanced(p: var Parser, s,e: char): string = p.stream.readBalanced(s,e)

proc skipComment(p: var Parser) : var Parser {. discardable .} =
  if p.peekChar() == '#': discard p.readUntil({'\l', '\r'}, true)
  return p

proc skipWhitespace(p: var Parser) : var Parser {. discardable .} =
  while p.peekChar() in {' '}: p.discardChar()
  return p

proc skipAndPeek(p: var Parser): char =
  p.skipWhitespace().skipComment().peekChar()


# Parsing logic
proc parseAtom(p: var Parser): Expr;

proc parseStringChunk(p: var Parser): Expr =
  result = Expr(eType: StringChunk)
  case p.insideQuotes
  of true:  result.str = p.readUntil(quotedSpecialChars, true)
  of false: result.str = p.readUntil(specialChars, true)

proc parseQuotedString(p: var Parser): Expr =
  p.discardChar()
  p.insideQuotes = true
  defer: p.insideQuotes = false
  var res: seq[Expr] = @[]
  while p.peekChar() != '"':
    if p.peekChar() == StopChar:
      raise newException(ValueError, "Unterminated string")
    res.add(p.parseAtom())
  p.discardChar()
  return Expr(eType: Word, wBody: res)

proc parseQuotation(p: var Parser): Expr =
  Expr(eType: Quotation, qBody: p.readBalanced('{', '}'))

proc parseSubstitution(p: var Parser): Expr =
  Expr(eType: Substitution, subBody: p.readBalanced('[', ']'))

proc parseVariable(p: var Parser) : Expr =
  p.discardChar()     # drop '$'
  let name = p.readUntil(specialChars, true)
  Expr(eType: Variable, varName: name)

proc parseAtom(p: var Parser): Expr =
  case p.peekChar()
  of '"': p.parseQuotedString()
  of '[': p.parseSubstitution()
  of '{': p.parseQuotation()
  of '$': p.parseVariable()
  else:   p.parseStringChunk()

proc parseWord(p: var Parser): Expr =
  p.skipWhitespace()
  var chunks: seq[Expr] = @[]
  while p.peekChar() notin {' ', '\l', '\r', StopChar}:
    chunks.add(p.parseAtom())
  return Expr(eType: Word, wBody: chunks)

proc parseCommand(p: var Parser) : Expr =
  var args = @[p.parseWord()]
  if len(args[0].wBody) == 0: return Expr(eType: Empty)
  while p.skipAndPeek() notin ({StopChar} + commandSeparators):
    args.add(p.parseWord())
  Expr(eType: Command, cBody: args)

proc parse(p: var Parser): seq[Expr] =
  result = @[]
  while p.skipWhitespace().skipComment().peekChar() != StopChar:
    result.add(p.parseCommand())
    discard p.stream.readChar()   # either commandSeparator or end of input

proc tclParse*(input: string): seq[Expr] =
  var p = initParser(input)
  p.parse()
