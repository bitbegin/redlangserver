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

	get-token: function [
		src			[string!]
		return:		[block!]
	][
		top: make block! 1
		append/only top make block! 1
		lines: make block! 64
		parse-line lines src
		range: make block! 1
		append range 1x1
		append range pos-line? lines tail src
		top: get-token* src lines
		stack: make block! 1
		append/only stack make block! 4
		repend stack/1 ['source src 'lines lines 'range range 'nested top]
		stack
	]

	get-token*: function [
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
			;print event
			switch event [
				scan [
					start: index-line? lines token/x
					stop: index-line? lines token/y
					repend/only last stack [
						'range reduce [start stop]
						'type  type
					]
					true
				]
				load [
					repend last last stack [
						'token token
					]
					false
				]
				open [
					start: index-line? lines token/x
					repend/only p: last stack [
						'range reduce [start]
						'type  type
						'upper :p
					]
					repend/only stack make block! 4
					false
				]
				close [
					either 1 <> length? stack [
						v: last stack
						remove back tail stack
						value: last last stack
						repend value ['nested v]
						either value/type <> type [
							either none? value/error [
								repend value [
									'error reduce ['close type]
								]
							][
								repend/only value/error ['close type]
							]
						][
							stop: index-line? lines token/x
							append value/range stop
						]
					][
						start: index-line? lines token/x
						stop: index-line? lines token/y
						repend/only last stack [
							'range reduce [start stop]
							'error reduce ['unknown type]
						]
					]
					false
				]
				error [
					start: index-line? lines token/x
					stop: index-line? lines token/y
					repend/only last stack [
						'range reduce [start stop]
						'error reduce ['unknown type]
					]
					if 1 <> length? stack [
						value: last stack
						remove back tail stack
						p: last stack
						append/only p/nested value
					]
					input: next input
					false
				]
			]
			;probe stack
		]
		transcode/trace src :red-lex
		while [1 <> length? stack][
			value: last stack
			either none? value/error [
				repend/only value [
					'error reduce ['unclose 0]
				]
			][
				repend/only value/error ['unclose 0]
			]
			remove back tail stack
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
				if pc/1/token [
					append buffer "token: "
					append buffer mold/flat/part pc/1/token 20
				]
				if pc/1/range [
					newline pad + 4
					append buffer "range: "
					append buffer mold/flat pc/1/range
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
					append buffer mold/flat/part error 20
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
