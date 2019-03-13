Red []

#include %../lexer.red

file: %semantic.red
code: read file

print now/precise
lexer/parse-line lines: clear [] code
print now/precise

print now/precise
top: lexer/transcode code
print now/precise
print lexer/format top
