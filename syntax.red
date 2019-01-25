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

	syntax-top: none

	error-code: [
		'miss-head-red			"missing 'Red' at head"
		'miss-head-block		"missing '[]' at head"
		'miss-expr				"missing 'expr'"
		'miss-block				"missing a block!"
		'miss-spec				"missing a block! for function's spec"
		'miss-body				"missing a block! for function's body"
		'miss-ctx				"missing context for bind"
		'unresolve 				"need resolve unknown type"
		'invalid-refine			"invalid refinement"
		'invalid-datatype		"invalid datatype! in block!"
		'invalid-arg			"invalid argument"
		'double-define			"double define"
		'return-place			"invalid place for 'return:'"
		'forbidden-refine		"forbidden refinement here"
		'no-need-desc			"no need descriptions for"
		'include-not-file		"#include requires a file argument"
	]

	warning-code: [
		'unknown-word			"unknown word"
	]

	create-error: function [type [word!] word [word!] more [string! none!]][
		message: case [
			type = 'Error [copy error-code/(word)]
			type = 'Warning [copy warning-code/(word)]
			true [none]
		]
		if all [
			message
			more
			not empty? more
		][
			append message ": "
			append message more
		]
		make map! reduce [
			'severity DiagnosticSeverity/(type)
			'code to string! word
			'source "Syntax"
			'message message
		]
	]

	create-error-at: function [syntax [map!] type [word!] word [word!] more [string! none!]][
		error: create-error type word more
		either none? syntax/error [
			syntax/error: error
		][
			either block? syntax/error [
				append syntax/error error
			][
				old: syntax/error
				syntax/error: reduce [old error]
			]
		]
	]

	literal-type: reduce [
		binary! char! date! email! file! float!
		get-path! get-word! lit-path! lit-word!
		integer! issue! logic! map! pair! path!
		percent! refinement! string! tag! time!
		tuple! url!
	]

	symbol-type?: function [type][
		case [
			find reduce [date! float! integer! percent! time! tuple! pair!] type [
				SymbolKind/Number
			]
			type = logic! [
				SymbolKind/Boolean
			]
			find reduce [string! char! email! file! issue! tag! url!] type [
				SymbolKind/String
			]
			type = binary! [
				SymbolKind/Array
			]
			find reduce [lit-word! get-word!] type [
				SymbolKind/Constant
			]
			find reduce [get-path! lit-path! path! refinement!] type [
				SymbolKind/Object
			]
			type = map! [
				SymbolKind/Key
			]
		]
	]

	simple-literal?: function [value][
		either find literal-type value [true][false]
	]

	skip-semicolon-next: function [pc [block! paren!]][
		npc: pc
		until [
			npc: next npc
			any [
				tail? npc
				npc/1/syntax/name <> "semicolon"
			]
		]
		npc
	]

	create-pos: function [where [block! paren! none!]][
		if where = none [return none]
		make map! reduce [
			'start	where/1/start
			'end	where/1/end
		]
	]
	
	check-has-spec: function [pc [block!]][
		npc: skip-semicolon-next pc
		if tail? npc [exit]
		if string? npc/1/expr [
			create-error-at pc/1/syntax 'Error 'no-need-desc "has"
			pc: npc
		]
		forall pc [
			if refinement? pc/1/expr [
				create-error-at pc/1/syntax 'Error 'forbidden-refine mold pc/1/expr
			]
		]
	]

	check-func-spec: function [pc [block!] par [block! paren!]][
		words: clear []
		word: none
		double-check: function [pc][
			either find words word: to word! pc/1/expr [
				create-error-at pc/1/syntax 'Error 'double-define to string! word
			][
				append words word
			]
		]
		check-args: function [npc [block!] par [block! paren! none!]][
			syntax: npc/1/syntax
			syntax/name: "func-args"
			syntax/parent: create-pos par
			double-check npc
			npc2: skip-semicolon-next npc
			if tail? npc2 [return npc2]
			type: type? npc2/1/expr
			case [
				type = string! [
					syntax/desc: create-pos npc2
					npc2/1/syntax/parent: create-pos npc
					npc3: skip-semicolon-next npc2
					if tail? npc3 [return npc3]
					if block? npc3/1/expr [
						create-error-at npc3/1/syntax 'Error 'invalid-arg mold npc3/1/expr
						return next npc3
					]
					return npc3
				]
				type = block! [
					expr2: npc2/1/expr
					forall expr2 [
						expr3: expr2/1/expr
						unless any [
							all [
								value? expr3
								datatype? get expr3
							]
							all [
								value? expr3
								typeset? get expr3
							]
						][
							create-error-at expr2/1/syntax 'Error 'invalid-datatype mold expr3
						]
					]
					syntax/spec: create-pos npc2
					npc2/1/syntax/parent: create-pos npc
					npc3: skip-semicolon-next npc2
					if tail? npc3 [return npc3]
					if string? npc3/1/expr [
						syntax/desc: create-pos npc3
						npc3/1/syntax/parent: create-pos npc
						return next npc3
					]
					return npc3
				]
			]
			npc2
		]
		check-return: function [npc [block!]][
			syntax: npc/1/syntax
			syntax/name: "func-return"
			double-check npc
			npc2: skip-semicolon-next npc
			if tail? npc2 [
				create-error-at npc/1/syntax 'Error 'miss-expr "return:"
				return npc2
			]
			unless block? npc2/1/expr [
				create-error-at npc/1/syntax 'Error 'miss-block "return:"
				return npc2
			]
			expr2: npc2/1/expr
			forall expr2 [
				expr3: expr2/1/expr
				unless any [
					all [
						value? expr3
						datatype? get expr3
					]
					all [
						value? expr3
						typeset? get expr3
					]
				][
					create-error-at expr2/1/syntax 'Error 'invalid-datatype mold expr3
				]
			]
			syntax/spec: create-pos npc2
			npc2/1/syntax/parent: create-pos npc
			skip-semicolon-next npc2
		]
		check-refines: function [npc [block!]][
			collect-args: function [npc [block!] par [block!]][
				while [not tail? npc] [
					either word? npc/1/expr [
						either par/1/syntax/spec [
							append par/1/syntax/spec create-pos npc
						][
							par/1/syntax/spec: reduce [create-pos npc]
						]
						npc/1/syntax/parent: create-pos par
						if tail? npc: check-args npc par [return npc]
					][
						either refinement? npc/1/expr [
							return npc
						][
							create-error-at npc/1/syntax 'Error 'invalid-arg mold npc/1/expr
							npc: next npc
						]
					]
				]
				return npc
			]
			syntax: npc/1/syntax
			syntax/name: "func-refines"
			double-check npc
			npc2: skip-semicolon-next npc
			if tail? npc2 [return npc2]
			type: type? npc2/1/expr
			case [
				type = string! [
					syntax/desc: create-pos npc2
					npc2/1/syntax/parent: create-pos npc
					npc3: skip-semicolon-next npc2
					return collect-args npc3 npc
				]
				type = word! [
					return collect-args npc2 npc
				]
				type = refinement! [
					return npc2
				]
				true [
					create-error-at npc2/1/syntax 'Error 'invalid-arg mold npc2/1/expr
					return next npc2
				]
			]
		]
		npc: skip-semicolon-next pc
		if tail? npc [exit]
		if string? npc/1/expr [
			par/1/syntax/desc: create-pos npc
			pc: npc
		]
		return-pc: none
		until [
			expr: pc/1/expr
			case [
				expr = to set-word! 'return [
					return-pc: pc
					pc: check-return pc
				]
				refinement? expr [
					pc: check-refines pc
				]
				find [word! lit-word! get-word!] type? expr [
					if return-pc [
						create-error-at return-pc/1/syntax 'Error 'return-place none
					]
					pc: check-args pc none
				]
				true [
					create-error-at pc/1/syntax 'Error 'invalid-arg mold expr
					pc: skip-semicolon-next pc
				]
			]
			tail? pc
		]
	]

	exp-type?: function [pc [block! paren!]][
		if tail? pc [
			return reduce [none 0]
		]
		expr: pc/1/expr
		expr-type: type? expr
		syntax: pc/1/syntax
		ret: none
		ret2: none
		type: none
		spec: none
		body: none
		step: none
		bind?: none

		check-tail: function [where [block! paren!] result [block!]][
			if result/2 = 0 [
				create-error-at where/1/syntax 'Error 'miss-expr mold where/1/expr
			]
		]

		semicolon-type?: [
			if any [
				all [
					string? expr
					not empty? expr
					expr/1 = #";"
				]
				expr = none
			][
				syntax/name: "semicolon"
				ret: exp-type? next pc
				check-tail pc ret
				ret/2: ret/2 + 1
				return ret
			]
		]

		include-type?: [
			if all [
				expr-type = issue! 
				"include" = to string! expr
			][
				syntax/name: "include"
				ret: exp-type? next pc
				check-tail pc ret
				unless file? ret/1/expr [
					create-error-at syntax 'Error 'include-not-file mold ret/1/expr
				]
				syntax/cast: ret/1
				return reduce [create-pos pc ret/2 + 1]
			]
		]

		literal-type?: [
			if simple-literal? expr-type [
				syntax/name: "literal"
				return reduce [create-pos pc 1]
			]
		]

		set-word-type?: [
			if set-word? expr [
				syntax/name: "set-word"
				ret: exp-type? next pc
				check-tail pc ret
				syntax/cast: ret/1
				ret/2: ret/2 + 1
				return ret
			]
		]

		set-path-type?: [
			if set-path? expr [
				syntax/name: "set-path"
				ret: exp-type? next pc
				check-tail pc ret
				syntax/cast: ret/1
				ret/2: ret/2 + 1
				return ret
			]
		]

		block-type?: [
			if block? expr [
				syntax/name: "block"
				unless empty? expr [
					exp-all expr
				]
				return reduce [create-pos pc 1]
			]
		]

		paren-type?: [
			if paren? expr [
				syntax/name: "paren"
				unless empty? expr [
					exp-all expr
				]
				return reduce [create-pos pc 1]
			]
		]

		all-any-type?: [
			if any [
				expr = 'all
				expr = 'any
			][
				syntax/name: "all/any"
				step: 1
				ret: exp-type? skip pc step
				if ret/2 = 0 [
					create-error-at syntax 'Error 'miss-body to string! expr
					return reduce [create-pos pc 1]
				]
				unless body: find-expr syntax-top ret/1 [
					throw-error 'do-type? "can't find expr at" ret/1
				]
				unless any [
					block? body/1/expr
					word? body/1/expr
					set-word? body/1/expr
				][
					create-error-at syntax 'Error 'miss-body to string! expr
					return reduce [create-pos pc step]
				]
				either set-word? body/1/expr [
					ret2: exp-type? skip pc step
					if ret2/2 = 1 [
						create-error-at syntax 'Error 'miss-body to string! expr
						return reduce [create-pos pc step + 1]
					]
					step: step + ret2/2
				][
					step: step + 1
				]
				syntax/body: ret/1
				body/1/syntax/ctx-parent: create-pos pc
				body/1/syntax/ctx: reduce [expr 'body]
				return reduce [create-pos pc step]
			]
		]

		do-type?: [
			if expr = 'do [
				syntax/name: "do"
				step: 1
				ret: exp-type? skip pc step
				if ret/2 = 0 [
					create-error-at syntax 'Error 'miss-spec "do"
					return reduce [create-pos pc 1]
				]
				unless body: find-expr syntax-top ret/1 [
					throw-error 'do-type? "can't find expr at" ret/1
				]
				if body/1/expr = 'bind [
					bind?: true
					body/1/syntax/ctx-parent: create-pos pc
					step: step + 1
					ret: exp-type? skip pc step
					if ret/2 = 0 [
						create-error-at syntax 'Error 'miss-body "do"
						return reduce [create-pos pc 2]
					]
					unless body: find-expr syntax-top ret/1 [
						throw-error 'do-type? "can't find expr at" ret/1
					]
				]
				unless any [
					block? body/1/expr
					word? body/1/expr
					set-word? body/1/expr
				][
					create-error-at syntax 'Error 'miss-body "do"
					return reduce [create-pos pc step]
				]
				either set-word? body/1/expr [
					ret2: exp-type? skip pc step
					if ret2/2 = 1 [
						create-error-at syntax 'Error 'miss-ctx "do"
						return reduce [create-pos pc step + 1]
					]
					step: step + ret2/2
				][
					step: step + 1
				]
				syntax/body: ret/1
				body/1/syntax/ctx-parent: create-pos pc
				body/1/syntax/ctx: reduce [expr 'body]
				if bind? [
					ret: exp-type? skip pc step
					if ret/2 = 0 [
						create-error-at syntax 'Error 'miss-ctx "do"
						return reduce [create-pos pc step]
					]
					unless body: find-expr syntax-top ret/1 [
						throw-error 'do-type? "can't find expr at" ret/1
					]
					unless any [
						word? body/1/expr
						lit-word? body/1/expr
						set-word? body/1/expr
					][
						create-error-at syntax 'Error 'miss-ctx "do"
						return reduce [create-pos pc step]
					]
					either set-word? body/1/expr [
						ret2: exp-type? skip pc step
						if ret2/2 = 1 [
							create-error-at syntax 'Error 'miss-ctx "do"
							return reduce [create-pos pc step + 1]
						]
						step: step + ret2/2
					][
						step: step + 1
					]
					syntax/bind: ret/1
					body/1/syntax/ctx-parent: create-pos pc
					body/1/syntax/ctx: reduce [expr 'bind]
				]
				return reduce [create-pos pc step]
			]
		]

		context-type?: [
			if find [has func function does context] expr [
				syntax/name: "context"
				step: 1
				if find [has func function] expr [
					ret: exp-type? skip pc step
					if ret/2 = 0 [
						create-error-at syntax 'Error 'miss-spec to string! expr
						return reduce [create-pos pc 1]
					]
					unless spec: find-expr syntax-top ret/1 [
						throw-error 'context-type? "can't find expr at" ret/1
					]
					either spec/1/syntax/name = "block" [
						if expr = 'has [
							check-has-spec spec/1/expr
						]
						check-func-spec spec/1/expr spec
						step: step + 1
					][
						unless any [
							word? spec/1/expr
							set-word? spec/1/expr
						][
							create-error-at syntax 'Error 'miss-spec to string! expr
							return reduce [create-pos pc 1]
						]
						either set-word? spec/1/expr [
							ret2: exp-type? skip pc step
							if ret2/2 = 1 [
								create-error-at syntax 'Error 'miss-spec to string! expr
								return reduce [create-pos pc step + 1]
							]
							step: step + ret2/2
						][
							step: step + 1
						]
					]
					syntax/spec: ret/1
					spec/1/syntax/ctx-parent: create-pos pc
					spec/1/syntax/ctx: reduce [expr 'spec]
				]
				ret: exp-type? skip pc step
				if ret/2 = 0 [
					create-error-at syntax 'Error 'miss-body to string! expr
					return reduce [create-pos pc step]
				]
				unless body: find-expr syntax-top ret/1 [
					throw-error 'context-type? "can't find expr at" ret/1
				]
				unless any [
					block? body/1/expr
					word? body/1/expr
					set-word? body/1/expr
				][
					create-error-at syntax 'Error 'miss-body to string! expr
					return reduce [create-pos pc step]
				]
				either set-word? body/1/expr [
					ret2: exp-type? skip pc step
					if ret2/2 = 1 [
						create-error-at syntax 'Error 'miss-body to string! expr
						return reduce [create-pos pc step + 1]
					]
					step: step + ret2/2
				][
					step: step + 1
				]
				syntax/body: ret/1
				body/1/syntax/ctx-parent: create-pos pc
				body/1/syntax/ctx: reduce [expr 'body]
				body/1/syntax/spec: syntax/spec
				return reduce [create-pos pc step]
			]
		]

		keyword-type?: [
			if all [
				expr-type = word!
				find system-words/system-words expr
			][
				syntax/name: "keyword"
				type: type? get expr
				;if find [action! native! function! routine!] type [
				;]
				return reduce [create-pos pc 1]
			]
		]

		unknown-type?: [
			if expr-type = word! [
				syntax/name: "unknown"
				return reduce [create-pos pc 1]
			]
		]

		do semicolon-type?
		do include-type?
		do literal-type?
		do set-word-type?
		do set-path-type?
		do block-type?
		do paren-type?
		do all-any-type?
		do do-type?
		do context-type?
		do keyword-type?
		do unknown-type?
		throw-error 'exp-type "not support!" pc/1/expr
	]

	exp-all: function [pc [block! paren!]][
		while [not tail? pc][
			type: exp-type? pc
			pc: skip pc type/2
		]
	]

	analysis: function [top [block!]][
		set 'syntax-top top
		if empty? top [exit]
		unless all [
			top/1/expr
			block? top/1/expr
		][throw-error 'analysis "expr isn't a block!" top/1]
		pc: top/1/expr
		top/1/syntax/ctx: [context body]
		top/1/syntax/name: "block"
		unless pc/1/expr = 'Red [
			create-error-at pc/1/syntax 'Error 'miss-head-red none
		]
		unless block? pc/2/expr [
			create-error-at pc/2/syntax 'Error 'miss-head-block none
		]
		pc/1/syntax/meta: 1
		pc/2/syntax/meta: 2
		exp-all pc
		raise-set-word top
		;resolve-unknown top
	]

	collect-errors: function [top [block! paren!]][
		ret: clear []
		collect-errors*: function [pc [block! paren!]][
			blk: [
				if all [
					pc/1/syntax
					pc/1/syntax/error
				][
					error: copy pc/1/syntax/error
					error/range: red-lexer/to-range pc/1/start pc/1/end
					append ret error
				]
			]
			forall pc [
				either all [
					map? pc/1
					any [
						block? pc/1/expr
						paren? pc/1/expr
					]
					not empty? pc/1/expr
				][
					do blk
					collect-errors* pc/1/expr
				][
					if map? pc/1 [
						do blk
					]
				]
			]
		]
		collect-errors* top
		ret
	]

	func-arg?: function [top [block!] pos [map!] word [word!]][
		unless spec*: find-expr top pos [
			throw-error 'func-arg? "can't find expr at" pos
		]
		spec: spec*/1/expr
		if block? spec [
			forall spec [
				if find [word! lit-word! get-word! refinement!] type? spec/1/expr [
					if (to word! spec/1/expr) = word [
						return create-pos spec
					]
				]
			]
		]
		false
	]

	raise-set-word: function [top [block!]][
		raise: function [pc [block! paren!]][
			dpar: get-parent top pc/1
			raise?: function [par [block! paren!]][
				if all [
					par/1/syntax/name = "block"
					ctx: par/1/syntax/ctx
					ctx/2 = 'body
				][
					switch ctx/1 [
						function [
							if pos: func-arg? top par/1/syntax/spec to word! pc/1/expr [
								pc/1/syntax/parent: pos
							]
							return false
						]
						func has [
							if pos: func-arg? top par/1/syntax/spec to word! pc/1/expr [
								pc/1/syntax/parent: pos
								return false
							]
						]
						context [
							if par = dpar [
								pc/1/syntax/parent: create-pos par
								return false
							]
						]
					]
				]
				npc: head par
				forall npc [
					if all [
						npc/1/syntax
						npc/1/syntax/name = "set-word"
						pc/1/expr = npc/1/expr
					][
						pc/1/syntax/parent: create-pos npc
						return false
					]
				]
				return true
			]
			; if not first appear, mark it as first one's child
			hpc: head pc
			while [hpc <> pc][
				if all [
					hpc/1/syntax
					hpc/1/syntax/name = "set-word"
					hpc/1/expr = pc/1/expr
				][
					pc/1/syntax/parent: create-pos hpc
					exit
				]
				hpc: next hpc
			]
			; now mark first appear set-word!
			par: pc
			while [par: get-parent top par/1][
				unless raise? par [exit]
			]
			; mark it as global word
			either top/1/syntax/extra [
				append top/1/syntax/extra create-pos pc
			][
				top/1/syntax/extra: reduce [create-pos pc]
			]
			pc/1/syntax/parent: create-pos top
		]
		raise-set-word*: function [pc [block! paren!]][
			forall pc [
				either all [
					any [
						block? pc/1/expr
						paren? pc/1/expr
					]
					not empty? pc/1/expr
				][
					raise-set-word* pc/1/expr
				][
					if all [
						pc/1/syntax
						pc/1/syntax/name = "set-word"
					][
						raise pc
					]
				]
			]
		]

		raise-set-word* top/1/expr
	]

	resolve-unknown: function [top [block!]][
		resolve-ctx: function [pc [block! paren!]][
			resolve-ctx*: function [par [block! paren!]][
				if all [
					par/1/syntax/ctx = 'context
					vars: par/1/syntax/vars
				][
					forall vars [
						if pc/1/expr = to word! vars/1/expr [
							pc/1/syntax/cast: vars/1
							pc/1/syntax/name: "resolved"
							pc/1/syntax/resolved-type: 'context
							return true
						]
					]
					return false
				]
				if any [
					all [
						any [
							par/1/syntax/ctx = 'func
							par/1/syntax/ctx = 'function
							par/1/syntax/ctx = 'has
						]
						par/1/syntax/ctx-index = 2
					]
					par/1/syntax/ctx = 'does
				][
					if par/1/syntax/spec [
						if ret: func-arg? pc par [
							pc/1/syntax/cast: ret
							pc/1/syntax/name: "resolved"
							pc/1/syntax/resolved-type: 'spec
							return true
						]
					]
					if vars: par/1/syntax/vars [
						forall vars [
							if pc/1/expr = to word! vars/1/expr [
								pc/1/syntax/cast: vars/1
								pc/1/syntax/name: "resolved"
								pc/1/syntax/resolved-type: 'function
								return true
							]
						]
					]
					return false
				]
			]
			par: pc
			while [par: get-parent top par/1][
				if resolve-ctx* par [return true]
			]
			false
		]

		resolve-unknown*: function [pc [block! paren!]][
			forall pc [
				either all [
					map? pc/1
					any [
						block? pc/1/expr
						paren? pc/1/expr
					]
					not empty? pc/1/expr
				][
					resolve-unknown* pc/1/expr
				][
					if all [
						map? pc/1
						pc/1/syntax
						pc/1/syntax/name = "unknown"
					][
						unless resolve-ctx pc [
							create-error-at pc/1/syntax 'Warning 'unknown-word mold pc/1/expr
						]
					]
				]
			]
		]

		resolve-unknown* top
	]

	get-parent: function [top [block!] item [map!]][
		get-parent*: function [pc [block! paren!] par [block! paren!]][
			forall pc [
				if all [
					item/start = pc/1/start
					item/end = pc/1/end
				][return par]
				if all [
					any [
						block? pc/1/expr
						paren? pc/1/expr
					]
					not empty? pc/1/expr
				][
					if ret: get-parent* pc/1/expr pc [return ret]
				]
			]
			none
		]
		if top/1 = item [return none]
		get-parent* top/1/expr top
	]

	find-expr: function [top [block! paren!] pos [map!]][
		find-expr*: function [pc [block! paren!] pos [map!]][
			forall pc [
				if all [
					pc/1/start = pos/start
					pc/1/end   = pos/end
				][
					return pc
				]
				if all [
					any [
						block? pc/1/expr
						paren? pc/1/expr
					]
					not empty? pc/1/expr
				][
					if ret: find-expr* pc/1/expr pos [return ret]
				]
			]
			none
		]
		find-expr* top pos
	]

	position?: function [top [block! paren!] line [integer!] column [integer!]][
		position*: function [pc [block! paren!] line [integer!] column [integer!]][
			cascade: [
				if all [
					any [
						block? pc/1/expr
						paren? pc/1/expr
					]
					not empty? pc/1/expr
				][
					if ret: position* pc/1/expr line column [return ret]
				]
				return pc
			]
			ret: none
			forall pc [
				if all [
					any [
						pc/1/start/1 < line
						all [
							pc/1/start/1 = line
							pc/1/start/2 <= column
						]
					]
				][
					either any [
						pc/1/end/1 > line
						all [
							pc/1/end/1 = line
							pc/1/end/2 > column
						]
					][
						do cascade
					][
						if all [
							pc/1/end/1 = line
							pc/1/end/2 = column
							any [
								tail? next pc
								all [
									pc/2/start/1 >= line
									pc/2/start/2 <> column
								]
							]
						][
							do cascade
						]
					]
				]
			]
			none
		]
		position* top line column
	]

	collect-completions: function [top [block!] str [string! none!] line [integer!] column [integer!]][
		words: clear []
		unique?: function [word [string!]][
			forall words [
				if words/1/1 = word [return false]
			]
			true
		]
		collect-set-word: function [pc [block! paren!]][
			forall pc [
				if all [
					map? pc/1
					pc/1/syntax
					pc/1/syntax/name = "set-word"
				][
					word: to string! pc/1/expr
					if any [
						empty? str
						find/match word str
					][
						if unique? word [
							append/only words reduce [word pc/1]
						]
					]
				]
			]
		]

		unless pc: position? top line column [
			pc: top
		]
		if all [
			any [
				block? pc/1/expr
				paren? pc/1/expr
			]
			not empty? pc/1/expr
			any [
				pc/1/end/1 > line
				all [
					pc/1/end/1 = line
					pc/1/end/2 > column
				]
			]
		][
			collect-set-word pc/1/expr
		]
		collect-set-word head pc
		if top = head pc [return words]
		par: pc
		while [par: get-parent top par/1][
			either empty? par [
				break
			][
				collect-set-word head par
			]
		]
		words
	]

	get-completions: function [top [block!] str [string! none!] line [integer!] column [integer!]][
		if any [
			none? str
			empty? str
			#"%" = str/1
			find str #"/"
		][return none]
		if empty? resolve-block: collect-completions top str line column [return none]
		words: reduce ['word]
		forall resolve-block [
			kind: CompletionItemKind/Variable
			cast: resolve-block/1/2/syntax/cast
			if all [
				cast/expr
				find [does has func function] cast/expr
			][
				kind: cast/CompletionItemKind
			]
			append/only words reduce [resolve-block/1/1 kind]
		]
		words
	]

	resolve-completion: function [top [block!] str [string! none!] line [integer!] column [integer!]][
		if any [
			none? str
			empty? str
			#"%" = str/1
			find str #"/"
		][return ""]
		if empty? resolve-block: collect-completions top str line column [return ""]
		forall resolve-block [
			if resolve-block/1/1 = str [
				item: resolve-block/1/2
				cast: item/syntax/cast
				either all [
					cast/expr
					find [does has func function] cast/expr
				][
					return rejoin [str " is a " to string! cast/expr]
				][
					return rejoin [str " is a variable"]
				]
			]
		]
		""
	]

	hover: function [top [block!] line [integer!] column [integer!]][
		pc: position? top line column
		range: red-lexer/to-range pc/1/start pc/1/end
		expr: pc/1/expr
		case [
			pc/1/syntax/name = "set-word" [
				res: rejoin [to string! expr " is a variable"]
				return reduce [res range]
			]
			path? expr [
				if find system-words/system-words expr/1 [
					res: system-words/get-word-info expr/1
					return reduce [res range]
				]
			]
			word? expr [
				if find system-words/system-words expr [
					either datatype? get expr [
						res: rejoin [to string! expr " is a base datatype!"]
						return reduce [res range]
					][
						res: system-words/get-word-info expr
						return reduce [res range]
					]
				]
				res: either pc/1/syntax/name = "resolved" [
					rejoin [to string! expr " is a resolved word"]
				][
					rejoin [to string! expr " is a unknown word"]
				]
				return reduce [res range]
			]
		]
		return none
	]
]
