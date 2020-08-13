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

	fetch-token: function [
		src			[string!]
	][
		node: make map! 4
		pre: none
		start: none
		stop: none
		lex: func [
			event	[word!]
			input	[string! binary!]
			type	[datatype! word! none!]
			line	[integer!]
			token
			return:	[logic!]
		][
			[prescan scan load open close error]
			;print [event mold type token mold input]
			switch event [
				prescan [
					pre: token
				]
				scan [
					node/token: either all [start stop][
						as-pair start stop
					][token]
					node/type: type
					true
				]
				load [
					node/expr: token
					throw node
				]
				open [
					either type = string! [
						if none? start [
							start: token/x
						]
						true
					][
						node/event: event
						node/type:  type
						node/token: token + 0x1
						throw node
					]
				]
				close [
					either type = string! [
						stop: token/y + 1
						true
					][
						node/event: event
						node/type:  type
						node/token: token + 0x1
						throw node
					]
				]
				error [
					case [
						type = string! [
							;-- multiline
							either start [
								node/token: as-pair start token/y
							][
								;-- have scaned
								either node/token [
									node/token: pre + 0x1
								][
									node/token: token + 0x1
								]
							]
							node/event: event
							node/type:  type
							node/error: reduce ['type 'only-opened 'at token]
							throw node
						]
						type = error! [
							node/event: event
							either input/1 = #"}" [
								node/type: string!
								node/error: 'only-closed
							][
								node/type: type
								node/error: 'only-opened
							]
							node/token: token + 0x1
							throw node
						]
						type = char! [
							node/event: event
							node/type: type
							either input/1 = #"^"" [
								node/token: token + 0x1
								node/error: 'invalid
							][
								node/token: token
								node/error: 'not-closed
							]
							throw node
						]
						type = binary! [
							node/event: event
							node/type: type
							either input/1 = #"}" [
								node/token: token + 0x1
								node/error: 'invalid
							][
								node/token: token
								node/error: 'not-closed
							]
							throw node
						]
						true [
							node/event: event
							node/type: type
							node/token: token
							node/error: 'unknown
							throw node
						]
					]
				]
			]
		]
		either block? pos: catch [system/words/transcode/trace src :lex][
			none
		][
			node
		]
	]

	insert-node: function [
		stack		[block!]
		lines		[block!]
		src			[string!]
		index		[integer!]
		return:		[block!]
	][
		add-node: func [
			base	[integer!]
			x		[integer!]
			y		[integer!]
			type	[datatype!]
			expr
			error
			/local nested
		][
			nested: select last stack 'nested
			repend/only nested [
				'range reduce [index-line? lines base + x index-line? lines base + y]
				'type  type
				'upper back tail stack
			]
			if expr [
				repend last nested ['expr expr]
			]
			if error [
				repend last nested ['error error]
			]
		]
		push-node: func [
			base	[integer!]
			x		[integer!]
			type	[datatype!]
			return:	[block!]
			/local nested
		][
			nested: select last stack 'nested
			repend/only nested [
				'range reduce [index-line? lines base + x]
				'type  type
				'upper back tail stack
			]
			repend last nested ['nested reduce []]
			stack: nested
		]
		lex: func [
			event	[word!]
			input	[string! binary!]
			type	[datatype! word! none!]
			line	[integer!]
			token
			return:	[logic!]
			/local nstop ntype range item y e
		][
			[prescan scan load open close error]
			;print [event mold type token mold input]
			switch event [
				prescan [
					pretoken: token
					true
				]
				scan [
					stoken: either all [start stop][							;-- string! need adjust the position
						as-pair start stop
					][token]
					stype: type
					true
				]
				load [
					add-node base stoken/x stoken/y stype token none
					throw stoken/y - 1
				]
				open [
					either type = string! [
						if none? start [
							start: token/x
						]
						true
					][
						push-node base token/x type
						throw token/y
					]
				]
				close [
					either type = string! [
						stop: token/y + 1
						true
					][
						nstop: none
						x: token/x
						y: token/y + 1
						forever [
							unless ntype: select last stack 'type [				;-- check if top
								add-node base x y type none 'only-closed
								break
							]
							if ntype = type [									;-- match the upper's type
								range: select last stack 'range
								append range index-line? lines base + y
								stack: select last stack 'upper
								break
							]
							unless nstop [
								nstop: index-line? lines base + y
							]
							range: select last stack 'range
							append range nstop
							item: last stack
							either none? item/error [
								repend item ['error 'only-opened]
							][
								item/error: 'only-opened
							]
							stack: select last stack 'upper
						]
						throw token/y
					]
				]
				error [
					case [
						type = string! [
							;-- multiline
							either start [
								x: start
								y: token/y + 1
							][
								;-- have scaned
								either node/token [
									x: pretoken/x
									y: pretoken/y + 1
								][
									x: token/x
									y: token/y + 1
								]
							]
							add-node base x y type none reduce ['type 'only-opened 'at token]
							throw y - 1
						]
						type = error! [
							either input/1 = #"}" [
								type: string!
								e: 'only-closed
							][
								e: 'only-opened
							]
							add-node base token/x token/y + 1 type none e
							throw token/y
						]
						type = char! [
							either input/1 = #"^"" [
								y: token/y + 1
								e: 'invalid
							][
								y: token/y
								e: 'not-closed
							]
							add-node base token/x y type none e
							throw y - 1
						]
						type = binary! [
							either input/1 = #"}" [
								y: token/y + 1
								e: 'invalid
							][
								y: token/y
								e: 'not-closed
							]
							add-node base token/x y type none e
							throw y - 1
						]
						true [
							add-node base token/x token/y type none none
							throw token/y - 1
						]
					]
				]
			]
		]

		top: stack
		forever [
			pretoken: none										;-- used for store prescan token
			start: none											;-- used for mark the begin of string!
			stop: none											;-- used for mark the end of string!
			stoken: none										;-- used for store scan token
			stype: none											;-- used for store scan type
			base: index + (index? src) - 1
			pos: catch [system/words/transcode/trace src :lex]
			if block? pos [break]
			src: skip src pos
		]

		stop: none
		while [stack <> top][
			unless stop [
				stop: index-line? lines index + index? tail src
			]
			range: select last stack 'range
			append range stop
			item: last stack
			either none? item/error [
				repend item ['error 'only-opened]
			][
				item/error: 'only-opened
			]
			stack: select last stack 'upper
		]
		top
	]

	transcode: function [
		src			[string!]
		return:		[block!]
	][
		lines: make block! 64
		parse-line lines src
		range: make block! 1
		append range 0x0
		append range pos-line? lines tail src
		stack: reduce [reduce ['source src 'lines lines 'range range 'nested reduce []]]
		top: stack
		insert-node stack lines src 0
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
