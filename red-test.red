Red []

do %system-words.red
do %lexer.red
do %syntax.red


file: %testx.red
code: read file
code-analysis: clear []
code-analysis: red-lexer/analysis code
probe red-syntax/analysis code-analysis
forall code-analysis [
    probe code-analysis/1
]
