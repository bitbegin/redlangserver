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

	create-error-at: function [syntax [map!] word [word!]][
		error: make map! reduce [
			'severity DiagnosticSeverity/Error
			'code to string! word
			'source "Syntax"
			'message error-code/(word)
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
						create-error-at blk/2/syntax 'invalid-refine
					]
					forall expr2 [
						expr3: expr2/1/expr
						unless any [
							datatype? expr3
							typeset? expr3
						][
							create-error-at blk/2/syntax 'invalid-datatype
						]
					]
					blk: next blk
				]
			][
				create-error-at blk/1/syntax 'invalid-arg
			]
		]
	]

	exp-type?: function [pc [block! paren!]][
		if tail? pc [
			syntax: make map! 1
			create-error-at syntax 'miss-expr
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
					exp-all? expr
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
					exp-all? expr
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
							check-func-args pc/2/expr
							if all [
								not tail? next next pc
								block? pc/3/expr
							][
								exp-type? next next pc
								step: step + 1
							]
						]
						find [does context] expr [
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

	exp-all?: function [pc [block! paren!]][
		while [not tail? pc][
			type: exp-type? pc
			pc: skip pc type/2
		]
	]

	analysis: function [npc [block!]][
		unless npc/1/expr = 'Red [
			create-error-at npc/1/syntax 'miss-head-red
		]
		unless block? npc/2/expr [
			create-error-at npc/2/syntax 'miss-head-block
		]
		exp-all? npc
	]

	position?: function [npc [block! paren!] line [integer!] column [integer!]][
		cascade: [
			append ctx index? npc
			either all [
				any [
					block? npc/1/expr
					paren? npc/1/expr
				]
				not empty? npc/1/expr
			][
				append ctx position? npc/1/expr line column
				return ctx
			][
				return ctx
			]
		]
		ctx: clear []
		blk: none
		forall npc [
			if all [
				npc/1/start/1 <= line
				npc/1/start/2 <= column
			][
				either all [
					npc/1/end/1 >= line
					npc/1/end/2 > column
				][
					do cascade
				][
					if all [
						npc/1/end/1 = line
						npc/1/end/2 = column
						any [
							tail? next npc
							all [
								npc/2/start/1 >= line
								npc/2/start/2 <> column
							]
						]
					][
						do cascade
					]
				]
			]
		]
		return ctx
	]

]
