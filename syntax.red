Red [
	Title:   "Red syntax for Red language server"
	Author:  "bitbegin"
	File: 	 %syntax.red
	Tabs:	 4
	Rights:  "Copyright (C) 2011-2019 Red Foundation. All rights reserved."
	License: "BSD-3 - https://github.com/red/red/blob/origin/BSD-3-License.txt"
]

#include %error.red

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
			throw-error fn "no more code!" where
		]
	]

	check-block?: func [fn where][
		unless block? where/1/1 [
			throw-error fn "need a block!" where
		]
	]

	literal-type: reduce [
		binary! char! date! email! file! float!
		get-path! get-word! lit-path! lit-word!
		integer! issue! logic! map! pair! path!
		percent! refinement! string! tag! time!
		tuple! url!
	]

	simple-literal?: function [value][
		either find literal-type type: type? value [reduce [type 1]][false]
	]

	save-type: func [npc [block!] type][
		npc/1/4: type
		npc/1/5: index? ctx
	]

	exp-type?: function [npc [block!]][
		old-pc: npc2: npc
		code: npc/1/1
		code-type: type? code
		type: none
		value: none

		semicolon-exp-type?: [
			if code = none [
				save-type old-pc 'semicolon
				return ['semicolon 1]
			]
		]

		slit-exp-type?: [
			if type: simple-literal? code [
				save-type old-pc 'literal
				return type
			]
		]

		set-word-exp-type?: [
			if set-word? code [
				next-tail? 'set-word npc
				npc2: next npc
				type: exp-type? npc2
				save-type old-pc type/1
				return reduce [type/1 type/2 + 1]
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
				save-type old-pc type/1
				return reduce [type/1 type/2 + 1]
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
				save-type old-pc type/1
				return reduce [type/1 type/2 + 2]
			]
		]

		block-exp-type?: [
			if block? code [
				case [
					ctx/1/1 = 'does [
						value: pop-ctx
						return reduce ['block 1]
					]
					ctx/1/1 = 'context [
						value: pop-ctx
						return reduce ['block 1]
					]
					ctx/1/1 = 'has [
						value: pop-ctx
						return reduce ['block 1]
					]
					ctx/1/1 = 'func [
						value: pop-ctx
						return reduce ['block 1]
					]
					ctx/1/1 = 'function [
						value: pop-ctx
						return reduce ['block 1]
					]
					ctx/1/1 = 'routine [
						value: pop-ctx
						return reduce ['block 1]
					]
				]
				return reduce ['block 1]
			]
		]

		system-word-exp-type?: [
			if all [
				code-type = word!
				find system-words/system-words code
			][
				save-type old-pc 'builtin
				return reduce ['builtin 1]
			]
		]

		unknown-word-exp-type?: [
			if code-type = word! [
				save-type old-pc 'unknown
				return reduce ['unknown 1]
			]
		]

		do semicolon-exp-type?
		do slit-exp-type?
		do set-word-exp-type?
		do block-1-exp-type?
		do block-2-exp-type?
		do block-exp-type?
		do system-word-exp-type?
		do unknown-word-exp-type?
		throw-error 'exp-type "not support!" code
	]

	find-head: function [npc [block!]][
		unless npc/1/1 = 'Red [
			throw-error 'find-head "incorrect header" npc/1
		]
		npc: next npc
		unless block? npc/1/1 [
			throw-error 'find-head "incorrect header" npc/1
		]
		next npc
	]

	global?: function [npc [block!] word [word!]][
		w: to set-word! word
		forall npc [
			if all [
				npc/1/1 = w
				npc/1/5 = 1
			][
				return true
			]
		]
		false
	]

	analysis: function [npc [block!]][
		saved: pc: find-head npc
		clear ctx
		append/only ctx [#[none] #[none]]
		until [
			type: exp-type? pc
			pc: skip pc type/2
			tail? pc
		]

		;-- resolve unknown type
		pc: saved
		until [
			if pc/1/4 = 'unknown [
				if global? saved pc/1/1 [
					pc/1/4: 'global
				]
			]
			pc: next pc
			tail? pc
		]

		true
	]
]
