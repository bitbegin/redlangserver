Red []

#include %error.red
#include %lsp-const.red
;#include %json.red
#include %system-words.red
#include %lexer.red
#include %syntax.red


file: %testx.red
code: read file
code-analysis: clear []
code-analysis: red-lexer/analysis code
red-syntax/analysis code-analysis
forall code-analysis [
    probe code-analysis/1
]
