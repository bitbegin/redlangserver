Red []


parse-line: function [stack [block!] src [string!]][
	append stack src
	append stack index? src
	while [src: find/tail src #"^/"][
		append stack index? src
	]
]
line-pos?: function [stack [block!] line [pair!] return: [string!]][
	pos: pick stack line/x + 1
	skip at stack/1 pos line/y - 1
]
index-line?: function [stack [block!] pos [integer!] return: [pair!]][
	stack: next stack
	forall stack [
		if all [
			stack/1 <= pos
			any [
				none? stack/2
				stack/2 > pos
			]
		][
			column: pos - stack/1
			return as-pair (index? stack) - 1 column + 1
		]
	]
	none
]



lex: function [
	event	[word!]									;-- event name
	input	[string! binary!]						;-- input series at current loading position
	type	[datatype! word! none!]					;-- type of token or value currently processed.
	line	[integer!]								;-- current input line number
	token											;-- current token as an input slice (pair!) or a loaded value.
	return: [logic!]								;-- YES: continue to next lexing stage, NO: cancel current token lexing
][
	[open prescan close error scan load]
	if pair? token [
		start: index-line? lines token/x
		stop: index-line? lines token/y
	]
	print [event type either pair? token [reduce [start stop]][token]]
	either event = 'error [input: next input no][yes]
]

print lf

files: [
	%number-cases.txt
	%char-cases.txt
	%string-cases.txt
	%mstring-cases.txt
	%rstring-cases.txt
	%block-cases.txt
	%binary-cases.txt
	%tag-cases.txt
	%path-cases.txt
]

lines: make block! 64
forall files [
	src: read files/1
	clear lines
	parse-line lines src
	print ["begin" files/1]
	print "================================================"
	transcode/trace src :lex
	print "================================================"
	print ["end" files/1]
	print lf
]
