Red []

#include %../lexer.red

;-- usage:
;-- ./console ast-cases.red

output: %ast-cases.txt
write output mold now
write/append output "^/"

files: read %cases/

forall files [
	src: read rejoin [%cases/ files/1]
	write/append output rejoin ["begin " mold files/1 "^/"]
	write/append output "================================================^/"
	write/append output lexer/format lexer/transcode src
	write/append output "^/"
	write/append output "================================================^/"
	write/append output rejoin ["end " mold files/1 "^/"]
	write/append output "^/"
]
