import parse, eval

const testString* = """
    set a "zzz"
    set b [concat $a"-1" asdasdasd]
    $a$b 13 # sdfadf
    proc f {a} {echo $a}
    set x {
        concat [concat 3 4] {
           99
        }
    }
    if [cmp 99 99] {echo "99 does equal 99"}
    if true {
        echo "It was true!"
    }
    if "" {} {
        echo "It was false!"
    }
    f "Calling a command"
"""

for cmd in tclParse(testString):
  let val = tclEval(cmd)
  if val != Null: echo $(val)
