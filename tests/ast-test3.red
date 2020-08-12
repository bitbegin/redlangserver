Red []

#include %../lexer.red

files: [
	%number-cases.txt
	%char-cases.txt
	%string-cases.txt
	%mstring-cases.txt
	%rstring-cases.txt
	%block-cases.txt
	%binary-cases.txt
	%tag-cases.txt
	;%path-cases.txt
]


forall files [
	src: read files/1
	print ["begin" files/1]
	print "================================================"
	print lexer/format lexer/transcode src
	print "================================================"
	print ["end" files/1]
	print lf
]
