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
		return:		[block!]
	][
		lines: make block! 64
		parse-line lines src
		range: make block! 1
		append range 0x0
		append range top-stop: pos-line? lines tail src
		stack: reduce [reduce ['source src 'lines lines 'range range 'nested reduce []]]
		top: stack

		node*: none
		match-stack: []
		red-lex: func [
			event	[word!]
			input	[string! binary!]
			type	[datatype! word! none!]
			line	[integer!]
			token
			return:	[logic!]
		][
			[scan load open close error]
			;print [event mold type token mold input]
			switch event [
				scan [
					node*: make map! []
					node*/type: type
					either empty? match-stack [
						node*/token: token
						node*/next: input
					][
						node*/token: as-pair match-stack/1/3/x token/y + 1
						node*/next: next input
					]
					true
				]
				load [
					node*/expr: token
					throw node*
				]
				open [
					if find [block! paren! map! path!] to word! type [	;-- ignore open/close string!
						node*: make map! []
						node*/event: event
						node*/type: type
						node*/token: token
						node*/next: skip input 1 + token/y - token/x
						throw node*
					]
					repend/only match-stack ['open type token]
					true
				]
				close [
					if find [block! paren! map! path! lit-path! get-path!] to word! type [	;-- ignore open/close event like string!
						node*: make map! []
						node*/event: event
						node*/type: type
						node*/token: token
						node*/next: skip input 1 + token/y - token/x
						throw node*
					]
					repend/only match-stack ['close type token]
					true
				]
				error [
					node*: make map! []
					node*/event: event
					node*/type: type
					either all [
						type = error!
						input/1 = #"}"
					][
						node*/type: string!
						node*/token: token + 0x1
						node*/next: next input
						node*/error: 'only-close
					][
						if type = string! [
							node*/error: 'only-open
						]
						either empty? match-stack [
							either tail? input [
								node*/token: token
								node*/next: input
							][
								node*/token: token + 0x1
								node*/next: next input
							]
						][
							either tail? input [
								node*/token: as-pair match-stack/1/3/x token/y
								node*/next: input
							][
								node*/token: as-pair match-stack/1/3/x token/y + 1
								node*/next: next input
							]
						]
					]
					throw node*
				]
			]
		]

		forever [
			index: (index? src) - 1
			clear match-stack
			if block? node: catch [system/words/transcode/trace src :red-lex][
				;-- src tail
				break
			]
			;probe node
			case [
				node/event = 'open [
					nested: select last stack 'nested
					repend/only nested [
						'range reduce [index-line? lines node/token/x + index]
						'type  node/type
						'upper back tail stack
					]
					repend last nested ['nested reduce []]
					stack: nested
				]
				node/event = 'close [
					stop: index-line? lines node/token/x + index + 1
					forever [
						;-- top ast
						if none? ntype: select last stack 'type [
							nested: select last stack 'nested
							repend/only nested [
								'range reduce [stop stop]
								'type  node/type
								'upper back tail stack
								'error 'only-closed
							]
							break
						]
						;-- matched open/close
						if any [
							all [
								ntype = path!
								find [path! lit-path! get-path!] type
							]
							all [
								ntype <> path!
								ntype = node/type
							]
						][
							;-- just close the event
							range: select last stack 'range
							append range stop
							item: last stack
							item/type: node/type
							stack: select last stack 'upper
							break
						]
						;-- not matched close, need mark error tag
						range: select last stack 'range
						append range stop
						item: last stack
						either none? item/error [
							repend item ['error node/type]
						][
							item/error: node/type
						]
						stack: select last stack 'upper
					]
				]
				node/event = 'error [
					nested: select last stack 'nested
					repend/only nested [
						'range reduce [index-line? lines node/token/x + index index-line? lines node/token/y + index]
						'type  node/type
						'upper back tail stack
						'error either node/error [node/error]['unknown]
					]
				]
				true [
					nested: select last stack 'nested
					repend/only nested [
						'range reduce [index-line? lines node/token/x + index index-line? lines node/token/y + index]
						'type  node/type
						'expr  node/expr
						'upper back tail stack
					]
				]
			]
			src: node/next
		]
		;-- unclose event
		while [stack <> top][
			range: select last stack 'range
			if none? range/2 [
				append range top-stop
				item: last stack
				either none? item/error [
					repend item ['error 'only-opend]
				][
					item/error: 'only-opend
				]
			]
			stack: select last stack 'upper
		]
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
				;unless empty? error: pc/1/error [
				;	newline pad + 4
				;	append buffer "error: ["
				;	newline pad + 6
				;	append buffer mold/flat/part error 30
				;	newline pad + 4
				;	append buffer "]"
				;]
				if error: pc/1/error [
					newline pad + 4
					append buffer "error: "
					append buffer mold/flat/part error 30
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
