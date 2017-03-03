import parse, eval

const testString* = """
    set a "str1"
    set b [concat -- $a"-str2" longer_str_3]
    $a$b 13                                  # a comment, will be ignored
    proc f {a} {
        echo $a
    }
    set x {
        echo "Evaling x!"
        concat [concat a b] {c} "d"
    }
    if [cmp [eval $x] abcd] {
        echo "Good."
    } {
        echo "Bad."
    }
    if [cmp 99 99] {echo "99 does equal 99"}
    if true {
        echo "It was true!"
    }
    if "" {} {echo "It was false!"}
    f "Calling a command"
    if [cmp $a "str1"] {echo "a value: $a"}
    set b "a"
    while {not [cmp $b "aaaaaaaaaaa"]} {
        echo Iterating: $b
        set b [concat $b "a"]
    }
    proc ff {} {
        echo "Inside `ff`"
        return "asd"
        echo "Won't get here!"
    }
    ff
"""

let ctx = getContext()
for cmd in tclParse(testString):
  let val = ctx.eval(cmd)
  if val != Null: echo $(val)

while true:
  stdout.write("> ")
  try:
    let res = $(ctx.eval(stdin.readLine()))
    if res != "": echo res
  except IOError:
    echo "Exiting."
    break
