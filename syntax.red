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
		'miss-type				"missing type"
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

	create-error: function [syntax [map!] type [word!] word [word!] message [string! none!]][
		error: make map! reduce [
			'severity DiagnosticSeverity/(type)
			'code to string! word
			'source "Syntax"
			'message message
		]
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
		lit-path! lit-word!
		integer! issue! logic! map! pair!
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
			find reduce [lit-word!] type [
				SymbolKind/Constant
			]
			find reduce [lit-path! refinement!] type [
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

	next-type: function [pc [block! paren!]][
		step: 1
		pc: next pc
		while [not tail? pc][
			either pc/1/syntax/name = "semicolon" [
				pc: skip pc 1
				step: step + 1
			][
				break
			]
		]
		reduce [pc step]
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

	func-arg?: function [spec [block! paren!] word [word!]][
		expr: spec/1/expr
		if block? expr [
			forall expr [
				if find [word! lit-word! get-word! refinement!] type?/word expr/1/expr [
					if word = to word! expr/1/expr [
						return expr
					]
				]
			]
		]
		false
	]

	syntax-error: function [pc [block! paren!] type [word!]][
		switch type [
			miss-expr [
				create-error pc/1/syntax 'Error 'miss-expr
					rejoin [mold pc/1/expr ": need a value"]
			]
			recursive-define [
				create-error pc/1/syntax 'Error 'recursive-define
					rejoin ["recursive define for: " mold pc/1/expr]
			]
			need-file [
				create-error pc/1/syntax 'Error 'need-file
					rejoin [mold pc/1/expr ": need a file! literal"]
			]
			miss-head [
				create-error pc/1/syntax 'Error 'miss-head "miss 'Red' for Red File header"
			]
			miss-head-block [
				create-error pc/1/syntax 'Error 'miss-head "miss block! for Red File header"
			]
			unsupport [
				create-error pc/1/syntax 'Error 'unsupport "unsupport for now"
			]
			miss-define [
				create-error pc/1/syntax 'Error 'miss-define
					rejoin [mold pc/1/expr ": need a definition"]
			]
		]
	]

	mark-word: function [top [block!] pc [block! paren!]][
		unless any-word? pc/1/expr [return false]
		word: to word! pc/1/expr
		mark-set-word: function [npc [block! paren!]][
			forall npc [
				if all [
					npc/1/syntax/name = "set-word"
					word = to word! npc/1/expr
				][
					;-- tail
					unless cast: npc/1/syntax/cast [
						return false
					]
					;-- recursive define
					if cast/1 = pc/1 [
						syntax-error npc 'recursive-define
						return false
					]
					;-- nested define
					if any [
						word? cast/1/expr
						get-word? cast/1/expr
					][
						if ret: mark-word top cast [
							cast/1/syntax/parent: ret
							cast/1/syntax/name: "refer"
							return ret
						]
					]
					return cast
				]
			]
			false
		]
		mark-func-spec: function [npc [block! paren!]][
			if all [
				find [func function has] npc/1/syntax/keyword
				npc/1/syntax/args
				npc/1/syntax/args/name = 'body
			][
				par: top npc/1/syntax/parent
				if all [
					par/1/syntax/resolved
					spec: par/1/syntax/resolved/spec
					ret: func-arg? spec word
				][
					return ret
				]
			]
			false
		]
		par: pc
		until [
			if any [
				ret: mark-func-spec par
				ret: mark-set-word head par
			][
				if any [
					word? pc/1/expr
					get-word? pc/1/expr
				][
					pc/1/syntax/parent: ret
					pc/1/syntax/name: "refer"
				]
				return ret
			]
			not par: get-parent top par/1
		]
		false
	]

	word-value?: function [pc [block! paren!]][
		type: type? pc/1/expr
		case [
			find reduce [word! get-word!] type [
				if find/match pc/1/syntax/name "keyword-" [
					return reduce [true pc]
				]
				if all [
					pc/1/syntax/name = "refer"
					pc/1/syntax/parent
				][
					return word-value? pc/1/syntax/parent
				]
				return reduce [false pc]
			]
			type = set-word! [
				if pc/1/syntax/cast [
					return word-value? pc/1/syntax/cast
				]
				return reduce [false pc]
			]
		]
		reduce [true pc]
	]

	resolve-refer: function [top [block!] pc [block! paren!]][
		forall pc [
			if any [
				word? pc/1/expr
				get-word? pc/1/expr
			][
				if npc: mark-word top pc [
					if all [
						(head npc) = head pc
						(index? npc) > index? pc
					][
						unless find [function func does has context] npc/1/expr [
							create-error pc/1/syntax 'Error 'beyond-scope
								rejoin ["find define at: " mold red-lexer/form-range npc/1/range ", but beyond scope"]
						]
					]
				]
			]
		]
	]

	resolve-keyword: function [top [block!]][
		type*?: function [pc [block! paren!] stype][
			fn: get to word! replace to string! stype "!" "?"
			if error? ret: try [fn pc/1/expr][
				return true
			]
			ret
		]
		direct-type*?: function [pc [block! paren!] type [block!]][
			forall type [
				if any [
					datatype? reduce type/1
					typeset? reduce type/1
				][
					if type/1 = 'any-type! [return true]
					if type*? pc type/1 [return true]
				]
			]
			false
		]
		resolve-user-func: function [pc [block! paren!]][
			
		]
		resolve-spec: function [par [block! paren!] pc [block! paren!] name [word! lit-word!] type [block!]][
			cast-expr: function [direct [block! paren!] resolved [block! paren!]][
				put par/1/syntax/args name direct
				put par/1/syntax/resolved name resolved
			]
			npc: none
			step: none
			set [npc step] next-type pc
			if tail? npc [
				syntax-error pc 'miss-expr
				return reduce [false step]
			]
			if lit-word? name [
				if direct-type*? npc type [
					cast-expr npc npc
					return reduce [true step]
				]
				return reduce [false step]
			]
			type: type? npc/1/expr
			either type = set-word! [
				step: step + 1
				;-- tail
				unless cast: npc/1/syntax/cast [
					return reduce [false step]
				]
			][
				cast: npc
			]
			;-- recursive resolve
			if cast/1/syntax/name = "unknown-keyword" [
				resolve-keyword* cast
				if cast/1/syntax/name = "unknown-keyword" [
					return reduce [false step]
				]
			]
			dst: cast
			if cast/1/syntax/name = "refer" [
				ret: word-value? cast
				dst: ret/2
				unless ret/1 [
					;-- tail
					if set-word? dst/1/expr [
						return reduce [false step]
					]
					resolve-keyword* dst
					if dst/1/syntax/name = "unknown-keyword" [
						return reduce [false step]
					]
				]
			]
			case [
				find [does has context] dst/1/expr [
					cast-expr npc dst
					return reduce [true step]
				]
				find [func function] dst/1/expr [
					cast-expr npc dst
					return reduce [true step]
				]
			]
			cast-expr npc dst
			reduce [true step]
		]
		resolve-keyword*: function [pc [block! paren!]][
			par: pc
			expr: pc/1/expr
			syntax: pc/1/syntax
			word: either word? expr [expr][expr/1]
			type: type?/word get word
			step: none
			spec: none
			rname: none
			params: none
			rparams: none
			refinements: none
			ret: none
			refs?: none

			function*?: [
				if find [native! action! function! routine!] type [
					syntax/name: "keyword-function"
					syntax/args: make map! 4
					syntax/resolved: make map! 8
					step: 0
					unless spec: system-words/get-spec word [
						throw-error 'function*? "can't find spec for" word
					]
					params: spec/params
					refinements: spec/refinements
					syntax/params: params
					syntax/refinements: refinements
					forall params [
						ret: resolve-spec par pc params/1/name params/1/type
						unless ret/1 [
							return reduce [false pc ret/2]
						]
						step: step + ret/2
						pc: skip pc step
					]
					;-- path?
					if word? expr [
						return reduce [true pc 1]
					]
					forall refinements [
						rname: refinements/1/name
						rparams: refinements/1/params
						if empty? rparams [continue]
						unless find expr rname [continue]
						forall rparams [
							refs?: true
							params: rparams/1
							ret: resolve-spec par pc params/1/name params/1/type
							unless ret/1 [
								return reduce [false pc ret/2]
							]
							step: step + ret/2
							pc: skip pc step
						]
					]
					unless refs? [
						return reduce [false pc step]
					]
					return reduce [true pc step]
				]
			]

			op*?: [
				if type = 'op! [
					syntax/name: "keyword-op"
				]
			]

			object*?: [
				if type = 'object! [
					syntax/name: "keyword-object"
				]
			]

			do function*?
			do op*?
			do object*?
			throw-error 'resolve-keyword* "not support!" expr
		]

		resolve-depth: function [pc [block! paren!] depth [integer!]][
			if pc/1/depth > depth [exit]
			forall pc [
				either pc/1/depth = depth [
					if all [
						any [
							word? pc/1/expr
							path? pc/1/expr
						]
						pc/1/syntax/name = "unknown-keyword"
					][
						resolve-keyword* pc
					]
				][
					if all [
						any [
							block? pc/1/expr
							paren? pc/1/expr
						]
						not empty? pc/1/expr
					][
						resolve-depth pc/1/expr depth
					]
				]
			]
		]

		max-depth: top/1/max-depth
		repeat depth max-depth [
			resolve-depth top/1/expr depth
		]
	]

	exp-all: function [top [block! paren!]][
		exp-type?: function [pc [block! paren!]][
			if tail? pc [
				return reduce [pc 0]
			]
			expr: pc/1/expr
			syntax: pc/1/syntax
			ret: none
			type: none

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
					ret/2: ret/2 + 1
					syntax/step: 1
					return ret
				]
			]

			include-type?: [
				if all [
					issue? expr
					"include" = to string! expr
				][
					syntax/name: "include"
					ret: exp-type? next pc
					either tail? ret/1 [
						syntax-error pc 'miss-expr
					][
						syntax/cast: ret/1
						unless file? ret/1/expr [
							syntax-error pc 'need-file
						]
					]
					ret/2: ret/2 + 1
					syntax/step: ret/2
					return reduce [pc ret/2]
				]
			]

			literal-type?: [
				if simple-literal? type? expr [
					syntax/name: "literal"
					syntax/step: 1
					return reduce [pc 1]
				]
			]

			set-type?: [
				if any [
					set-word? expr
					set-path? expr
				][
					either set-word? expr [
						syntax/name: "set-word"
					][
						syntax/name: "set-path"
					]
					ret: exp-type? next pc
					either tail? ret/1 [
						syntax-error pc 'miss-expr
					][
						syntax/cast: ret/1
					]
					ret/2: ret/2 + 1
					syntax/step: ret/2
					return ret
				]
			]

			block-type?: [
				if block? expr [
					syntax/name: "block"
					syntax/step: 1
					return reduce [pc 1]
				]
			]

			paren-type?: [
				if paren? expr [
					syntax/name: "paren"
					syntax/step: 1
					return reduce [pc 1]
				]
			]

			get-type?: [
				if any [
					get-word? expr
					get-path? expr
				][
					either get-word? expr [
						syntax/name: "get-word"
					][
						syntax/name: "get-path"
					]
					syntax/step: 1
					return reduce [pc 1]
				]
			]

			word-type?: [
				if any [
					word? expr
					path? expr
				][
					word: either word? expr [expr][expr/1]
					if system-words/system? word [
						type: type?/word get word
						syntax/keyword: word
						either find [native! action! function! routine! op! object!] type [
							syntax/name: "unknown-keyword"
							syntax/step: 1
							return reduce [pc 1]
						][
							syntax/name: "keyword-value"
							syntax/step: 1
							return reduce [pc 1]
						]
					]
					syntax/name: "unknown"
					syntax/step: 1
					return reduce [pc 1]
				]
			]

			do semicolon-type?
			do include-type?
			do literal-type?
			do set-type?
			do block-type?
			do paren-type?
			do get-type?
			do word-type?
			throw-error 'exp-type? "not support!" expr
		]

		exp-all*: function [pc [block! paren!]][
			npc: pc
			while [not tail? npc][
				type: exp-type? npc
				npc: skip npc type/2
			]
			resolve-refer top pc
		]

		exp-depth: function [pc [block! paren!] depth [integer!]][
			if pc/1/depth > depth [exit]
			forall pc [
				either pc/1/depth = depth [
					exp-all* pc
				][
					if all [
						any [
							block? pc/1/expr
							paren? pc/1/expr
						]
						not empty? pc/1/expr
					][
						exp-depth pc/1/expr depth
					]
				]
			]
		]

		max-depth: top/1/max-depth
		repeat depth max-depth [
			exp-depth top/1/expr depth
		]
	]

	analysis: function [top [block!]][
		if empty? top [exit]
		unless all [
			top/1/expr
			block? top/1/expr
		][throw-error 'analysis "expr isn't a block!" top/1]
		top/1/syntax/name: "top"
		top/1/syntax/step: 1
		pc: top/1/expr
		unless pc/1/expr = 'Red [
			syntax-error pc 'miss-head
		]
		unless block? pc/2/expr [
			syntax-error next pc 'miss-head-block
		]
		pc/1/syntax/meta: 1
		pc/2/syntax/meta: 2
		exp-all top
		resolve-keyword top
	]

	format: function [top [block!]][
		buffer: make string! 1000
		newline: function [cnt [integer!]] [
			append buffer lf
			append/dup buffer " " cnt
		]
		format*: function [pc [block! paren!]][
			pad: pc/1/depth * 4
			newline pad
			either block? pc [
				blk?: true
				append buffer "["
			][
				append buffer "("
			]
			forall pc [
				newline pad + 2
				append buffer "#("
				newline pad + 4
				append buffer "expr: "
				either any [
					block? pc/1/expr
					paren? pc/1/expr
				][
					either empty? pc/1/expr [
						either block? pc/1/expr [
							append buffer "[]"
						][
							append buffer "()"
						]
					][
						format* pc/1/expr
					]
				][
					append buffer mold/flat pc/1/expr
				]
				newline pad + 4
				append buffer "range: "
				append buffer mold pc/1/range
				newline pad + 4
				append buffer "depth: "
				append buffer mold pc/1/depth
				if pc/1/max-depth [
					newline pad + 4
					append buffer "max-depth: "
					append buffer mold pc/1/max-depth
				]
				newline pad + 4
				append buffer "syntax: #("
				newline pad + 6
				append buffer "name: "
				append buffer pc/1/syntax/name
				newline pad + 6
				append buffer "step: "
				append buffer pc/1/syntax/step
				if pc/1/syntax/error [
					newline pad + 6
					append buffer "error: "
					append buffer mold/flat pc/1/syntax/error
				]
				if pc/1/syntax/cast [
					newline pad + 6
					append buffer "cast: "
					append buffer mold/flat pc/1/syntax/cast/1/range
				]
				if pc/1/syntax/parent [
					newline pad + 6
					append buffer "parent: "
					append buffer mold/flat pc/1/syntax/parent/1/range
				]

				if pc/1/syntax/keyword [
					newline pad + 6
					append buffer "keyword: "
					append buffer pc/1/syntax/keyword
				]


				if pc/1/syntax/args [
					newline pad + 6
					append buffer "args: #("
					args: words-of pc/1/syntax/args
					forall args [
						newline pad + 8
						append buffer mold args/1
						append buffer ": "
						pos: pc/1/syntax/args/(args/1)
						append buffer mold/flat pos/1/range
					]
					newline pad + 6
					append buffer ")"
				]

				if pc/1/syntax/resolved [
					newline pad + 6
					append buffer "resolved: #("
					resolved: words-of pc/1/syntax/resolved
					forall resolved [
						newline pad + 8
						append buffer mold resolved/1
						append buffer ": "
						pos: pc/1/syntax/resolved/(resolved/1)
						append buffer mold/flat pos/1/range
					]
					newline pad + 6
					append buffer ")"
				]

				newline pad + 4
				append buffer ")"
				newline pad + 2
				append buffer ")"
			]
			newline pad
			either blk? [
				append buffer "]"
			][
				append buffer ")"
			]
		]
		format* top
		buffer
	]

	collect-errors: function [top [block! paren!]][
		ret: make block! 4
		collect-errors*: function [pc [block! paren!]][
			blk: [
				if pc/1/syntax/error [
					error: copy pc/1/syntax/error
					either block? error [
						forall error [
							error/1/range: red-lexer/form-range pc/1/range
							append ret error/1
						]
					][
						error/range: red-lexer/form-range pc/1/range
						append ret error
					]
				]
			]
			forall pc [
				either all [
					any [
						block? pc/1/expr
						paren? pc/1/expr
					]
					not empty? pc/1/expr
				][
					do blk
					collect-errors* pc/1/expr
				][
					do blk
				]
			]
		]
		collect-errors* top
		ret
	]

	clear-syntax: function [pc [block! paren!]][
		forall pc [
			either all [
				any [
					block? pc/1/expr
					paren? pc/1/expr
				]
				not empty? pc/1/expr
			][
				clear-syntax pc/1/expr
			][
				clear pc/1/syntax
				pc/1/syntax/step: 1
				if all [
					string? pc/1/expr
					#";" = pc/1/expr/1
				][
					pc/1/syntax/step: 2
				]
			]
		]
	]

	check-func-spec: function [pc [block!] keyword [word!]][
		words: make block! 4
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
					npc2/1/syntax/args/type: make block! 4
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
						expr2/1/name: "func-type-item"
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
			syntax/args/type: npc2/1/range
			npc2/1/name: "func-type"
			npc2/1/syntax/parent: npc/1/range
			npc2/1/syntax/args: make map! 1
			npc2/1/syntax/args/type: make block! 4
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
				expr2/1/name: "func-type-item"
				append/only npc2/1/syntax/args/type expr3
			]
			skip-semicolon-next npc2
		]
		check-refines: function [npc [block!]][
			collect-args: function [npc [block!] par [block!]][
				while [not tail? npc] [
					either word? npc/1/expr [
						append par/1/syntax/args/params npc/1/range
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
			syntax/args/params: make block! 4
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
		desc: none
		npc: skip-semicolon-next pc
		if tail? npc [return desc]
		if string? npc/1/expr [
			desc: npc/1/range
			pc: npc
		]
		return-pc: none
		local-pc: none
		until [
			expr: pc/1/expr
			case [
				expr = to set-word! 'return [
					return-pc: pc
					pc: check-return pc
				]
				refinement? expr [
					if local-pc [
						create-error-at pc/1/syntax 'Error 'forbidden-refine mold pc/1/expr
					]
					if expr = /local [local-pc: pc]
					either keyword = 'has [
						create-error-at pc/1/syntax 'Error 'forbidden-refine mold pc/1/expr
					][
						pc: check-refines pc
					]
				]
				find [word! lit-word! get-word!] type?/word expr [
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
		desc
	]

	resolve-spec: function [top [block!]][
		function-collect: function [pc [block! paren!]][
			unless par: pc/1/syntax/parent [exit]
			unless ret: find-expr top par [
				throw-error 'function-collect "can't find expr at" par
			]
			spec: ret/1/syntax/args/spec
			unless ret: find-expr top spec [
				throw-error 'function-collect "can't find expr at" spec
			]
			spec: ret/1/expr
			extra: make block! 4
			collect?: false
			collect-set-word*: function [npc [block! paren!]][
				forall npc [
					either all [
						any [
							block? npc/1/expr
							paren? npc/1/expr
						]
						not empty? npc/1/expr
					][
						collect-set-word* npc
					][
						if npc/1/syntax/name = "set-word" [
							collect?: true
							forall spec [
								if find [word! lit-word! refinement!] type?/word spec/1/expr [
									if (to word! spec/1/expr) = (to word! npc/1/expr) [
										collect?: false
									]
								]
							]
							if collect? [append/only extra npc/1/range]
						]
					]
				]
			]
			collect-set-word* pc/1/expr
			pc/1/syntax/extra: extra
		]

		resolve-func: function [pc [block! paren!] par [block! paren!]][
			keyword: pc/1/syntax/keyword
			if all [
				pc/1/syntax/args
				pc/1/syntax/args/name = 'spec
				find [func function has] keyword
			][
				if all [
					par/1/syntax/resolved
					ret: par/1/syntax/resolved/spec
				][
					unless spec: find-expr top ret [
						throw-error 'resolve-spec* "can't find expr at" ret
					]
					clear-syntax spec/1/expr
					desc: check-func-spec spec/1/expr keyword
					pc/1/syntax/desc: desc
				]
			]
		]

		resolve-bind: function [pc [block! paren!] par [block! paren!]][
			;-- TBD: bind block/word to context
		]

		resolve: function [pc [block! paren!] par [block! paren!]][
			args: pc/1/syntax/args
			refs: pc/1/syntax/refs
			if all [
				args
				args/name
			][
				if ret: fetch-type pc args/type args/name [
					put par/1/syntax/resolved args/name ret/1/range
				]
			]
			if all [
				refs
				refs/name
			][
				if ret: fetch-type pc refs/type refs/name [
					put par/1/syntax/resolved refs/name ret/1/range
				]
			]
		]

		resolve-spec*: function [pc [block! paren!]][
			forall pc [
				if keyword: pc/1/syntax/keyword [
					unless par: find-expr top pc/1/syntax/parent [
						throw-error 'resolve-spec* "can't find expr at" pc/1/syntax/parent
					]
					resolve pc par
					case [
						find [func function has does context] keyword [
							resolve-func pc par
						]
						keyword = 'bind [
							resolve-bind pc par
						]
					]
				]
				if all [
					any [
						block? pc/1/expr
						paren? pc/1/expr
					]
					not empty? pc/1/expr
				][
					resolve-spec* pc/1/expr
				]
			]
		]
		resolve-spec* top/1/expr
	]

	collect-completions: function [top [block!] str [string! none!] line [integer!] column [integer!]][
		words: make block! 4
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
