Red []
#include %system-words.red

words: system-words/system-words

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