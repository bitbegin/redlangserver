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
print now/precise
code-ast: ast/analysis code
print now/precise
semantic/analysis code-ast
print now/precise
print semantic/format/semantic code-ast


print "Error/Warning: ---------------------------------------"
probe semantic/collect-errors code-ast
pos: ast/to-pos code-ast/1/source 18 6
ret: semantic/collect-completions code-ast semantic/position?/outer code-ast index? pos

print semantic/format ret
