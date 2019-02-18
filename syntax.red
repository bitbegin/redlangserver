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
			either block? errors: syntax/error [
				forall errors [
					if errors/1/code = error/code [exit]
				]
				append syntax/error error
			][
				if errors/code = error/code [exit]
				syntax/error: reduce [errors error]
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
			either all [
				string? pc/1/expr
				find/match pc/1/expr ";"
			][
				pc: skip pc 1
				step: step + 1
			][
				break
			]
		]
		reduce [pc step]
	]

	back-type: function [pc [block! paren!]][
		bpc: back pc
		while [pc <> bpc: back pc][
			either bpc/1/syntax/name = "semicolon" [
				pc: bpc
			][
				return bpc
			]
		]
		bpc
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

	syntax-error: function [pc [block! paren!] word [word!] args][
		switch word [
			miss-expr [
				create-error pc/1/syntax 'Error 'miss-expr
					rejoin [mold pc/1/expr " -- need a type: " args]
			]
			recursive-define [
				create-error pc/1/syntax 'Error 'recursive-define
					rejoin [mold pc/1/expr " -- recursive define"]
			]
			double-define [
				create-error pc/1/syntax 'Error 'double-define
					rejoin [mold pc/1/expr " -- double define: " args]
			]
			invalid-arg [
				create-error pc/1/syntax 'Error 'invalid-arg
					rejoin [mold pc/1/expr " -- invalid argument for: " args]
			]
			invalid-datatype [
				create-error pc/1/syntax 'Error 'invalid-datatype
					rejoin [mold pc/1/expr " -- invalid datatype: " args]
			]
			forbidden-refine [
				create-error pc/1/syntax 'Error 'forbidden-refine
					rejoin [mold pc/1/expr " -- forbidden refinement: " args]
			]
		]
	]

	check-func-spec: function [pc [block!] keyword [word!]][
		words: make block! 4
		word: none
		double-check: function [pc [block!]][
			either find words word: to word! pc/1/expr [
				syntax-error pc 'double-define to string! word
			][
				append words word
			]
		]
		check-args: function [npc [block!] par [block! paren! none!]][
			syntax: npc/1/syntax
			syntax/name: "func-param"
			syntax/args: make map! 3
			syntax/args/refs: par
			double-check npc
			ret: next-type npc
			npc2: ret/1
			if tail? npc2 [return npc2]
			type: type? npc2/1/expr
			case [
				type = string! [
					syntax/args/desc: npc2
					npc2/1/syntax/name: "func-desc"
					npc2/1/syntax/parent: npc
					ret: next-type npc2
					npc3: ret/1
					if tail? npc3 [return npc3]
					if block? npc3/1/expr [
						syntax-error npc3 'invalid-arg mold npc/1/expr
						return next npc3
					]
					return npc3
				]
				type = block! [
					syntax/args/type: npc2
					npc2/1/syntax/name: "func-type"
					npc2/1/syntax/parent: npc
					npc2/1/syntax/args: make map! 1
					npc2/1/syntax/args/types: make block! 4
					expr2: npc2/1/expr
					forall expr2 [
						expr3: expr2/1/expr
						either any [
							all [
								value? expr3
								datatype? get expr3
							]
							all [
								value? expr3
								typeset? get expr3
							]
						][
							append/only npc2/1/syntax/args/types expr3
						][
							syntax-error expr2 'invalid-datatype mold expr3
						]
						expr2/1/syntax/name: "func-type-item"
					]
					ret: next-type npc2
					npc3: ret/1
					if tail? npc3 [return npc3]
					if string? npc3/1/expr [
						syntax/args/desc: npc3
						npc3/1/syntax/name: "func-desc"
						npc3/1/syntax/parent: npc
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
			ret: next-type npc
			npc2: ret/1
			if tail? npc2 [
				syntax-error npc 'miss-expr "block!"
				return npc2
			]
			unless block? npc2/1/expr [
				syntax-error npc 'miss-expr "block!"
				return npc2
			]
			syntax/args: make map! 1
			syntax/args/type: npc2
			npc2/1/syntax/name: "func-type"
			npc2/1/syntax/parent: npc
			npc2/1/syntax/args: make map! 1
			npc2/1/syntax/args/types: make block! 4
			expr2: npc2/1/expr
			forall expr2 [
				expr3: expr2/1/expr
				either any [
					all [
						value? expr3
						datatype? get expr3
					]
					all [
						value? expr3
						typeset? get expr3
					]
				][
					append/only npc2/1/syntax/args/types expr3
				][
					syntax-error expr2 'invalid-datatype mold expr3
				]
				expr2/1/syntax/name: "func-type-item"
			]
			ret: next-type npc2
			ret/1
		]
		check-refines: function [npc [block!]][
			collect-args: function [npc [block!] par [block!]][
				while [not tail? npc][
					either word? npc/1/expr [
						append par/1/syntax/args/params npc
						if tail? npc: check-args npc par [return npc]
					][
						either refinement? npc/1/expr [
							return npc
						][
							syntax-error npc 'invalid-arg mold par/1/expr
							npc: next npc
						]
					]
				]
				return npc
			]
			syntax: npc/1/syntax
			syntax/name: "func-refinement"
			syntax/args: make map! 2
			syntax/args/params: make block! 4
			double-check npc
			ret: next-type npc
			npc2: ret/1
			if tail? npc2 [return npc2]
			type: type? npc2/1/expr
			case [
				type = string! [
					syntax/args/desc: npc2
					npc2/1/syntax/name: "func-desc"
					npc2/1/syntax/parent: npc
					ret: next-type npc2
					npc3: ret/1
					return collect-args npc3 npc
				]
				type = word! [
					return collect-args npc2 npc
				]
				type = refinement! [
					return npc2
				]
				true [
					syntax-error npc2 'invalid-arg mold npc/1/expr
					return next npc2
				]
			]
		]
		par: pc
		pc: par/1/expr
		if string? pc/1/expr [
			par/1/syntax/desc: pc
			pc/1/syntax/name: "func-desc"
			ret: next-type pc
			if tail? pc: ret/1 [exit]
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
					if any [
						local-pc
						keyword = 'has
					][
						syntax-error pc 'forbidden-refine mold pc/1/expr
					]
					if expr = /local [local-pc: pc]
					pc: check-refines pc
				]
				find [word! lit-word! get-word!] type?/word expr [
					if return-pc [
						syntax-error return-pc 'invalid-arg mold expr
					]
					pc: check-args pc none
				]
				true [
					syntax-error pc 'invalid-arg mold expr
					ret: next-type pc
					pc: ret/1
				]
			]
			tail? pc
		]
	]

	func-arg?: function [spec [block! paren!] word [word!]][
		if block? expr: spec/1/expr [
			forall expr [
				if find [word! lit-word! get-word! refinement!] type?/word expr/1/expr [
					if word = to word! expr/1/expr [
						return expr
					]
				]
			]
		]
		none
	]

	spec-of-func-body: function [top [block!] pc [block! paren!]][
		npc: head pc
		forall npc [
			if all [
				find [func function has] npc/1/syntax/word
				npc/1/syntax/resolved
				npc/1/syntax/resolved/body = pc
			][
				return npc/1/syntax/resolved/spec
			]
		]
		none
	]

	context-spec?: function [top [block!] pc [block! paren!]][
		if top = pc [return true]
		npc: head pc
		forall npc [
			if all [
				npc/1/syntax/word = 'context
				npc/1/syntax/resolved
				npc/1/syntax/resolved/spec = pc
			][
				return true
			]
		]
		false
	]

	function-body?: function [top [block!] pc [block! paren!]][
		npc: head pc
		forall npc [
			if all [
				npc/1/syntax/word = 'function
				npc/1/syntax/resolved
				npc/1/syntax/resolved/body = pc
			][
				return true
			]
		]
		false
	]

	belong-to-function?: function [top [block!] pc [block! paren!]][
		until [
			if all [
				pc/1/syntax/name = "block"
				function-body? top pc
			][
				return true
			]
			pc: get-parent top pc/1
		]
		false
	]

	word-value?: function [top [block!] pc [block! paren!]][
		unless any-word? pc/1/expr [return none]
		word: to word! pc/1/expr
		find-set-word: function [npc [block! paren!]][
			forall npc [
				if all [
					pc <> npc
					npc/1/syntax/name = "set"
					set-word? npc/1/expr
					word = to word! npc/1/expr
				][
					;-- tail
					unless cast: npc/1/syntax/cast [
						return reduce [npc cast]
					]
					;-- recursive define
					if cast = pc [
						syntax-error npc 'recursive-define none
						return none
					]
					;-- nested define
					if all [
						any [
							word? cast/1/expr
							get-word? cast/1/expr
						]
						ret: word-value? top cast
					][
						return ret
					]
					return reduce [npc cast]
				]
			]
			none
		]
		find-func-spec: function [par [block! paren! none!]][
			unless par [return none]
			if all [
				par/1/syntax/name = "block"
				spec: spec-of-func-body top par
				ret: func-arg? spec word
			][
				return reduce [ret none]
			]
			none
		]
		npc: pc
		until [
			par: get-parent top npc/1
			if any [
				ret: find-func-spec par
				ret: find-set-word head npc
			][
				return ret
			]
			not npc: par
		]
		none
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

		resolve-keyword**: function [][]

		resolve-depth: function [pc [block! paren!] depth [integer!]][
			if pc/1/depth > depth [exit]
			if pc/1/depth = depth [
				resolve-keyword* pc
			]
			forall pc [
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
			step: none
			cast: none

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
						syntax-error pc 'miss-expr "file!"
					][
						syntax/cast: ret/1
						unless file? ret/1/1/expr [
							syntax-error pc 'miss-expr "file!"
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
					syntax/name: "set"
					ret: exp-type? next pc
					either tail? ret/1 [
						syntax-error pc 'miss-expr "any-type!"
					][
						syntax/cast: ret/1
					]
					ret/2: ret/2 + 1
					syntax/step: ret/2
					return ret
				]
			]

			keyword-set-type?: [
				if expr = 'set [
					ret: exp-type? next pc
					if any [
						tail? cast: ret/1
						all [
							not word? cast/1/expr
							not lit-word? cast/1/expr
							not path? cast/1/expr
							not lit-path? cast/1/expr
						]
					][
						syntax-error pc 'miss-expr "word! or lit-word! or path! or lit-path!"
						ret/2: ret/2 + 1
						syntax/step: ret/2
						return reduce [pc syntax/step]
					]
					syntax/name: "keyword-set"
					syntax/set-word: cast
					cast/1/syntax/name: "refer-set"
					cast/1/syntax/refer: pc
					step: ret/2 + 1
					ret: exp-type? skip pc step
					if tail? cast: ret/1 [
						syntax-error pc 'miss-expr "any-type!"
						syntax/step: step + ret/2
						return reduce [pc syntax/step]
					]
					syntax/cast: cast
					syntax/step: step + ret/2
					return reduce [pc syntax/step]
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
					syntax/name: "get"
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
					syntax/word: word
					if system-words/system? word [
						type: type?/word get word
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
			do keyword-set-type?
			do block-type?
			do paren-type?
			do get-type?
			do word-type?
			throw-error 'exp-type? "not support!" expr
		]

		resolve-type: function [pc [block! paren!]][
			while [not tail? pc][
				type: exp-type? pc
				pc: skip pc type/2
			]
		]

		resolve-refer: function [pc [block! paren!]][
			forall pc [
				if any [
					all [
						word? pc/1/expr
						find/match pc/1/syntax/name "unknown"
					]
					all [
						get-word? pc/1/expr
						pc/1/syntax/name = "get"
					]
					all [
						set-word? pc/1/expr
						pc/1/syntax/name = "set"
					]
				][
					either ret: word-value? top pc [
						if word? pc/1/expr [
							pc/1/syntax/name: "refer"
						]
						pc/1/syntax/refer: ret/1
						pc/1/syntax/value: ret/2
					][
						if all [
							set-word? pc/1/expr
							par: get-parent top pc/1
							not context-spec? top par
							not belong-to-function? top par
						][
							append top/1/syntax/extra pc/1
						]
					]
				]
			]
		]

		exp-func?: function [pc [block! paren!]][
			if all [
				pc/1/syntax/name = "unknown-keyword"
				find [func has does function context all any] pc/1/syntax/word
			][
				pc/1/syntax/name: append copy "keyword-" to string! pc/1/syntax/word
				npc: none
				step: none
				ret: next-type pc
				step: ret/2
				if tail? npc: ret/1 [
					syntax-error pc 'miss-expr "block!"
					return step
				]
				pc/1/syntax/casts: make map! 2
				either pc/1/syntax/word = 'does [
					pc/1/syntax/casts/body: npc
				][
					pc/1/syntax/casts/spec: npc
				]
				step: step + npc/1/syntax/step - 1
				either block? npc/1/expr [
					spec: npc
				][
					unless any [
						set-word? npc/1/expr
						word? npc/1/expr
					][
						syntax-error pc 'miss-expr "block!"
						return step + 1
					]
					either spec: npc/1/syntax/cast [
						unless block? spec/1/expr [
							spec: spec/1/syntax/value
						]
					][
						spec: npc/1/syntax/value
					]
					unless spec [
						syntax-error pc 'miss-expr "block!"
						return step + 1
					]
					unless block? spec/1/expr [
						syntax-error pc 'miss-expr "block!"
						return step + 1
					]
				]
				pc/1/syntax/resolved: make map! 2
				either pc/1/syntax/word = 'does [
					pc/1/syntax/resolved/body: spec
					spec/1/syntax/into: true
				][
					pc/1/syntax/resolved/spec: spec
					if find [context all any] pc/1/syntax/word [
						spec/1/syntax/into: true
					]
				]
				if find [does context all any] pc/1/syntax/word [return step + 1]
				check-func-spec spec pc/1/syntax/word
				ret: next-type skip pc step
				step: step + ret/2
				if tail? npc: ret/1 [
					syntax-error pc 'miss-expr "block!"
					return step + 1
				]
				pc/1/syntax/casts/body: npc
				step: step + npc/1/syntax/step - 1
				either block? npc/1/expr [
					body: npc
				][
					unless any [
						set-word? npc/1/expr
						word? npc/1/expr
					][
						syntax-error pc 'miss-expr "block!"
						return step + 1
					]
					either body: npc/1/syntax/cast [
						unless block? body/1/expr [
							body: body/1/syntax/value
						]
					][
						body: npc/1/syntax/value
					]
					unless body [
						syntax-error pc 'miss-expr "block!"
						return step + 1
					]
					unless block? body/1/expr [
						syntax-error pc 'miss-expr "block!"
						return step + 1
					]
				]
				pc/1/syntax/resolved/body: body
				body/1/syntax/into: true
				return 1 + step
			]
			none
		]

		resolve-func: function [pc [block! paren!]][
			while [not tail? pc][
				either step: exp-func? pc [
					pc/1/syntax/step: step
				][
					step: 1
				]
				pc: skip pc step
			]
		]

		exp-depth: function [pc [block! paren!] depth [integer!]][
			if pc/1/depth > depth [exit]
			if pc/1/depth = depth [
				resolve-type pc
				resolve-refer pc
				resolve-func pc
				exit
			]
			forall pc [
				if all [
					any [
						block? pc/1/expr
						paren? pc/1/expr
					]
					not empty? pc/1/expr
				][
					if any [
						paren? pc/1/expr
						pc/1/syntax/into
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
		top/1/syntax/extra: make block! 20
		pc: top/1/expr
		unless pc/1/expr = 'Red [
			syntax-error pc 'miss-expr "'Red' for Red File header"
		]
		unless block? pc/2/expr [
			syntax-error next pc 'miss-expr "block! for Red File header"
		]
		pc/1/syntax/meta: 1
		pc/2/syntax/meta: 2
		exp-all top
		;resolve-keyword top
	]

	format: function [top [block!]][
		buffer: make string! 1000
		newline: function [cnt [integer!]] [
			append buffer lf
			append/dup buffer " " cnt
		]
		format*: function [pc [block! paren!] depth [integer!]][
			pad: depth * 4
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
				append buffer "range: "
				append buffer mold pc/1/range
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
						format* pc/1/expr depth + 1
					]
				][
					append buffer mold/flat pc/1/expr
				]
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
				if pc/1/syntax/step [
					newline pad + 6
					append buffer "step: "
					append buffer pc/1/syntax/step
				]
				if pc/1/syntax/error [
					newline pad + 6
					append buffer "error: "
					append buffer mold/flat pc/1/syntax/error
				]
				if pc/1/syntax/meta [
					newline pad + 6
					append buffer "meta: "
					append buffer pc/1/syntax/meta
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
				if pc/1/syntax/refer [
					newline pad + 6
					append buffer "refer: "
					append buffer mold/flat pc/1/syntax/refer/1/range
				]
				if pc/1/syntax/value [
					newline pad + 6
					append buffer "value: "
					append buffer mold/flat pc/1/syntax/value/1/range
				]
				if pc/1/syntax/word [
					newline pad + 6
					append buffer "word: "
					append buffer pc/1/syntax/word
				]

				if pc/1/syntax/desc [
					newline pad + 6
					append buffer "desc: "
					append buffer mold/flat pc/1/syntax/desc/1/range
				]

				if pc/1/syntax/args [
					newline pad + 6
					append buffer "args: #("
					if pc/1/syntax/args/refs [
						newline pad + 8
						append buffer "refs: "
						append buffer mold/flat pc/1/syntax/args/refs/1/range
					]
					if pc/1/syntax/args/desc [
						newline pad + 8
						append buffer "desc: "
						append buffer mold/flat pc/1/syntax/args/desc/1/range
					]
					if pc/1/syntax/args/type [
						newline pad + 8
						append buffer "type: "
						append buffer mold/flat pc/1/syntax/args/type/1/range
					]
					if pc/1/syntax/args/types [
						newline pad + 8
						append buffer "types: "
						append buffer mold/flat pc/1/syntax/args/types
					]
					if params: pc/1/syntax/args/params [
						newline pad + 8
						append buffer "types: ["
						forall params [
							newline pad + 10
							append buffer mold/flat params/1/range
						]
						newline pad + 8
						append buffer "]"
					]
					newline pad + 6
					append buffer ")"
				]

				if pc/1/syntax/casts [
					newline pad + 6
					append buffer "casts: #("
					casts: words-of pc/1/syntax/casts
					forall casts [
						newline pad + 8
						append buffer mold casts/1
						append buffer ": "
						pos: pc/1/syntax/casts/(casts/1)
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

				if pc/1/syntax/into [
					newline pad + 6
					append buffer "into: "
					append buffer mold pc/1/syntax/into
				]

				if extra: pc/1/syntax/extra [
					newline pad + 6
					append buffer "extra: ["
					forall extra [
						newline pad + 8
						append buffer mold/flat extra/1/range
					]
					newline pad + 6
					append buffer "]"
				]

				if completions: pc/1/syntax/completions [
					newline pad + 6
					append buffer "completions: ["
					forall completions [
						newline pad + 8
						append buffer mold/flat completions/1/range
					]
					newline pad + 6
					append buffer "]"
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
		format* top 0
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

	collect-completions: function [top [block!] pc [block! paren!] /extra][
		ret: clear []
		str: clear ""
		unique?: function [word [string!]][
			npc: ret
			forall npc [
				if word = to string! npc/1/expr [return false]
			]
			true
		]
		collect*: function [npc [block! paren!]][
			word: to string! npc/1/expr
			if any [
				empty? str
				all [
					str <> word
					find/match word str
				]
			][
				if all [
					unique? word
					npc <> pc
				][
					append ret npc/1
				]
			]
		]
		collect-set-word: function [npc [block! paren!]][
			forall npc [
				if set-word? npc/1/expr [
					collect* npc
				]
			]
		]

		collect-arg: function [spec [block! paren!]][
			if block? npc: spec/1/expr [
				forall npc [
					if find [word! lit-word! get-word! refinement!] type?/word npc/1/expr [
						collect* npc
					]
				]
			]
		]

		collect-func-spec: function [par [block! paren! none!]][
			unless par [exit]
			if all [
				par/1/syntax/name = "block"
				spec: spec-of-func-body top par
			][
				collect-arg spec
			]
		]

		unless extra [
			either all [
				any [
					block? pc/1/expr
					paren? pc/1/expr
				]
				not empty? pc/1/expr
				any [
					pc/1/range/3 > line
					all [
						pc/1/range/3 = line
						pc/1/range/4 > column
					]
				]
			][
				collect-func-spec pc
				collect-set-word pc/1/expr
			][
				unless word? pc/1/expr [
					return ret
				]
				str: to string! pc/1/expr
			]

			npc: pc
			until [
				par: get-parent top npc/1
				collect-func-spec par
				collect-set-word head npc
				not npc: par
			]
		]
		if npc: top/1/syntax/extra [
			forall npc [
				if set-word? npc/1/expr [
					collect* npc
				]
			]
		]
		ret
	]
]

source-syntax: context [
	sources: make block! 4
	last-comps: []

	find-source: function [uri [string!]][
		forall sources [
			if sources/1/1 = uri [
				return sources
			]
		]
		false
	]

	add-source-to-table: function [uri [string!] blk [block!]][
		either item: find-source uri [
			item/1/2: blk
		][
			append/only sources reduce [uri blk]
		]
	]

	add-source: function [uri [string!] code [string!]][
		if map? res: red-lexer/analysis code [
			add-source-to-table uri res/stack
			range: red-lexer/to-range res/pos res/pos
			line-cs: charset [#"^M" #"^/"]
			info: res/error/arg2
			if part: find info line-cs [info: copy/part info part]
			message: rejoin [res/error/id " ^"" res/error/arg1 "^" at: ^"" info "^""]
			return reduce [
				make map! reduce [
					'range range
					'severity 1
					'code 1
					'source "lexer"
					'message message
				]
			]
		]
		add-source-to-table uri res
		if error? err: try [red-syntax/analysis res][
			pc: err/arg3
			range: red-lexer/to-range pc/2 pc/2
			return reduce [
				make map! reduce [
					'range range
					'severity 1
					'code 1
					'source "syntax"
					'message err/arg2
				]
			]
		]
		red-syntax/collect-errors res
	]

	get-completions: function [uri [string!] line [integer!] column [integer!]][
		unless item: find-source uri [
			return none
		]
		top: item/1/2
		unless pc: red-syntax/position? top line column [
			return none
		]
		unless any [
			file? pc/1/expr
			path? pc/1/expr
			word? pc/1/expr
		][
			return none
		]
		str: mold pc/1/expr
		comps: clear last-comps

		if word? pc/1/expr [
			forall sources [
				top2: sources/1/2
				collects: either sources/1/1 = uri [
					red-syntax/collect-completions top2 pc
				][
					red-syntax/collect-completions/extra top2 pc
				]
				forall collects [
					comp: make map! reduce [
						'label to string! collects/1/expr
						'kind CompletionItemKind/Variable
						'data make map! reduce [
							'uri uri
							'range mold collects/1/range
						]
					]
					if sources/1/1 = uri [
						put comp 'preselect true
					]
					append comps comp
				]
			]
			words: system-words/system-words
			forall words [
				sys-word: mold words/1
				if find/match sys-word str [
					append comps make map! reduce [
						'label sys-word
						'kind CompletionItemKind/Keyword
					]
				]
			]
			return comps
		]
		if path? pc/1/expr [
			completions: red-complete-ctx/red-complete-path str no
			forall completions [
				append comps make map! reduce [
					'label completions/1
					'kind CompletionItemKind/Property
				]
			]
			return comps
		]

		if file? pc/1/expr [
			completions: red-complete-ctx/red-complete-file str no
			forall completions [
				append comps make map! reduce [
					'label completions/1
					'kind CompletionItemKind/File
				]
			]
			return comps
		]
	]

	resolve-completion: function [params [map!]][
		if params/kind = CompletionItemKind/Keyword [
			word: to word! params/label
			if datatype? get word [
				return rejoin [params/label " is a base datatype!"]
			]
			return system-words/get-word-info word
		]
		if all [
			params/kind = CompletionItemKind/Variable
			params/data
		][
			uri: params/data/uri
			range: load params/data/range
			unless item: find-source uri [
				return none
			]
			top: item/1/2
			unless pc: red-syntax/find-expr top range [
				return none
			]
			unless cast: pc/1/syntax/cast [
				return none
			]
			either any [
				word? cast/1/expr
				path? cast/1/expr
			][
				if val: cast/1/syntax/value [
					return rejoin [params/label " is a " mold type? val/1/expr " datatype!"]
				]
				if refer: cast/1/syntax/refer [
					if refer/1/syntax/name = "func-param" [
						return rejoin [params/label " is function parameter!"]
					]
					if refer/1/syntax/name = "func-refinement" [
						return rejoin [params/label " is function refinement!"]
					]
				]
				if find [func function does has] cast/1/syntax/word [
					return rejoin [params/label " is a function!"]
				]
				if cast/1/syntax/word = 'context [
					return rejoin [params/label " is a context!"]
				]
			][
				return rejoin [params/label " is a " mold type? cast/1/expr " datatype!"]
			]
		]
		none
	]

	system-completion-kind: function [word [word!]][
		type: type? get word
		kind: case [
			datatype? get word [
				CompletionItemKind/Keyword
			]
			typeset? get word [
				CompletionItemKind/Keyword
			]
			op! = type [
				CompletionItemKind/Operator
			]
			find reduce [action! native! function! routine!] type [
				CompletionItemKind/Function
			]
			object! = type [
				CompletionItemKind/Class
			]
			true [
				CompletionItemKind/Variable
			]
		]
	]

	hover: function [uri [string!] line [integer!] column [integer!]][
		unless item: find-source uri [
			return none
		]
		top: item/1/2
		unless pc: red-syntax/position? top line column [
			return none
		]
		none
	]
]
