var registeredCommands: TclTable[TclCmd] = newTable[string, TclCmd]()

template defcmd(cmdName: string, procName, body: untyped): untyped =
  proc procName(c: TclContext, a: seq[TclValue]): TclValue =
    var ctx {. inject .} = c    # for some reason the inject pragma doesn't work
    var args {. inject .} = a   # in proc formal params list
    body
  registeredCommands[cmdName] = procName

defcmd("not", cmdNot): (if args[0] == Null: True else: Null)

defcmd("while", cmdWhile):
  if len(args) != 2: return Null
  while ctx.eval(args[0]) != Null:
    result = ctx.eval(args[1])

defcmd("eval", cmdEval):
  if len(args) < 1: return Null
  return ctx.eval(args[0])

defcmd("proc", cmdProc):
  if len(args) != 3: return Null
  let
    procName = args[0].data
    procClosure =
      proc (innerCtx: TclContext, innerArgs: seq[TclValue]): TclValue =
        let argNames = args[1].data.split(" ")
        let ctx = innerCtx.copy()
        ctx.setVars(zip(argNames, innerArgs))
        result = ctx.eval(args[2])
  ctx.cmds.add(procName, procClosure)
  Null

defcmd("set", cmdSetVar):
  if len(args) == 1: return ctx.vars[args[0].data]
  elif len(args) != 2: return Null
  let name = args[0].data
  ctx.vars[name] = args[1]
  return args[1]

defcmd("concat", cmdConcat):
  result = newValue()
  for v in args:
    result.data &= v.data

defcmd("return", cmdReturn):
  var e = newException(TclReturn, "")
  e.val = args[0]
  raise e

defcmd("echo", cmdEcho):
  for arg in args: stdout.write(arg.data)
  stdout.write("\n")
  Null

defcmd("cmp", cmdCmp):
  if len(args) != 2: return Null
  return (if args[0] != args[1]: Null else: True)

defcmd("if", cmdIf):
  if len(args) notin {2, 3}: return Null
  if args[0] == True: return ctx.eval(args[1])
  else: return (if len(args) == 3: ctx.eval(args[2]) else: Null)

defcmd("help", cmdHelp):
  for k in registeredCommands.keys(): echo $k
  Null
