Red []

#include %../lexer.red

;-- usage:
;-- ./console ast-lines.red > ast-lines.txt

; char!
print lexer/format lexer/transcode {"}
print lexer/format lexer/transcode {#"^^(00)"}
print lexer/format lexer/transcode {#"^^(00)}
print lexer/format lexer/transcode {#"^^(00) a"}
; line string!
print lexer/format lexer/transcode {"abc"}
print lexer/format lexer/transcode {"abc}
print lexer/format lexer/transcode {"abc^/"}
; block!
print lexer/format lexer/transcode "[]"
print lexer/format lexer/transcode "["
print lexer/format lexer/transcode "]"
print lexer/format lexer/transcode "[]["
print lexer/format lexer/transcode "[]]"
print lexer/format lexer/transcode "[[]"
print lexer/format lexer/transcode "][]"
print lexer/format lexer/transcode "[[]]"
; paren!
print lexer/format lexer/transcode "()"
print lexer/format lexer/transcode "("
print lexer/format lexer/transcode ")"
print lexer/format lexer/transcode "()("
print lexer/format lexer/transcode "())"
print lexer/format lexer/transcode "(()"
print lexer/format lexer/transcode ")()"
print lexer/format lexer/transcode "(())"
; block string!
print lexer/format lexer/transcode "{}"
print lexer/format lexer/transcode "{"
print lexer/format lexer/transcode "}"
print lexer/format lexer/transcode "{}{"
print lexer/format lexer/transcode "{}}"
print lexer/format lexer/transcode "{{}"
print lexer/format lexer/transcode "}{}"
print lexer/format lexer/transcode "{{}}"
print lexer/format lexer/transcode "{{"
print lexer/format lexer/transcode "{{{"
; path!
print lexer/format lexer/transcode "a/"
print lexer/format lexer/transcode "a/ "
print lexer/format lexer/transcode "a/b"
print lexer/format lexer/transcode "a/b/"
print lexer/format lexer/transcode "a/b/ "
print lexer/format lexer/transcode "a/b/:"
print lexer/format lexer/transcode "a/b/: "
