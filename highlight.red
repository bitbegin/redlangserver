Red []
#include %system-words.red

to-regex: func [words [block!]][
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
]

print "Red words: "
print to-regex system-words/get-words no
print "Red/System words: "
print to-regex system-words/get-words yes
