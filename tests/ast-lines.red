Red []

#include %../lexer.red

;-- usage:
;-- ./console ast-lines.red

output: %ast-lines.txt
write output mold now
write/append output "^/"

codes: [
	;-- char!
	%{"}%
	%{#"^(00)"}%
	%{#"^(00)}%
	%{#"^(00) a"}%
	;-- line string!
	%{"abc"}%
	%{"abc}%
	%{"abc
"}%
	;-- block!
	"[]"
	"["
	"]"
	"[]["
	"[]]"
	"[[]"
	"][]"
	"[[]]"
	;-- paren!
	"()"
	"("
	")"
	"()("
	"())"
	"(()"
	")()"
	"(())"
	;-- multi string!
	"{}"
	"{"
	"}"
	"{}{"
	"{}}"
	"{{}"
	"}{}"
	"{{}}"
	"{{"
	"{{{"
	;-- path!
	"a/"
	"a/ "
	"a/b"
	"a/b/"
	"a/b/ "
	"a/b/:"
	"a/b/: "
	"a/b/'"
	"a/b/' "
]

forall codes [
	write/append output lexer/format lexer/transcode codes/1
	write/append output "^/"
]
