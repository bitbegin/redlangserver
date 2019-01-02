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

	push-ctx: func [type [word!] params [block! none!]][
		append/only ctx reduce [type params]
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
		npc/1/4: reduce [copy ctx type]
	]

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
			push-ctx code none
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
			push-ctx code npc2
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
			;case [
			;	ctx/1/1 = 'does [
			;		return ['any 1]
			;	]
			;]
			return ['any 1]
		]
	]

	system-word-exp-type?: [
		if all [
			code-type = word!
			find system-words/system-words code
		][
			return reduce ['builtin 1]
		]
	]

	exp-type?: function [npc [block!]][
		old-pc: npc2: npc
		code: npc/1/1
		code-type: type? code
		type: none
		do bind semicolon-exp-type? 'old-pc
		do bind slit-exp-type? 'old-pc
		do bind system-word-exp-type? 'old-pc
		do bind set-word-exp-type? 'old-pc
		do bind block-1-exp-type? 'old-pc
		do bind block-2-exp-type? 'old-pc
		do bind block-exp-type? 'old-pc
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

	analysis: function [npc [block!]][
		pc: find-head npc
		clear ctx
		append/only ctx [#[none] #[none]]
		until [
			type: exp-type? pc
			pc: skip pc type/2
			tail? pc
		]
		true
	]
]
