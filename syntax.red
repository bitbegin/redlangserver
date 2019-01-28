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
		'miss-define			"missing define for"
		'miss-blk-define		"missing block! define for"
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

	exp-type?: function [pc [block! paren!]][
		if tail? pc [
			return reduce [none 0]
		]
		expr: pc/1/expr
		expr-type: type? expr
		syntax: pc/1/syntax
		ret: none
		type: none
		spec: none
		name: none
		rname: none
		params: none
		rparams: none
		refinements: none
		res: none
		body: none
		step: none

		check-tail: function [where [block! paren!] result [block!]][
			if result/2 = 0 [
				create-error-at where/1/syntax 'Error 'miss-expr rejoin [mold where/1/expr ": need a type"]
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
				return reduce [pc/1/range ret/2 + 1]
			]
		]

		literal-type?: [
			if simple-literal? expr-type [
				syntax/name: "literal"
				return reduce [pc/1/range 1]
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
				return reduce [pc/1/range 1]
			]
		]

		paren-type?: [
			if paren? expr [
				syntax/name: "paren"
				unless empty? expr [
					exp-all expr
				]
				return reduce [pc/1/range 1]
			]
		]

		function*?: [
			step: 1
			unless spec: system-words/get-spec expr [
				throw-error 'keyword? "can't find spec for" expr
			]
			syntax/spec: spec
			params: spec/params refinements: spec/refinements
			forall params [
				ret: exp-type? skip pc step
				name: params/1/name
				type: params/1/type
				if ret/2 = 0 [
					create-error-at syntax 'Error 'miss-expr rejoin [mold expr "'s " mold name ": need type of '" mold type "'"]
					return reduce [pc/1/range step]
				]
				unless body: find-expr syntax-top ret/1 [
					throw-error 'keyword? "can't find expr at" ret/1
				]
				put syntax/args name body/1/range
				body/1/syntax/keyword: expr
				body/1/syntax/parent: pc/1/range
				body/1/syntax/args: make map! 2
				body/1/syntax/args/name: name
				body/1/syntax/args/type: type
				step: step + ret/2
			]
			if expr-type = word! [
				return reduce [pc/1/range step]
			]
			forall refinements [
				rname: refinements/1/name
				rparams: refinements/1/params
				if empty? rparams [continue]
				unless find expr rname [continue]
				res: make map! 4
				forall rparams [
					params: rparams/1
					ret: exp-type? skip pc step
					name: params/name
					type: params/type
					if ret/2 = 0 [
						create-error-at syntax 'Error 'miss-expr rejoin [mold expr "'s " mold rname ": need type of '" mold type "'"]
						return reduce [pc/1/range step]
					]
					unless body: find-expr syntax-top ret/1 [
						throw-error 'keyword? "can't find expr at" ret/1
					]
					put res name body/1/range
					body/1/syntax/keyword: expr
					body/1/syntax/parent: pc/1/range
					body/1/syntax/refs: make map! 3
					body/1/syntax/refs/name: name
					body/1/syntax/refs/type: type
					body/1/syntax/refs/refname: rname
					step: step + ret/2
				]
				put syntax/refs to word! rname res
			]
			return reduce [pc/1/range step]
		]

		keyword-type?: [
			if any [
				all [
					expr-type = word!
					find system-words/system-words expr
				]
				all [
					expr-type = path!
					find system-words/system-words expr/1
				]
			][
				syntax/name: "keyword"
				if any [
					all [
						expr-type = word!
						find reduce [native! action! function! routine!] type? get expr
					]
					all [
						expr-type = path!
						find reduce [native! action! function! routine!] type? get expr/1
					]
				][
					syntax/function?: true
					syntax/args: make map! 4
					syntax/refs: make map! 4
					;-- TBD
					;syntax/return: make map! 1
					do function*?
				]
				return reduce [pc/1/range 1]
			]
		]

		unknown-type?: [
			if expr-type = word! [
				syntax/name: "unknown"
				return reduce [pc/1/range 1]
			]
		]

		do semicolon-type?
		do include-type?
		do literal-type?
		do set-word-type?
		do set-path-type?
		do block-type?
		do paren-type?
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
		unless pc/1/expr = 'Red [
			create-error-at pc/1/syntax 'Error 'miss-head-red none
		]
		unless block? pc/2/expr [
			create-error-at pc/2/syntax 'Error 'miss-head-block none
		]
		pc/1/syntax/meta: 1
		pc/2/syntax/meta: 2
		exp-all pc
		probe top
		resolve-spec top
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
					error/range: red-lexer/form-range pc/1/range
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

	find-set-word: function [top [block!] pc [block! paren!] /datatype type][
		word: to word! pc/1/expr
		match?: function [npc [block! paren!]][
			forall npc [
				if all [
					npc/1/syntax/name = "set-word"
					word = to word! npc/1/expr
				][
					unless cast: find-expr top npc/1/syntax/cast [
						throw-error 'match? "can't find expr at" npc/1/cast
					]
					if word? cast/1/expr [
						ret: either datatype [
							find-set-word/datatype top cast type
						][
							find-set-word top cast
						]
						if ret [
							cast/1/syntax/ctx/define: ret/1/range
							cast/1/syntax/name: "resolved"
							return ret
						]
					]
					either datatype [
						fn: get type
						if fn cast/1/expr [
							return cast
						]
					][
						return cast
					]
				]
			]
			false
		]
		par: pc
		until [
			if ret: match? head par [return ret]
			par: get-parent top par/1
		]
		false
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
			syntax/name: "func-name"
			syntax/args: make map! 3
			if par [syntax/args/refs: par/1/range]
			double-check npc
			npc2: skip-semicolon-next npc
			if tail? npc2 [return npc2]
			type: type? npc2/1/expr
			case [
				type = string! [
					syntax/args/desc: npc2/1/range
					npc2/1/name: "func-desc"
					npc2/1/syntax/parent: npc/1/range
					npc3: skip-semicolon-next npc2
					if tail? npc3 [return npc3]
					if block? npc3/1/expr [
						create-error-at npc3/1/syntax 'Error 'invalid-arg mold npc3/1/expr
						return next npc3
					]
					return npc3
				]
				type = block! [
					syntax/args/type: npc2/1/range
					npc2/1/name: "func-type"
					npc2/1/syntax/parent: npc/1/range
					npc2/1/syntax/args: make map! 1
					npc2/1/syntax/args/type: clear []
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
						append/only npc2/1/syntax/args/type expr3
					]
					npc3: skip-semicolon-next npc2
					if tail? npc3 [return npc3]
					if string? npc3/1/expr [
						syntax/args/desc: npc3/1/range
						npc3/1/name: "func-desc"
						npc3/1/syntax/parent: npc/1/range
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
				create-error-at npc/1/syntax 'Error 'miss-expr {"return:" need a block!}
				return npc2
			]
			unless block? npc2/1/expr [
				create-error-at npc/1/syntax 'Error 'miss-block "return:"
				return npc2
			]
			syntax/args: make map! 1
			syntax/args/type: np2c/1/range
			npc2/1/name: "func-type"
			npc2/1/syntax/parent: npc/1/range
			npc2/1/syntax/args: make map! 1
			npc2/1/syntax/args/type: clear []
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
				append/only npc2/1/syntax/args/type expr3
			]
			skip-semicolon-next npc2
		]
		check-refines: function [npc [block!]][
			collect-args: function [npc [block!] par [block!]][
				while [not tail? npc] [
					either word? npc/1/expr [
						append par/1/syntax/params npc/1/range
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
			syntax/args: make map! 2
			syntax/args/params: clear []
			double-check npc
			npc2: skip-semicolon-next npc
			if tail? npc2 [return npc2]
			type: type? npc2/1/expr
			case [
				type = string! [
					syntax/args/desc: npc2/1/range
					npc2/1/name: "func-desc"
					npc2/1/syntax/parent: npc/1/range
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
			par/1/syntax/desc: npc/1/range
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

	resolve-spec: function [top [block!]][
		resolve-func: function [pc [block! paren!]][
			unless args: pc/1/syntax/args [
				throw-error 'resolve-func "parse func error!" mold pc/1
			]
			if args/name = 'spec [
				unless ret: find-set-word/datatype top pc 'block? [
					create-error-at pc/1/syntax 'Error 'miss-blk-define to string! pc/1/expr
					exit
				]

			]
		]
		resolve: function [pc [block! paren!]][
			type: pc/1/syntax/ctx/type
			if type = [do bind][
				unless ret: find-set-word top pc [
					create-error-at pc/1/syntax 'Error 'miss-define to string! pc/1/expr
					exit
				]
				pc/1/syntax/ctx/define: ret/1/range
				exit
			]
			if any [
				type = [all body]
				type = [any body]
			][
				unless ret: find-set-word/blk? top pc [
					create-error-at pc/1/syntax 'Error 'miss-blk-define to string! pc/1/expr
					exit
				]
				pc/1/syntax/ctx/define: ret/1/range
				exit
			]
			if type/2 = 'spec [
				unless ret: find-set-word/blk? top pc [
					create-error-at pc/1/syntax 'Error 'miss-blk-define to string! pc/1/expr
					exit
				]
				unless par: find-expr top pc/1/syntax/ctx/parent [
					throw-error 'resolve "can't find expr at" pc/1/syntax/ctx/parent
				]
				if par/1/expr = 'has [
					check-has-spec ret/1/expr
				]
				check-func-spec ret/1/expr ret
				pc/1/syntax/ctx/define: ret/1/range
				exit
			]
			if type/2 = 'body [
				unless ret: find-set-word/blk? top pc [
					create-error-at pc/1/syntax 'Error 'miss-blk-define to string! pc/1/expr
					exit
				]
				pc/1/syntax/ctx/define: ret/1/range
				exit
			]
		]
		resolve-spec*: function [pc [block! paren!]][
			forall pc [
				either all [
					any [
						block? pc/1/expr
						paren? pc/1/expr
					]
					not empty? pc/1/expr
				][
					resolve-spec* pc/1/expr
				][
					keyword: pc/1/syntax/keyword
					if find [func function has does do bind all any] keyword [
						fn: to word! append copy "resolve-" to string! keyword
						do bind fn resolve-spec
					]
				]
			]
		]
		resolve-spec* top/1/expr
	]

	func-arg?: function [top [block!] pos [map!] word [word!]][
		unless spec*: find-expr top pos [
			throw-error 'func-arg? "can't find expr at" pos
		]
		unless block? spec: spec*/1/expr [
			either any [
				all [
					word? spec/1/expr
					npos: spec/1/syntax/ctx/define
				]
				all [
					set-word? spec/1/expr
					npos: spec/1/syntax/cast
				]
			][
				unless spec: find-expr top npos [
					throw-error 'func-arg? "can't find expr at" npos
				]
				while [set-word? spec/1/expr][
					npos: spec/1/syntax/cast
					unless spec: find-expr top npos [
						throw-error 'func-arg? "can't find expr at" npos
					]
				]
			][return false]
		]
		if block? spec [
			forall spec [
				if find [word! lit-word! get-word! refinement!] type? spec/1/expr [
					if (to word! spec/1/expr) = word [
						return spec/1/range
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
					type: par/1/syntax/ctx/type
					type/2 = 'body
				][
					switch type/1 [
						function [
							if pos: func-arg? top par/1/syntax/ctx/spec to word! pc/1/expr [
								pc/1/syntax/parent: pos
							]
							return false
						]
						func has [
							if pos: func-arg? top par/1/syntax/ctx/spec to word! pc/1/expr [
								pc/1/syntax/parent: pos
								return false
							]
						]
						context [
							if par = dpar [
								pc/1/syntax/parent: par/1/range
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
						pc/1/syntax/parent: npc/1/range
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
					pc/1/syntax/parent: hpc/1/range
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
				append top/1/syntax/extra pc/1/range
			][
				top/1/syntax/extra: reduce [pc/1/range]
			]
			pc/1/syntax/parent: top/1/range
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
				if item/range = pc/1/range [return par]
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

	find-expr: function [top [block! paren!] pos [block!]][
		find-expr*: function [pc [block! paren!] pos [block!]][
			forall pc [
				if pc/1/range = pos [
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
						pc/1/range/1 < line
						all [
							pc/1/range/1 = line
							pc/1/range/2 <= column
						]
					]
				][
					either any [
						pc/1/range/3 > line
						all [
							pc/1/range/3 = line
							pc/1/range/4 > column
						]
					][
						do cascade
					][
						if all [
							pc/1/range/3 = line
							pc/1/range/4 = column
							any [
								tail? next pc
								all [
									pc/2/range/3 >= line
									pc/2/range/4 <> column
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
