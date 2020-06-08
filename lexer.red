Red [
	Title:   "Red runtime lexer"
	Author:  "bitbegin"
	File: 	 %lexer.red
	Tabs:	 4
	Rights:  "Copyright (C) 2020 Red Foundation. All rights reserved."
]

lexer: context [
	uri-to-file: function [uri [string!] return: [file!]][
		src: copy find/tail uri "file:///"
		to-red-file dehex src
	]
	file-to-uri: function [file [file!] return: [string!]][
		src: to-local-file file
		replace/all src "\" "/"
		insert src "file:///"
		src
	]
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
	pos-line?: function [stack [block!] pos [string!] return: [pair!]][
		index-line? stack index? pos
	]
	pos-range?: function [stack [block!] s [string!] e [string!] return: [block!]][
		range: make block! 4
		append range pos-line? stack s
		append range pos-line? stack e
		range
	]
	form-range: function [range [block!] return: [map!] /keep][
		make map! reduce [
			'start make map! reduce [
				'line either keep [range/1/x][range/1/x - 1]
				'character either keep [range/1/y][range/1/y - 1]
			]
			'end make map! reduce [
				'line either keep [range/2/x][range/2/x - 1]
				'character either keep [range/2/y][range/2/y - 1]
			]
		]
	]
	load-range: function [stack [block!] range [block!]][
		start: line-pos? stack range/1
		stop: line-pos? stack range/2
		try [load copy/part start stop]
	]

	transcode: function [
		src			[string!]
		system?		[logic!]
		return:		[block!]
	][
		lines: make block! 64
		parse-line lines src
		range: make block! 1
		append range 0x0
		append range pos-line? lines tail src
		stack: reduce [reduce ['source src 'lines lines 'range range 'nested reduce []]]
		top: stack

		start: none
		stop: none
		red-lex: func [
			event	[word!]
			input	[string! binary!]
			type	[datatype! word! none!]
			line	[integer!]
			token
			return:	[logic!]
		][
			[scan load open close error]
			;print [event mold type token]
			switch event [
				scan [
					start: index-line? lines token/x
					stop: index-line? lines token/y
					nested: select last stack 'nested
					repend/only nested [
						'range reduce [start stop]
						'type  type
						'upper back tail stack
					]
					true
				]
				load [
					nested: select last stack 'nested
					repend last nested [
						'expr token
					]
					true
				]
				open [
					start: index-line? lines token/x
					nested: select last stack 'nested
					repend/only nested [
						'range reduce [start]
						'type  type
						'upper back tail stack
					]
					if find reduce [block! paren! map! path! lit-path! get-path!] type [
						repend last nested ['nested reduce []]
						stack: nested
					]
					true
				]
				close [
					stop: index-line? lines token/y + 1
					either find reduce [block! paren! map! path! lit-path! get-path!] type [
						range: select last stack 'range
						append range stop
						stack: select last stack 'upper
					][
						nested: select last stack 'nested
						range: select last nested 'range
						append range stop
						p: last nested
						probe range
						either error? value: load-range lines range [
							if none? p/error [
								repend p ['error make block! 1]
							]
							repend p/error ['level 'Error 'type 'load]
						][
							repend p ['expr value]
						]
					]
					true
				]
				error [
					start: index-line? lines token/x
					either token/x = token/y [
						str: copy/part input 1
						stop: index-line? lines token/x + 1
					][
						str: skip input token/x - token/y
						str: copy/part str input
						stop: index-line? lines token/y
					]
					;-- unclosed [block! paren! map! path! lit-path! get-path!]
					if all [
						p: last stack
						p/range/1 = start
					][
						append p/range stop
						if none? p/error [
							repend p ['error make block! 1]
						]
						repend p/error ['level 'Error 'type 'unclose]
						stack: select last stack 'upper
						input: next input
						return false
					]
					nested: select last stack 'nested
					;-- unclosed like string!
					if all [
						p: last nested
						p/range/1 = start
					][
						append p/range stop
						if none? p/error [
							repend p ['error make block! 1]
						]
						repend p/error ['level 'Error 'type 'unclose]
						input: next input
						return false
					]
					repend/only nested [
						'range reduce [start stop]
						'error [level Error type unknown]
					]
					input: next input
					false
				]
			]
		]
		system/words/transcode/trace src :red-lex
		;probe stack
		top
	]

	format: function [top [block!]][
		buffer: make string! 1000
		newline: function [cnt [integer!]] [
			append buffer lf
			append/dup buffer " " cnt
		]

		format*: function [pc [block!] depth [integer!]][
			pad: depth * 4
			newline pad
			append buffer "["
			forall pc [
				newline pad + 2
				append buffer "["
				if pc/1/expr [
					newline pad + 4
					append buffer "expr: "
					append buffer mold/flat/part pc/1/expr 20
				]
				if pc/1/range [
					newline pad + 4
					append buffer "range: "
					append buffer mold/flat pc/1/range
				]
				if pc/1/type [
					newline pad + 4
					append buffer "type: "
					append buffer mold/flat pc/1/type
				]
				if pc/1/nested [
					newline pad + 4
					append buffer "nested: "
					format* pc/1/nested depth + 1
				]
				if pc/1/source [
					newline pad + 4
					append buffer "source: "
					append buffer mold/flat/part pc/1/source 10
				]
				if lines: pc/1/lines [
					newline pad + 4
					append buffer "lines: ["
					newline pad + 6
					append buffer mold/flat/part lines/1 10
					lines: next lines
					forall lines [
						newline pad + 6
						append buffer mold lines/1
					]
					newline pad + 4
					append buffer "]"
				]
				if upper: pc/1/upper [
					newline pad + 4
					append buffer "upper: "
					append buffer mold/flat upper/1/range
				]
				unless empty? error: pc/1/error [
					newline pad + 4
					append buffer "error: ["
					newline pad + 6
					append buffer mold/flat/part error 30
					newline pad + 4
					append buffer "]"
				]
				newline pad + 2
				append buffer "]"
			]
			newline pad
			append buffer "]"
		]
		format* top 0
		buffer
	]
]
