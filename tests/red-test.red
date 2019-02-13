Red []

#include %../error.red
#include %../lsp-const.red
;#include %../json.red
#include %../system-words.red
#include %../lexer.red
#include %../syntax.red


file: %testx.red
code: read file
code-analysis: clear []
code-analysis: red-lexer/analysis code
red-syntax/analysis code-analysis
print red-syntax/format code-analysis


print "Error/Warning: ---------------------------------------"
probe red-syntax/collect-errors code-analysis

if pos: red-syntax/position? code-analysis 12 1 [
    probe pos/1/range
]
probe red-syntax/collect-completions code-analysis "f" 12 1
