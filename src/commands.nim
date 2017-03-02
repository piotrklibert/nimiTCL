var registeredCommands: TclTable[TclCmd] = newTable[string, TclCmd]()

template defcmd(cmdName: string, procName, body: untyped): untyped =
  proc procName(c: TclContext, a: seq[TclValue]): TclValue =
    var ctx {. inject .} = c    # for some reason the inject pragma doesn't work
    var args {. inject .} = a   # in proc formal params list
    body
  registeredCommands[cmdName] = procName

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
  if len(args) != 2: return Null
  let name = args[0].data
  ctx.vars[name] = args[1]
  return args[1]

defcmd("concat", cmdConcat):
  result = newValue()
  for v in args:
    result.data &= v.data


defcmd("echo", cmdEcho):
  for arg in args: stdout.write(arg.data)
  stdout.write("\n")
  Null

defcmd("cmp", cmdCmp):
  if len(args) != 2: return Null
  if args[0] != args[1]: return Null
  return True

defcmd("if", cmdIf):
  if len(args) notin {2, 3}: return Null
  if args[0] == True: return ctx.eval(args[1])
  else: return (if len(args) == 3: ctx.eval(args[2]) else: Null)
