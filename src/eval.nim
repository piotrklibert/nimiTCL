import tables,sequtils, strutils
import parse

type
  TclTable[T] = TableRef[string, T]
  TclCmd = proc (ctx: TclContext, args: seq[TclValue]): TclValue
  TclValue = ref object of RootObj
    data: string

  TclContext = ref object
    vars: TclTable[TclValue]
    cmds: TclTable[TclCmd]

proc `$`*(v: TclValue) : string = $(v.data)

proc newValue(s: string = ""): TclValue =
  result = new(TclValue)
  result.data = s

proc newContext(): TclContext =
  new(result)
  result.vars = newTable[string, TclValue]()
  result.cmds = newTable[string, TclCmd]()

proc setVars(ctx: TclContext, vars: seq[(string, TclValue)]) =
  for v in vars: ctx.vars[v[0]] = v[1]

let Null = newValue()
proc tclEval*(e: Expr): TclValue

var ctx = newContext()

template defcmd(cmdName: string, procName, body: untyped): untyped =
  proc procName(c: TclContext, a: seq[TclValue]): TclValue =
    var ctx {. inject .} = c    # for some reason the inject pragma doesn't work
    var args {. inject .} = a   # work in proc formal params list
    body
  ctx.cmds[cmdName] = procName

defcmd("proc", cmdProc):
  if len(args) != 3: return Null
  let
    procName = args[0].data
    procClosure =
      proc (innerCtx: TclContext, innerArgs: seq[TclValue]): TclValue =
        let argNames = args[1].data.split(" ")
        innerCtx.setVars(zip(argNames, innerArgs))
        result = tclEval(tclParse(args[2].data)[0])
        innerCtx.setVars(zip(argNames, repeat(Null, len(argNames)))) # TODO: restore previous values
  ctx.cmds.add(procName, procClosure)
  Null
defcmd("set", cmdSetVar):
  if len(args) != 2: return Null
  let name = args[0].data
  ctx.vars[name] = args[1]
  return args[1]
defcmd("concat", cmdConcat):
  result = newValue()
  for v in args:
    result.data &= v.data
defcmd("eval", cmdEval):
  if len(args) < 1: return Null
  for e in args[0].data.tclParse():
    result = tclEval(e)
defcmd("echo", cmdEcho):
  for arg in args: stdout.write(arg.data)
  stdout.write("\n")
  Null

proc tclEval*(e: Expr): TclValue =
  result = newValue()
  case e.eType
  of Command:
    let cmdName = tclEval(e.cBody[0]).data
    try:
      let cmdProc = ctx.cmds[cmdName]
      result.data = cmdProc(ctx, e.cBody[1 .. ^1].map(tclEval)).data
    except KeyError:
      result.data = "unknown command: " & cmdName
  of Variable:
    if ctx.vars.hasKey(e.varName):
      result.data = ctx.vars[e.varName].data
  of Substitution:
    for ex in e.subBody.tclParse():
      result.data = tclEval(ex).data
  of Word:
    for ex in e.wBody:
      result.data &= tclEval(ex).data
  of Quotation: result.data = e.qBody
  of StringChunk: result.data = e.str
  else: discard
