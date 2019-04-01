Red []
#include %system-words.red

words: [
    ?? as assert size? if either case switch until while loop any all exit return break continue catch declare use null context with comment true false func function alias
]

result: clear ""
append result "("
forall words [
    str: to string! words/1
    replace/all str "\" "\\\\"
    replace/all str "?" "\\?"
    replace/all str "*" "\\*"
    replace/all str "." "\\."
    replace/all str "+" "\\+"
    replace/all str "|" "\\|"
    replace/all str "$" "\\$"
    replace/all str "^^" "\\^^"
    append result str
    append result "|"
]
remove back tail result
append result ")"
print result