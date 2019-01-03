Red [
	Title:   "Red syntax for Red language server"
	Author:  "bitbegin"
	File: 	 %syntax.red
	Tabs:	 4
	Rights:  "Copyright (C) 2011-2019 Red Foundation. All rights reserved."
	License: "BSD-3 - https://github.com/red/red/blob/origin/BSD-3-License.txt"
]

red-syntax: context [
	throw-error: register-error 'red-syntax

	ctx: []

	push-ctx: func [params [block!]][
		append/only ctx params
		ctx: next ctx
	]

	pop-ctx: has [value][
		also ctx/1 do [clear ctx ctx: back ctx]
	]

	next-tail?: func [fn where][
		if tail? next where [
			throw-error fn "no more code!" where/1
		]
	]

	check-block?: func [fn where][
		unless block? where/1/1 [
			throw-error fn "need a block!" where/1
		]
	]

	literal-type: reduce [
		binary! char! date! email! file! float!
		get-path! get-word! lit-path! lit-word!
		integer! issue! logic! map! pair! path!
		percent! refinement! string! tag! time!
		tuple! url!
	]

	form-type: function [type][
		case [
			any [
				type = date!
				type = float!
				type = integer!
				type = percent!
				type = time!
				type = tuple!
				type = pair!
			][
				SymbolKind/Number
			]
			type = logic! [
				SymbolKind/Boolean
			]
			any [
				type = string!
				type = char!
				type = email!
				type = file!
				type = issue!
				type = tag!
				type = url!
			][
				SymbolKind/String
			]
			type = binary! [
				SymbolKind/Array
			]
			any [
				type = lit-word!
				type = get-word!
			][
				SymbolKind/Constant
			]
			any [
				type = get-path!
				type = lit-path!
				type = path!
				type = refinement!
			][
				SymbolKind/Object
			]
			type = map! [
				SymbolKind/Key
			]
		]
	]

	simple-literal?: function [value][
		either find literal-type type? value [true][false]
	]

	save-type: func [npc [block!] symbol-type [block!]][
		npc/1/4: symbol-type
	]

	exp-type?: function [npc [block!]][
		old-pc: npc2: npc
		code: npc/1/1
		code-type: type? code
		type: none
		value: none
		nctx: none

		semicolon-exp-type?: [
			if any [
				all [
					string? code
					not empty? code
					code/1 = #";"
				]
				code = none
			][
				type: reduce ['semicolon-exp none SymbolKind/Null 1]
				save-type old-pc type
				return copy type
			]
		]

		slit-exp-type?: [
			if simple-literal? code [
				type: type? code
				type: reduce ['slit-exp type form-type type 1]
				save-type old-pc type
				return copy type
			]
		]

		set-word-exp-type?: [
			if set-word? code [
				next-tail? 'set-word npc
				npc2: next npc
				type: exp-type? npc2
				type/4: type/4 + 1
				save-type old-pc type
				return copy type
			]
		]

		set-path-exp-type?: [
			if set-path? code [
				next-tail? 'set-path npc
				npc2: next npc
				type: exp-type? npc2
				type/4: type/4 + 1
				save-type old-pc type
				return copy type
			]
		]

		;-- a key word followed by 1 block
		block-1-exp-type?: [
			if any [
				code = 'does
				code = 'context
			][
				push-ctx old-pc/1
				next-tail? code npc
				npc2: next npc
				check-block? code npc2
				type: exp-type? npc2
				type/4: type/4 + 1
				save-type old-pc type
				return copy type
			]
		]

		;-- a key word followed by 2 blocks
		block-2-exp-type?: [
			if any [
				code = 'has
				code = 'func
				code = 'function
				code = 'routine
			][
				next-tail? code npc
				npc2: next npc
				check-block? code npc2
				push-ctx old-pc/1
				next-tail? code npc2
				npc2: next npc2
				check-block? code npc2
				type: exp-type? npc2
				type/4: type/4 + 2
				save-type old-pc type
				return copy type
			]
		]

		block-exp-type?: [
			if block? code [
				nctx: ctx/1/1
				if any [
					nctx = 'does
					nctx = 'has
					nctx = 'func
					nctx = 'function
					nctx = 'routine
				][
					value: pop-ctx
					type: reduce ['block-exp nctx SymbolKind/Function 1]
					save-type old-pc type
					return copy type
				]
				if nctx = 'context [
					value: pop-ctx
					type: reduce ['block-exp nctx SymbolKind/Namespace 1]
					save-type old-pc type
					return copy type
				]
				type: reduce ['block-exp nctx SymbolKind/Object 1]
				return copy type
			]
		]

		system-word-exp-type?: [
			if all [
				code-type = word!
				find system-words/system-words code
			][
				type: reduce ['system system-words/get-type code SymbolKind/Method 1]
				save-type old-pc type
				return copy type
			]
		]

		unknown-word-exp-type?: [
			if code-type = word! [
				type: reduce ['unknown none SymbolKind/Null 1]
				save-type old-pc type
				return copy type
			]
		]

		do semicolon-exp-type?
		do slit-exp-type?
		do set-word-exp-type?
		do set-path-exp-type?
		do block-1-exp-type?
		do block-2-exp-type?
		do block-exp-type?
		do system-word-exp-type?
		do unknown-word-exp-type?
		throw-error 'exp-type "not support!" old-pc/1
	]

	find-head: function [npc [block!]][
		unless npc/1/1 = 'Red [
			throw-error 'find-head "incorrect header" npc/1
		]
		save-type npc reduce ['header 'Red SymbolKind/File 2]
		npc: next npc
		unless block? npc/1/1 [
			throw-error 'find-head "incorrect header" npc/1
		]
		save-type npc reduce ['header 'Block SymbolKind/File 1]
		next npc
	]

	global?: function [npc [block!] word [word!]][
		w: to set-word! word
		forall npc [
			if all [
				npc/1/1 == w
				npc/1/6 = 1
			][
				return true
			]
		]
		false
	]

	resolve-symbol: function [npc [block!]][
		;-- resolve unknown type
		pc: npc
		until [
			if pc/1/5 = 'unknown [
				if global? npc pc/1/1 [
					pc/1/5: 'global
				]
			]
			pc: next pc
			tail? pc
		]
	]

	;-- npc layout: [code start end symbol-type TBD TBD TBD]
	analysis: function [npc [block!]][
		clear ctx
		append/only ctx [#[none] #[none]]
		saved: pc: find-head npc
		until [
			type: exp-type? pc
			pc: skip pc type/4
			tail? pc
		]
		;resolve-symbol saved
		npc
	]
]
