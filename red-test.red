Red []

do %lexer.red
do %syntax.red

file: %testx.red
code: read file
probe red-lexer/analysis file code
probe red-syntax/analysis file red-lexer/words-table
