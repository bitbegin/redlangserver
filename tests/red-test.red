Red []

#include %../error.red
#include %../lsp-const.red
;#include %../json.red
#include %../system-words.red
#include %../ast.red
#include %../semantic.red


file: %testx.red
code: read file
code-ast: clear []
code-ast: ast/analysis code
semantic/analysis code-ast
print semantic/format code-ast


print "Error/Warning: ---------------------------------------"
probe semantic/collect-errors code-ast

;ret: red-syntax/collect-completions code-ast red-syntax/position? code-ast 17 5

;print red-syntax/format ret
