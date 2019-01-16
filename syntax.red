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
		'unresolve 				"need resolve unknown type"
		'invalid-refine			"invalid refinement"
		'invalid-datatype		"invalid datatype! in block!"
		'invalid-arg			"invalid argument"
	]

	warning-code: [
		'unknown-word			"unknown word"
	]

	create-error-at: function [syntax [map!] type [word!] word [word!]][
		message: case [
			type = 'Error [error-code/(word)]
			type = 'Warning [warning-code/(word)]
		]
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

	check-func-args: function [blk [block!]][
		forall blk [
			expr: blk/1/expr
			either any [
				word? expr
				lit-word? expr
				get-word? expr
				refinement? expr
			][
				if all [
					not tail? next blk
					block? expr2: blk/2/expr
				][
					if refinement? expr [
						create-error-at blk/2/syntax 'Error 'invalid-refine
					]
					forall expr2 [
						expr3: expr2/1/expr
						unless any [
							datatype? get expr3
							typeset? get expr3
						][
							create-error-at blk/2/syntax 'Error 'invalid-datatype
						]
					]
					blk: next blk
				]
			][
				create-error-at blk/1/syntax 'Error 'invalid-arg
			]
		]
	]

	exp-type?: function [pc [block! paren!]][
		if tail? pc [
			syntax: make map! 1
			create-error-at syntax 'Error 'miss-expr
			return reduce [syntax 0]
		]
		expr: pc/1/expr
		expr-type: type? expr
		syntax: pc/1/syntax
		ret: none
		type: none
		blk: none
		step: none

		semicolon-type?: [
			if any [
				all [
					string? expr
					not empty? expr
					expr/1 = #";"
				]
				expr = none
			][
				put-syntax syntax reduce [
					'name "semicolon"
					'CompletionItemKind CompletionItemKind/Text
					'SymbolKind SymbolKind/Null
				]
				ret: exp-type? next pc
				ret/2: ret/2 + 1
				return ret
			]
		]

		include-type?: [
			if all [
				expr-type = issue! 
				"include" = to string! expr
			][
				ret: exp-type? next pc
				put-syntax syntax reduce [
					'name "include"
					'cast ret/1
					'follow ret/2
					'CompletionItemKind CompletionItemKind/Module
					'SymbolKind SymbolKind/Package
				]
				ret/2: ret/2 + 1
				return ret
			]
		]

		slit-type?: [
			if simple-literal? expr-type [
				put-syntax syntax reduce [
					'name "literal"
					'type expr-type
					'CompletionItemKind CompletionItemKind/Constant
					'SymbolKind symbol-type? expr-type
				]
				return reduce [syntax 1]
			]
		]

		set-word-type?: [
			if set-word? expr [
				ret: exp-type? next pc
				put-syntax syntax reduce [
					'name "set-word"
					'cast ret/1
					'follow ret/2
				]
				ret/2: ret/2 + 1
				return ret
			]
		]

		set-path-type?: [
			if set-path? expr [
				ret: exp-type? next pc
				put-syntax syntax reduce [
					'name "set-path"
					'cast ret/1
					'follow ret/2
				]
				ret/2: ret/2 + 1
				return ret
			]
		]

		block-type?: [
			if block? expr [
				unless empty? expr [
					exp-all expr
				]
				put-syntax syntax reduce [
					'name "block"
				]
				return reduce [syntax 1]
			]
		]

		paren-type?: [
			if paren? expr [
				unless empty? expr [
					exp-all expr
				]
				put-syntax syntax reduce [
					'name "paren"
				]
				return reduce [syntax 1]
			]
		]

		keyword-type?: [
			if all [
				expr-type = word!
				find system-words/system-words expr
			][
				type: type? get expr
				put-syntax syntax reduce [
					'name "keyword"
					'expr expr
					'type type
					'CompletionItemKind CompletionItemKind/Keyword
					'SymbolKind SymbolKind/Method
				]

				step: 1
				if all [
					not tail? next pc
					block? pc/2/expr
				][
					case [
						find [has func function] expr [
							step: step + 1
							put-syntax pc/2/syntax reduce [
								'ctx expr
								'ctx-index 1
							]
							check-func-args pc/2/expr
							if all [
								not tail? next next pc
								block? pc/3/expr
							][
								put-syntax pc/3/syntax reduce [
									'ctx expr
									'ctx-index 2
									'spec pc/2/expr
								]
								exp-type? next next pc
								step: step + 1
							]
						]
						find [does context] expr [
							put-syntax pc/2/syntax reduce [
								'ctx expr
								'ctx-index 1
							]
							exp-type? next pc
							step: step + 1
						]
						;find [action! native! function! routine!] type [
						;	step: step
						;]
					]
				]
				if step > 1 [
					put-syntax syntax reduce [
						'follow step - 1
					]
				]
				return reduce [syntax step]
			]
		]

		unknown-type?: [
			if expr-type = word! [
				put-syntax syntax reduce [
					'name "unknown"
					'expr expr
				]
				return reduce [syntax 1]
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
			either map? pc/1 [
				type: exp-type? pc
				pc: skip pc type/2
			][
				pc: next pc
			]
		]
	]

	analysis: function [pc [block!]][
		unless pc/1/expr = 'Red [
			create-error-at pc/1/syntax 'Error 'miss-head-red
		]
		unless block? pc/2/expr [
			create-error-at pc/2/syntax 'Error 'miss-head-block
		]
		exp-all pc
		raise-global pc
		resolve-unknown pc
		put-syntax pc/1/syntax ['meta 1]
		put-syntax pc/2/syntax ['meta 2]
	]

	raise-global: function [top [block!]][
		globals: clear []
		append/only top globals

		raise-set-word: function [pc [block! paren!]][
			raise-set-word*: function [npc [block! paren!]][
				while [not tail? npc][
					if all [
						npc/1/syntax
						npc/1/syntax/name = "set-word"
						pc/1/expr = npc/1/expr
					][
						return false
					]
					npc: next npc
				]
				return true
			]
			if top = head pc [return false]
			par: get-parent top pc/1

			unless any [
				all [
					par/1/syntax/ctx = 'does
					par/1/syntax/ctx-index = 1
				]
				all [
					par/1/syntax/ctx = 'has
					par/1/syntax/ctx-index = 2
				]
				all [
					par/1/syntax/ctx = 'func
					par/1/syntax/ctx-index = 2
				]
			][
				return false
			]
			until [
				unless raise-set-word* head par [return false]
				par: get-parent top par/1
				if empty? par [
					return raise-set-word* top
				]
				par = false
			]
			return true
		]
		raise-global*: function [pc [block! paren!]][
			while [not tail? pc][
				either all [
					map? pc/1
					any [
						block? pc/1/expr
						paren? pc/1/expr
					]
					not empty? pc/1/expr
				][
					raise-global* pc/1/expr
				][
					if all [
						map? pc/1
						pc/1/syntax
						pc/1/syntax/name = "set-word"
					][
						if raise-set-word pc [
							append/only globals pc/1
						]
					]
				]
				pc: next pc
			]
		]

		raise-global* top
	]

	resolve-unknown: function [top [block!]][
		resolve-set-word: function [pc [block! paren!]][
			resolve-set-word*: function [npc [block! paren!]][
				while [not tail? npc][
					if all [
						npc/1/syntax
						npc/1/syntax/name = "set-word"
						pc/1/expr = to word! npc/1/expr
					][
						pc/1/syntax/cast: npc/1/syntax/cast
						pc/1/syntax/start: npc/1/start
						pc/1/syntax/end: npc/1/end
						pc/1/syntax/name: "resolved"
						return true
					]
					npc: next npc
				]
				return false
			]
			if resolve-set-word* head pc [return true]
			if top = head pc [return false]
			par: pc
			while [par: get-parent top par/1][
				if empty? par [
					return resolve-set-word* top
				]
				if resolve-set-word* par/1/expr [return true]
			]
			return false
		]
		resolve-unknown*: func [pc [block! paren!]][
			while [not tail? pc][
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
						unless resolve-set-word pc [
							create-error-at pc/1/syntax 'Warning 'unknown-word
						]
					]
				]
				pc: next pc
			]
		]
		resolve-unknown* top
	]

	get-parent: function [top [block!] item [map!]][
		get-parent*: function [pc [block! paren!] par [block!]][
			;probe length? ret
			while [not tail? pc][
				if all [
					map? pc/1
					item/start = pc/1/start
					item/end = pc/1/end
				][return par]
				if all [
					map? pc/1
					any [
						block? pc/1/expr
						paren? pc/1/expr
					]
					not empty? pc/1/expr
				][
					if temp: get-parent* pc/1/expr pc [return temp]
				]
				pc: next pc
			]
			false
		]
		get-parent* top clear []
	]

	position?: function [pc [block! paren!] line [integer!] column [integer!]][
		cascade: [
			append stack index? pc
			either all [
				map? pc/1
				any [
					block? pc/1/expr
					paren? pc/1/expr
				]
				not empty? pc/1/expr
			][
				append stack position? pc/1/expr line column
				return stack
			][
				return stack
			]
		]
		stack: clear []
		blk: none
		forall pc [
			if all [
				map? pc/1
				pc/1/start/1 <= line
				pc/1/start/2 <= column
			][
				either all [
					pc/1/end/1 >= line
					pc/1/end/2 > column
				][
					do cascade
				][
					if all [
						pc/1/end/1 = line
						pc/1/end/2 = column
						any [
							tail? next pc
							all [
								map? pc/2
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
		return stack
	]

]
