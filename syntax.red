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
		'unresolve 				"need resolve unknown type"
		'invalid-refine			"invalid refinement"
		'invalid-datatype		"invalid datatype! in block!"
		'invalid-arg			"invalid argument"
		'double-define			"double define"
		'return-place			"invalid place for 'return:'"
		'forbidden-refine		"forbidden refinement here"
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

	put-syntax: func [syn [map!] item [block!]][
		forall item [
			put syn item/1 item/2
			item: next item
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

	check-has-spec: function [pc [block!]][
		forall pc [
			if refinement? pc/1/expr [
				create-error-at pc/1/syntax 'Error 'forbidden-refine mold pc/1/expr
			]
		]
	]

	check-func-spec: function [pc [block!]][
		words: clear []
		word: none
		double-check: function [pc][
			either find words word: to word! pc/1/expr [
				create-error-at pc/1/syntax 'Error 'double-define to string! word
			][
				append words word
			]
		]
		check-args: function [npc [block!] par [refinement! none!]][
			double-check npc
			put-syntax npc/1/syntax reduce [
				'name "func-args"
				'paren	par
			]
			npc2: skip-semicolon-next npc
			if tail? npc2 [return npc2]
			type: type? npc2/1/expr
			case [
				type = string! [
					put-syntax npc/1/syntax reduce [
						'desc npc2/1/expr
					]
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
					put-syntax npc/1/syntax reduce [
						'spec expr2
					]
					npc3: skip-semicolon-next npc2
					if tail? npc3 [return npc3]
					if string? npc3/1/expr [return next npc3]
					return npc3
				]
			]
			npc2
		]
		check-refines: function [npc [block!]][
			double-check npc
			put-syntax npc/1/syntax reduce [
				'name "func-refines"
			]
			npc2: skip-semicolon-next npc
			if tail? npc2 [return npc2]
			type: type? npc2/1/expr
			case [
				type = string! [
					put-syntax npc/1/syntax reduce [
						'desc npc2/1/expr
					]
					npc3: skip-semicolon-next npc2
					while [not tail? npc3][
						either word? npc3/1/expr [
							append npc/1/syntax/spec npc3/1
							if tail? npc3: check-args npc3 npc/1/expr [return npc3]
						][
							either refinement? npc3/1/expr [
								return npc3
							][
								create-error-at npc3/1/syntax 'Error 'invalid-arg mold npc3/1/expr
								npc3: next npc3
							]
						]
					]
					return npc3
				]
				type = word! [
					put-syntax npc/1/syntax reduce [
						'spec clear []
					]
					while [not tail? npc2][
						either word? npc2/1/expr [
							append npc/1/syntax/spec npc2/1
							if tail? npc2: check-args npc2 npc/1/expr [return npc2]
						][
							either refinement? npc2/1/expr [
								return npc2
							][
								create-error-at npc2/1/syntax 'Error 'invalid-arg mold npc2/1/expr
								npc2: next npc2
							]
						]
					]
					return npc2
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
		if all [
			string? pc/1/expr
			pc/1/syntax/name = "literal"
		][
			pc: next pc
		]
		return-pc: none
		until [
			expr: pc/1/expr
			case [
				expr = to set-word! /return [
					return-pc: pc
					pc: check-args pc /return
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
					pc: next pc
				]
			]
			tail? pc
		]
	]

	create-pos: function [where [block! paren!]][
		make map! reduce [
			'start	where/1/start
			'end	where/1/end
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
		type: none
		spec: none
		body: none

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

		slit-type?: [
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

		keyword-type?: [
			if all [
				expr-type = word!
				find system-words/system-words expr
			][
				syntax/name: "keyword"
				type: type? get expr

				if find [has func function does context] expr [
					if find [has func function] expr [
						ret: exp-type? next pc
						if ret/2 = 0 [
							create-error-at syntax 'Error 'miss-spec to string! expr
							return reduce [create-pos pc 1]
						]
						unless spec: find-expr syntax-top ret/1 [
							throw-error 'keyword-type? "can't find expr at" ret/1
						]
						if spec/1/syntax/name <> "block" [
							syntax/need: "spec"
							return reduce [create-pos pc 1]
						]
						syntax/spec: spec/1
						if expr = 'has [
							check-has-spec spec/1/expr
						]
						check-func-spec spec/1/expr

						ret: exp-type? next next pc
						if ret/2 = 0 [
							create-error-at syntax 'Error 'miss-body to string! expr
							return reduce [create-pos pc 2]
						]
						unless body: find-expr syntax-top ret/1 [
							throw-error 'keyword-type? "can't find expr at" ret/1
						]
						if body/1/syntax/name <> "block" [
							syntax/need: "body"
							return reduce [create-pos pc 2]
						]
						syntax/body: body/1
						return reduce [create-pos pc 3]
					]

					ret: exp-type? next pc
					if ret/2 = 0 [
						create-error-at syntax 'Error 'miss-body to string! expr
						return reduce [create-pos pc 1]
					]
					unless body: find-expr syntax-top ret/1 [
						throw-error 'keyword-type? "can't find expr at" ret/1
					]
					if body/1/syntax/name <> "block" [
						syntax/need: "body"
						return reduce [create-pos pc 1]
					]
					syntax/body: body/1
					return reduce [create-pos pc 2]
				]
				;if find [action! native! function! routine!] type [
				;]

				return reduce [create-pos pc 1]
			]
		]

		unknown-type?: [
			if expr-type = word! [
				syntax/name: "unknown"
				return reduce [pc/1 1]
			]
		]

		do semicolon-type?
		do include-type?
		do slit-type?
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
		put-syntax top/1/syntax reduce [
			'ctx 'context
		]
		unless pc/1/expr = 'Red [
			create-error-at pc/1/syntax 'Error 'miss-head-red none
		]
		unless block? pc/2/expr [
			create-error-at pc/2/syntax 'Error 'miss-head-block none
		]
		put-syntax pc/1/syntax ['meta 1]
		put-syntax pc/2/syntax ['meta 2]
		exp-all pc
		;raise-variables top
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

	func-arg?: function [pc [block! paren!] par [block! paren!]][
		if block? spec: par/1/syntax/spec [
			forall spec [
				if find [word! lit-word! get-word! refinement!] type? spec/1/expr [
					if (to word! spec/1/expr) = to word! pc/1/expr [
						return spec/1
					]
				]
			]
		]
		false
	]

	raise-variables: function [top [block!]][
		raise?: function [pc [block! paren!]][
			dpar: get-parent top pc/1
			raise*?: function [par [block! paren!]][
				if all [
					par = dpar
					par/1/syntax/ctx = 'context
				][
					either par/1/syntax/vars [
						append par/1/syntax/vars pc/1
					][
						par/1/syntax/vars: reduce [pc/1]
					]
					return false
				]
				if all [
					par/1/syntax/ctx = 'function
					par/1/syntax/ctx-index = 2
				][
					unless func-arg? pc par [
						either par/1/syntax/vars [
							append par/1/syntax/vars pc/1
						][
							par/1/syntax/vars: reduce [pc/1]
						]
					]
					return false
				]
				if all [
					any [
						par/1/syntax/ctx = 'func
						par/1/syntax/ctx = 'has
					]
					par/1/syntax/ctx-index = 2
				][
					return not func-arg? pc par
				]
				if all [
					par/1/syntax/ctx = 'does
				][
					return true
				]

				npc: head par
				forall npc [
					if all [
						npc/1/syntax
						npc/1/syntax/name = "set-word"
						pc/1/expr = npc/1/expr
					][
						return false
					]
				]
				return true
			]
			par: pc
			while [par: get-parent top par/1][
				unless raise*? par [return false]
			]
			true
		]
		raise-vars*: function [pc [block! paren!]][
			forall pc [
				either all [
					any [
						block? pc/1/expr
						paren? pc/1/expr
					]
					not empty? pc/1/expr
				][
					raise-vars* pc/1/expr
				][
					if all [
						pc/1/syntax
						pc/1/syntax/name = "set-word"
					][
						if raise? pc [
							either top/1/syntax/vars [
								append top/1/syntax/vars pc/1
							][
								top/1/syntax/vars: reduce [pc/1]
							]
						]
					]
				]
			]
		]

		raise-vars* top/1/expr
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
