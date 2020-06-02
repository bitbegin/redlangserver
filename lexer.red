Red [
	Title:   "Red runtime lexer"
	Author:  "bitbegin"
	File: 	 %lexer.red
	Tabs:	 4
	Rights:  "Copyright (C) 2020 Red Foundation. All rights reserved."
]

lexer: context [
	uri-to-file: function [uri [string!]][
		src: copy find/tail uri "file:///"
		to-red-file dehex src
	]
	file-to-uri: function [file [file!]][
		src: to-local-file file
		replace/all src "\" "/"
		insert src "file:///"
		src
	]
	semicolon?: function [pc [block!] pos [string!] column [integer!]][
		if pos/1 = #";" [return true]
		repeat count column [
			if pos/(0 - count) = #";" [return true]
		]
		false
	]
	parse-line: function [stack [block!] src [string!]][
		append stack index? src
		while [src: find/tail src #"^/"][
			append stack index? src
		]
	]
	line-pos?: function [stack [block!] line [pair!]][
		pos: pick stack line/x + 1
		skip at stack/1 pos line/y - 1
	]
	index-line?: function [stack [block!] pos [integer!]][
		forall stack [
			if all [
				stack/1 <= pos
				any [
					none? stack/2
					stack/2 > pos
				]
			][
				column: pos - stack/1
				return as-pair index? stack column + 1
			]
		]
		none
	]
	pos-line?: function [stack [block!] pos [string!]][
		index-line? stack index? pos
	]
	pos-range?: function [stack [block!] s [string!] e [string!]][
		range: make block! 4
		append range pos-line? stack s
		append range pos-line? stack e
		range
	]
	form-range: function [range [block!] /keep][
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

	transcode: function [
		src			[string!]
		system?		[logic!]
		return:		[block!]
	][
		top: make block! 1
		append/only top make block! 1
		lines: make block! 64
		parse-line lines src
		range: make block! 1
		append range 1x1
		append range pos-line? lines tail src
		top: get-token src lines
		stack: make block! 1
		append/only stack make block! 4
		repend stack/1 ['source src 'lines lines 'range range 'nested top]
		stack
	]

	get-token: function [
		src			[string!]
		lines		[block!]
		return:		[block!]
	][
		stack: make block! 4
		append/only stack make block! 4
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
			;print [event type token]
			switch event [
				scan [
					start: index-line? lines token/x
					stop: index-line? lines token/y
					repend/only last stack [
						'range reduce [start stop]
						'type  type
					]
				]
				load [
					repend last last stack [
						'expr token
					]
				]
				open [
					start: index-line? lines token/x
					repend/only p: last stack [
						'range reduce [start]
						'type  type
						'upper :p
					]
					repend/only stack reduce [reduce []]
				]
				close [
					either 1 <> length? stack [
						v: last stack
						remove back tail stack
						value: last last stack
						repend value ['nested v]
						either value/type <> type [
							if none? value/error [
								repend value ['error make block! 1]
							]
							repend/only value/error ['level 'Error 'type type]
						][
							stop: index-line? lines token/x
							append value/range stop
						]
					][
						str: copy/part input token/y - token/x + 1
						start: index-line? lines token/x
						stop: index-line? lines token/y
						repend/only value: last stack [
							'range reduce [start stop]
						]
						if none? value/error [
							repend value ['error make block! 1]
						]
						repend/only value/error ['level 'Error 'type type]
					]
				]
				error [
					str: copy/part input token/y - token/x + 1
					start: index-line? lines token/x
					stop: index-line? lines token/y
					repend/only value: last stack [
						'range reduce [start stop]
					]
					if none? value/error [
						repend value ['error make block! 1]
					]
					repend/only value/error ['level 'Error 'type str]
					input: next input
				]
			]
			;probe stack
			either event = 'error [false][true]
		]
		try [system/words/transcode/trace src :red-lex]
		end: index-line? lines index? tail src
		while [1 <> length? stack][
			v: last stack
			remove back tail stack
			value: last last stack
			append value/range end
			repend value ['nested v]
			if none? value/error [
				repend value ['error make block! 1]
			]
			repend/only value/error ['level 'Error 'type value/type 'msg 'unclose]
		]
		last stack
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
				newline pad + 4
				if pc/1/expr [
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
