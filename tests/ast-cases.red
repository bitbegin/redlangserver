Red []

#include %../lexer.red

;-- usage:
;-- ./console ast-cases.red > ast-cases.txt

files: read %cases/

forall files [
	src: read rejoin [%cases/ files/1]
	print ["begin" files/1]
	print "================================================"
	print lexer/format lexer/transcode src
	print "================================================"
	print ["end" files/1]
	print lf
]
