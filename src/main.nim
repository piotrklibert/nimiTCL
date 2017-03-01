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
    echo [eval $x]
    f asdasdasdsa
"""

for cmd in tclParse(testString):
  echo $(tclEval(cmd))
