Red []

#include %../error.red
#include %../lsp-const.red
#include %../json.red
#include %../system-words.red
#include %../lexer.red


file: %semantic.red
code: read file

print now/precise
lexer/parse-line lines: clear [] code
print now/precise

print now/precise
ast: lexer/transcode code
print now/precise
print lexer/format ast
