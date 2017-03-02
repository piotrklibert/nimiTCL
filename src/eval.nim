import tables, sequtils, strutils
import parse

type
  TclTable[T] = TableRef[string, T]
  TclCmd = proc (ctx: TclContext, args: seq[TclValue]): TclValue
  TclValue = ref object of RootObj
    data: string

  TclContext = ref object
    vars: TclTable[TclValue]
    cmds: TclTable[TclCmd]


proc newValue(s: string = ""): TclValue =
  result = new(TclValue)
  result.data = s

proc `$`*(v: TclValue) : string = $(v.data)
proc `==`*(a,b: TclValue): bool = a.data == b.data

proc newContext*(): TclContext =
  new(result)
  result.vars = newTable[string, TclValue]()
  result.cmds = newTable[string, TclCmd]()

proc copy*(ctx: TclContext): TclContext = result.deepCopy(ctx)

proc eval*(ctx: TclContext, e: Expr): TclValue # the most primitive kind of eval
proc eval*(ctx: TclContext, s: string): TclValue =
  for expression in tclParse(s):
    result = ctx.eval(expression)
proc eval(ctx: TclContext, v: TclValue): TclValue = ctx.eval(v.data)
proc eval(ctx: TclContext, e: Expr): TclValue =
  result = newValue()
  case e.eType
  of Command:
    let cmdName = ctx.eval(e.cBody[0]).data
    try:
      let cmdProc = ctx.cmds[cmdName]
      result.data = cmdProc(ctx, e.cBody[1 .. ^1].map(proc (x: Expr): TclValue = ctx.eval(x))).data
    except KeyError:
      result.data = "unknown command: " & cmdName
  of Variable:
    if ctx.vars.hasKey(e.varName):
      result.data = ctx.vars[e.varName].data
  of Substitution:
    for ex in e.subBody.tclParse():
      result.data = ctx.eval(ex).data
  of Word:
    for ex in e.wBody:
      result.data &= ctx.eval(ex).data
  of Quotation: result.data = e.qBody
  of StringChunk: result.data = e.str
  else: discard

proc setVars(ctx: TclContext, vars: seq[(string, TclValue)]) =
  for v in vars: ctx.vars[v[0]] = v[1]

let
  Null* = newValue()
  True* = newValue("true")
var baseContext = newContext()
include "commands"
baseContext.cmds = registeredCommands
proc getContext*(): TclContext = baseContext.copy()
proc eval*(s: string): TclValue = getContext().eval(s)
