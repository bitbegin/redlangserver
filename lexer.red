Red [
	Title:   "Red runtime lexer"
	Author:  "bitbegin"
	File: 	 %lexer.red
	Tabs:	 4
	Rights:  "Copyright (C) 2020 Red Foundation. All rights reserved."
]

lexer: context [
	all-path!: reduce [path! lit-path! get-path! set-path!]
	noset-path!: reduce [path! lit-path! get-path!]
	all-pair!: reduce [block! paren! map!]
	pre-path!: reduce [lit-path! get-path!]

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
	line-pos?: function [stack [block!] line [integer!] column [integer!] return: [string!]][
		pos: pick stack line + 1
		skip at stack/1 pos column - 1
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
	;-- Range in lsp is zero-based position, use /keep for print
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
		start: line-pos? stack range/1/x range/1/y
		stop: line-pos? stack range/2/x range/2/y
		try [load copy/part start stop]
	]

	remove-last-empty-nested: func [
		item	[block!]
	][
		if all [
			item/nested
			empty? item/nested
		][
			item/nested: none
		]
	]

	insert-node: function [
		stack		[block!]
		lines		[block!]
		src			[string!]
		return:		[block!]
	][
		add-node: func [
			x		[integer!]
			y		[integer!]
			type	[datatype! word!]
			expr
			error
			/local nested
		][
			nested: select last stack 'nested
			repend/only nested [
				'range reduce [index-line? lines x index-line? lines y]
				'type  type
				'upper back tail stack
			]
			if expr [
				repend last nested ['expr reduce [expr]]
			]
			if error [
				repend last nested ['error error]
			]
		]
		push-node: func [
			x		[integer!]
			type	[datatype!]
			return:	[block!]
			/local nested
		][
			nested: select last stack 'nested
			repend/only nested [
				'range reduce [index-line? lines x]
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
			/local ltype x y err str
		][
			[prescan scan load open close error]
			close-path: func [
				y	[integer!]
				err	[block!]
				/local item
			][
				item: last stack
				append item/range index-line? lines y
				repend item ['error err]
				stack: item/upper
			]
			match-pair: func [
				x	[integer!]
				y	[integer!]
				/local ltype item nstop
			][
				forever [
					unless ltype: select last stack 'type [				;-- check if top
						add-node x y type none [code only-closed]
						break
					]
					unless nstop [
						nstop: index-line? lines y
					]
					if any [											;-- match the upper's type
						ltype = type
						all [
							find noset-path! ltype
							type = set-path!
						]
						all [
							ltype = map!
							type = paren!
						]
					][
						item: last stack
						if type = set-path! [
							item/type: type
						]
						append item/range nstop
						remove-last-empty-nested item
						stack: item/upper
						break
					]
					item: last stack
					append item/range nstop
					repend item ['error [code only-opened]]
					remove-last-empty-nested item
					stack: item/upper
				]
			]

			in-path?: func [
				/local p? ltype
			][
				p?: no
				if all [
					ltype: select last stack 'type
					ltype
				][
					if find noset-path! ltype [
						p?: yes
					]
				]
				p?
			]

			;print [event mold type token mold input]
			switch event [
				prescan [
					pretoken: token
					if all [
						type = 'eof
						input/1 = #";"
					][
						add-node token/x token/y 'comment none none
					]
					true
				]
				scan [
					stoken: either all [start stop][							;-- string! need adjust the position
						as-pair start stop
					][token]
					stype: type
					if stype = 'comment [
						add-node stoken/x stoken/y stype none none
					]
					true
				]
				load [
					add-node stoken/x stoken/y stype token none
					start: stop: none stoken: none
					true
				]
				open [
					either type = string! [
						if none? start [
							start: token/x
						]
					][
						push-node token/x type
					]
					true
				]
				close [
					either type = string! [
						stop: token/y + 1
					][
						nstop: none
						x: token/x
						either find noset-path! type [
							y: token/y
						][
							switch input/1 [
								#")" [type: paren!]
								#"]" [type: block!]
								#"}" [type: string!]
							]
							y: token/y + 1
							input: next input
						]
						close-y: token/y
						match-pair x y
					]
					true
				]
				error [
					case [
						find noset-path! type [
							case [
								input/1 = #"/" [			;-- eof after /
									y: token/y + 1
									input: next input
									err: [code slash]
								]
								input/-1 = #"/" [			;-- slash
									y: token/y
									err: [code slash]
								]
								true [
									y: token/y + 1
									input: next input
									err: [code unknown]
								]
							]
							close-path y err
						]
						find all-pair! type [
							if all [
								token/y > close-y
								find ")]}" input/1
							][
								switch input/1 [
									#")" [type: paren!]
									#"]" [type: block!]
									#"}" [type: string!]
								]
								match-pair token/x token/y + 1
							]
							input: next input
						]
						in-path? [
							s: skip input token/x - token/y
							err: reduce ['code type 'expr copy/part s input]
							close-path token/y err
						]
						type = string! [
							;-- multiline
							either start [
								x: start
								y: token/y
								input: next input
							][
								;-- have scaned
								either stoken [
									x: pretoken/x
									y: pretoken/y + 1
									input: next input
								][
									either input/1 = #"^"" [
										x: pretoken/x
										y: pretoken/y + 1
										input: next input
									][
										x: pretoken/x
										y: pretoken/y
									]
								]
							]
							stoken: none
							err: reduce ['code 'only-opened 'at token/x - x]
							add-node x y type none err
						]
						type = error! [
							either input/1 = #"}" [
								type: string!
								err: [code only-closed]
							][
								err: [code only-opened]
							]
							input: next input
							add-node token/x token/y + 1 type none err
						]
						type = char! [
							either input/1 = #"^"" [
								y: token/y + 1
								input: next input
								err: [code invalid]
							][
								y: token/y
								err: [code not-closed]
							]
							add-node token/x y type none err
						]
						type = binary! [
							either input/1 = #"}" [
								y: token/y + 1
								input: next input
								err: [code invalid]
							][
								y: token/y
								err: [code not-closed]
							]
							add-node token/x y type none err
						]
						true [
							add-node token/x token/y type none [code unknown]
						]
					]
					false
				]
			]
		]

		top: stack

		pretoken: none										;-- used for store prescan token
		start: none											;-- used for mark the begin of string!
		stop: none											;-- used for mark the end of string!
		stoken: none										;-- used for store scan token
		stype: none											;-- used for store scan type
		close-y: 0
		system/words/transcode/trace src :lex

		stop: none
		while [stack <> top][
			unless stop [
				stop: index-line? lines index? tail src
			]
			item: last stack
			append item/range stop
			either item/error [
				item/error/code: 'only-opened
			][
				append item [error [code only-opened]]
			]
			remove-last-empty-nested item
			stack: item/upper
		]
		top
	]

	transcode: function [
		src			[string!]
		return:		[block!]
	][
		unless head? src [return none]
		lines: make block! 64
		parse-line lines src
		range: make block! 1
		append range 1x1
		append range pos-line? lines tail src
		stack: reduce [reduce ['source src 'lines lines 'range range 'nested reduce []]]
		top: stack
		insert-node stack lines src
		if empty? top/1/nested [
			top/1/nested: none
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
					append buffer mold/flat/part pc/1/expr/1 20
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

	sformat: function [top [block!]][
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
				append buffer "range: "
				append buffer mold/flat pc/1/range
				if upper: pc/1/upper [
					append buffer " upper: "
					append buffer mold/flat upper/1/range
				]
				if pc/1/type [
					append buffer " type: "
					append buffer mold/flat pc/1/type
				]
				if pc/1/expr [
					append buffer " expr: "
					append buffer mold/flat/part pc/1/expr/1 20
				]
				if error: pc/1/error [
					append buffer " error: "
					append buffer mold/flat/part error 30
				]
				if pc/1/nested [
					append buffer " nested: "
					format* pc/1/nested depth + 1
				]
				append buffer "]"
			]
			newline pad
			append buffer "]"
		]
		format* top 0
		buffer
	]
]
