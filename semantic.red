Red [
	Title:   "Red syntax for Red language server"
	Author:  "bitbegin"
	File: 	 %syntax.red
	Tabs:	 4
	Rights:  "Copyright (C) 2011-2019 Red Foundation. All rights reserved."
	License: "BSD-3 - https://github.com/red/red/blob/origin/BSD-3-License.txt"
]

file-block: []

semantic: context [
	throw-error: register-error 'semantic

	create-error: function [pc [block!] type [word!] word [word!] message [string!]][
		error: reduce [
			'severity DiagnosticSeverity/(type)
			'code to string! word
			'source "Syntax"
			'message message
		]
		unless pc/error [
			repend pc ['error error]
			exit
		]
		errors: pc/error
		either block? errors/1 [
			forall errors [
				if errors/1/code = error/code [exit]
			]
			repend/only pc/error error
		][
			if errors/code = error/code [exit]
			pc/error: reduce [errors error]
		]
	]

	literal-type: [
		binary! char! date! email! file! float!
		lit-path! lit-word!
		integer! issue! logic! map! pair!
		percent! refinement! string! tag! time!
		tuple! url!
	]

	find-expr: function [top [block!] s [integer!] e [integer!]][
		find-expr*: function [pc [block!] s [integer!] e [integer!]][
			forall pc [
				if all [
					pc/1/s = s
					pc/1/e = e
				][
					return pc
				]
				if pc/1/nested [
					if ret: find-expr* pc/1/nested s e [return ret]
				]
			]
			none
		]
		find-expr* top s e
	]

	position?: function [top [block!] pos [integer!]][
		position?*: function [pc [block!]][
			forall pc [
				if all [
					pc/1/s <= pos
					pc/1/e >= pos
				][
					if any [
						all [
							pc/1/e <> pos
							none? pc/1/nested
						]
						all [
							pc/1/e = pos
							top <> pc
							any [
								tail? next pc
								pc/2/s <> pos
							]
						]
					][
						return pc
					]
					if pc/1/nested [
						if ret: position?* pc/1/nested [return ret]
					]
				]
			]
			none
		]
		position?* top
	]

	syntax-error: function [pc [block!] word [word!] args][
		switch/default word [
			unsupport [
				create-error pc/1 'Warning 'unsupport
					rejoin [mold pc/1/expr/1 " -- unsupport type: " args]
			]
			miss-expr [
				create-error pc/1 'Error 'miss-expr
					rejoin [mold pc/1/expr/1 " -- need a type: " args]
			]
			recursive-define [
				create-error pc/1 'Error 'recursive-define
					rejoin [mold pc/1/expr/1 " -- recursive define"]
			]
			double-define [
				create-error pc/1 'Error 'double-define
					rejoin [mold pc/1/expr/1 " -- double define: " args]
			]
			invalid-arg [
				create-error pc/1 'Error 'invalid-arg
					rejoin [mold pc/1/expr/1 " -- invalid argument for: " args]
			]
			invalid-datatype [
				create-error pc/1 'Error 'invalid-datatype
					rejoin [mold pc/1/expr/1 " -- invalid datatype: " args]
			]
			forbidden-refine [
				create-error pc/1 'Error 'forbidden-refine
					rejoin [mold pc/1/expr/1 " -- forbidden refinement: " args]
			]
			define-lag [
				create-error pc/1 'Warning 'define-lag
					rejoin [mold pc/1/expr/1 " -- definition is lagging"]
			]
			invalid-path [
				path: pc/1/expr/1
				remove back tail path
				create-error pc/1 'Warning 'invalid-path
					rejoin [mold path "/ -- invalid path"]
			]
		][
			create-error pc/1 'Error 'unknown
				rejoin [mold pc/1/expr/1 " -- unknown error: " mold word]
		]
	]

	check-func-spec: function [pc [block!] keyword [word!]][
		words: make block! 4
		word: none
		double-check: function [pc [block!]][
			either find words word: to word! pc/1/expr/1 [
				syntax-error pc 'double-define to string! word
			][
				append words word
			]
		]
		check-args: function [npc [block!] par [block! none!]][
			repend npc/1 ['syntax syntax: make block! 4]
			repend syntax ['type 'func-param 'args args: make block! 4]
			if par [repend syntax/args ['refs par]]
			double-check npc
			if tail? npc2: next npc [return npc2]
			type: type? npc2/1/expr/1
			case [
				type = string! [
					repend syntax/args ['desc npc2]
					repend npc2/1 ['syntax reduce ['type 'func-desc 'parent npc]]
					if tail? npc3: next npc2 [return npc3]
					if block? npc3/1/expr/1 [
						syntax-error npc3 'invalid-arg mold npc/1/expr/1
						return next npc3
					]
					return npc3
				]
				type = block! [
					repend syntax/args ['type npc2]
					repend npc2/1 ['syntax reduce ['type 'func-type 'parent npc]]
					if expr2: npc2/1/nested [
						forall expr2 [
							expr3: expr2/1/expr/1
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
								syntax-error expr2 'invalid-datatype mold expr3
							]
							repend expr2/1 ['syntax reduce ['type 'func-type-item]]
						]
					]
					if tail? npc3: next npc2 [return npc3]
					if string? npc3/1/expr/1 [
						repend syntax/args ['desc npc3]
						repend npc2/1 ['syntax reduce ['type 'func-desc 'parent npc]]
						return next npc3
					]
					return npc3
				]
			]
			npc2
		]
		check-return: function [npc [block!]][
			repend npc/1 ['syntax syntax: make block! 4]
			repend syntax ['type 'func-return]
			double-check npc
			if tail? npc2: next npc [
				syntax-error npc 'miss-expr "block!"
				return npc2
			]
			unless block? npc2/1/expr/1 [
				syntax-error npc 'miss-expr "block!"
				return npc2
			]
			repend syntax ['args args: make block! 4]
			repend syntax/args ['type npc2]
			repend npc2/1 ['syntax reduce ['type 'func-type 'parent npc]]
			if expr2: npc2/1/nested [
				forall expr2 [
					expr3: expr2/1/expr/1
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
						syntax-error expr2 'invalid-datatype mold expr3
					]
					repend expr2/1 ['syntax reduce ['type 'func-type-item]]
				]
			]
			next npc2
		]
		check-refines: function [npc [block!]][
			collect-args: function [npc [block!] par [block!]][
				while [not tail? npc][
					either word? npc/1/expr/1 [
						append/only par/1/syntax/args/params npc/1
						if tail? npc: check-args npc par [return npc]
					][
						either any [
							refinement? npc/1/expr/1
							npc/1/expr/1 = to set-word! 'return
						][
							return npc
						][
							syntax-error npc 'invalid-arg mold par/1/expr/1
							npc: next npc
						]
					]
				]
				return npc
			]
			repend npc/1 ['syntax syntax: make block! 4]
			repend syntax ['type 'func-refinement 'args make block! 4]
			repend syntax/args ['params make block! 4]
			double-check npc
			if tail? npc2: next npc [return npc2]
			type: type? npc2/1/expr/1
			case [
				type = string! [
					repend syntax/args ['desc npc2]
					repend npc2/1 ['syntax reduce ['type 'func-desc 'parent npc]]
					npc3: next npc2
					return collect-args npc3 npc
				]
				type = word! [
					return collect-args npc2 npc
				]
				type = refinement! [
					return npc2
				]
				true [
					syntax-error npc2 'invalid-arg mold npc/1/expr/1
					return next npc2
				]
			]
		]
		par: pc
		unless pc: par/1/nested [exit]
		if string? pc/1/expr/1 [
			repend par/1 ['syntax reduce ['desc pc]]
			repend pc/1 ['syntax reduce ['type 'func-desc]]
			if tail? pc: next pc [exit]
		]
		return-pc: none
		local-pc: none
		until [
			expr: pc/1/expr/1
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
						syntax-error pc 'forbidden-refine mold pc/1/expr/1
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
					pc: next pc
				]
			]
			tail? pc
		]
	]

	func-arg?: function [spec [block!] word [word!]][
		if block? expr: spec/1/expr/1 [
			if npc: spec/1/nested [
				forall npc [
					if all [
						find [word! lit-word! get-word! refinement!] type?/word npc/1/expr/1
						word = to word! npc/1/expr/1
					][
						return npc
					]
				]
			]
		]
		none
	]

	context-spec?: function [pc [block!]][
		par: pc/1/upper
		if all [
			block? par/1/expr/1
			par/1/syntax/type = 'spec
			parent: par/1/syntax/parent
			parent/1/syntax/word = 'context
			parent/1/syntax/resolved/spec
		][
			return true
		]
		false
	]

	func-spec-declare?: function [top [block!] pc [block!] /set?][
		word: to word! pc/1/expr/1
		func-spec-declare?*: function [par [block!]][
			if all [
				block? par/1/expr/1
				par/1/syntax
				par/1/syntax/type = 'body
				parent: par/1/syntax/parent
			][
				either set? [
					if all [
						parent/1/syntax/word = 'function
						spec: parent/1/syntax/resolved/spec
					] [return spec]
					if all [
						find [func has] parent/1/syntax/word
						spec: parent/1/syntax/resolved/spec
					][
						return func-arg? spec word
					]
				][
					if all [
						find [func has function] parent/1/syntax/word
						spec: parent/1/syntax/resolved/spec
					][
						return func-arg? spec word
					]
				]
			]
		]
		while [pc: pc/1/upper][
			if ret: func-spec-declare?* pc [
				return ret
			]
		]
		none
	]

	recent-set?: function [top [block!] pc [block!]][
		word: to word! pc/1/expr/1
		find-set-word: function [npc [block!]][
			forall npc [
				if all [
					any [
						set-word? npc/1/expr/1
						all [
							word? npc/1/expr/1
							npc/-1
							npc/-1/expr/1 = 'set
						]
					]
					word = to word! npc/1/expr/1
				][
					if all [
						(head npc) = (head pc)
						(index? pc) <= (index? npc)
					][
						if all [
							(index? pc) < (index? npc)
							none? pc/1/syntax/declare
						][
							syntax-error pc 'define-lag none
						]
						return none
					]
					return npc
				]
			]
			none
		]
		npc: pc
		until [
			if ret: find-set-word head npc [
				return ret
			]
			not npc: npc/1/upper
		]
		none
	]

	resolve: function [top [block!]][
		resolve-set: function [pc [block!]][
			resolve-set*: function [npc [block!]][
				if tail? cast: next npc [
					syntax-error pc 'miss-expr "any-type!"
					exit
				]
				unless find [word! path! get-word! get-path! set-word! set-path!] type?/word cast/1/expr/1 [
					repend pc/1/syntax ['value cast]
					repend pc/1/syntax ['step 1 + (index? cast) - (index? pc)]
					exit
				]
				if word? cast/1/expr/1 [
					repend pc/1/syntax ['cast cast]
					repend pc/1/syntax ['step 1 + (index? cast) - (index? pc)]
					exit
				]
				if set-word? cast/1/expr/1 [
					resolve-set* cast
				]
			]
			unless pc/1/syntax [
				repend pc/1 ['syntax make block! 4]
			]
			if all [
				none? pc/1/syntax/declare
				declare: func-spec-declare?/set? top pc
			][
				repend pc/1/syntax ['declare declare]
			]
			resolve-set* pc
			if all [
				none? pc/1/syntax/declare
				recent: recent-set? top pc
			][
				repend pc/1/syntax ['recent recent]
			]
			if all [
				none? pc/1/syntax/declare
				none? pc/1/syntax/recent
				top <> par: pc/1/upper
				not context-spec? pc
			][
				unless find top/1/syntax/extra pc/1 [
					append/only top/1/syntax/extra pc/1
				]
			]
		]

		resolve-word: function [pc [block!]][
			unless pc/1/syntax [
				repend pc/1 ['syntax make block! 4]
			]
			if all [
				none? pc/1/syntax/declare
				declare: func-spec-declare? top pc
			][
				repend pc/1/syntax ['declare declare]
			]
			if recent: recent-set? top pc [
				repend pc/1/syntax ['recent recent]
				;resolve-set recent
			]
		]

		word-value?: function [pc [block!]][
			if set-word? pc/1/expr/1 [
				unless pc/1/syntax [resolve-set pc]
				if value: pc/1/syntax/value [
					return reduce [pc/1/syntax/step value]
				]
				if cast: pc/1/syntax/cast [
					return reduce [pc/1/syntax/step cast]
				]
				return none
			]
			if any [
				word? pc/1/expr/1
				get-word? pc/1/expr/1
			][
				unless pc/1/syntax [resolve-word pc]
				if recent: pc/1/syntax/recent [
					if ret: word-value? recent [
						return reduce [1 ret/2]
					]
				]
			]
			none
		]

		fetch-block: function [pc [block! none!]][
			if tail? pc [
				return reduce [none 0]
			]
			if block? pc/1/expr/1 [
				return reduce [pc 1]
			]
			unless ret: word-value? pc [
				repend pc/1/syntax ['step 1]
				return reduce [none 1]
			]
			step: ret/1
			cast: ret/2
			if block? cast/1/expr/1 [
				return reduce [cast step]
			]
			reduce [none step]
		]

		block-mark: function [pc [block!] par [block!] type [word!]][
			unless pc/1/syntax [
				repend pc/1 ['syntax make block! 4]
			]
			repend pc/1/syntax ['type type 'parent par]
		]

		resolve-func: function [pc [block!]][
			step: 1
			ret: fetch-block next pc
			unless ret/1 [
				syntax-error pc 'miss-expr "block!"
				return step
			]
			step: step + ret/2
			spec: ret/1
			repend pc/1/syntax ['resolved resolved: make block! 4]
			either pc/1/syntax/word = 'does [
				repend resolved ['body spec]
				block-mark spec pc 'body
				if spec/1/nested [resolve-refer spec/1/nested]
				return step
			][
				repend resolved ['spec spec]
				block-mark spec pc 'spec
				if find [context all any] pc/1/syntax/word [
					if spec/1/nested [resolve-refer spec/1/nested]
					return step
				]
			]
			check-func-spec spec pc/1/syntax/word
			ret: fetch-block skip pc step
			unless ret/1 [
				syntax-error pc 'miss-expr "block!"
				return step
			]
			step: step + ret/2
			body: ret/1
			repend resolved ['body body]
			block-mark body pc 'body
			if body/1/nested [resolve-refer body/1/nested]
			step
		]

		resolve-each: function [pc [block!]][
			if all [
				any-path? pc/1/expr/1
				'`*?~+-= = last pc/1/expr/1
			][
				syntax-error pc 'invalid-path none
			]
			if pc/1/syntax [return 1]
			if all [
				word? pc/1/expr/1
				pc/1/expr/1 = 'set
			][
				if any [
					tail? npc: next pc
					not find [word! path! lit-word! lit-path!] type: type?/word npc/1/expr/1
				][
					either type = 'block! [
						syntax-error pc 'unsupport "block!"
					][
						syntax-error pc 'miss-expr "word!/path!/lit-word!/lit-path!"
					]
					return 1
				]
				resolve-set npc
				return 2
			]
			if set-word? pc/1/expr/1 [
				resolve-set pc
				return 1
			]
			if any [
				word? pc/1/expr/1
				path? pc/1/expr/1
				get-word? pc/1/expr/1
				get-path? pc/1/expr/1
			][
				either any [
					word? pc/1/expr/1
					get-word? pc/1/expr/1
				][
					resolve-word pc
					word: to word! pc/1/expr/1
					repend pc/1/syntax ['word word]
				][
					word: to word! pc/1/expr/1/1
					repend pc/1 ['syntax reduce ['word word]]
				]
				step: 1
				if all [
					none? pc/1/syntax/declare
					none? pc/1/syntax/recent
				][
					repend pc/1 ['syntax reduce ['word word]]
					if find [func function does has context all any] word [
						step: resolve-func pc
						repend pc/1/syntax ['step step]
					]
				]
				return step
			]
			if pc/1/expr = [#include][
				if any [
					tail? pc/2
					not file? pc/2/expr/1
				][
					syntax-error pc 'miss-expr "file!"
					return 1
				]
				repend/only file-block [top/1/uri pc/2/expr/1]
				return 2
			]
			if all [
				pc/1/nested
				paren? pc/1/expr/1
			][
				resolve-refer pc/1/nested
				return 1
			]
			1
		]

		resolve-refer: function [pc [block!]][
			while [not tail? pc] [
				step: resolve-each pc
				pc: skip pc step
			]
		]

		;-- TBD: if keyword can be resolved, these single cases can be simply resolved
		resolve-if: function [pc [block!]][

		]

		resolve-refer top/1/nested
	]

	analysis: function [top [block!]][
		if empty? top [exit]
		unless all [
			top/1/nested
			block? top/1/nested
		][throw-error 'analysis "expr isn't a block!" top/1]
		repend top/1 ['syntax syntax: make block! 3]
		repend syntax [
			'type 'top
			'extra make block! 20
		]
		pc: top/1/nested
		unless pc/1/expr/1 = 'Red [
			syntax-error pc 'miss-expr "'Red' for Red File header"
		]
		unless block? pc/2/expr/1 [
			syntax-error next pc 'miss-expr "block! for Red File header"
		]
		resolve top
	]

	to-range: function [src [string!] pc [block!]][
		append ast/form-pos at src pc/1/s ast/form-pos at src pc/1/e
	]

	format: function [top [block!] /semantic /pos][
		buffer: make string! 1000
		newline: function [cnt [integer!]] [
			append buffer lf
			append/dup buffer " " cnt
		]
		src: top/1/source
		format*: function [pc [block!] depth [integer!]][
			pad: depth * 4
			newline pad
			append buffer "["
			forall pc [
				newline pad + 2
				append buffer "["
				newline pad + 4
				append buffer "expr: "
				append buffer mold/flat/part pc/1/expr/1 20
				if pos [
					newline pad + 4
					append buffer "s: "
					append buffer mold pc/1/s
					newline pad + 4
					append buffer "e: "
					append buffer mold pc/1/e
				]
				newline pad + 4
				append buffer "range: "
				append buffer mold/flat to-range src pc
				if pc/1/upper [
					newline pad + 4
					append buffer "upper: "
					append buffer mold/flat to-range src pc/1/upper
				]
				if pc/1/nested [
					newline pad + 4
					append buffer "nested: "
					format* pc/1/nested depth + 1
				]
				if pc/1/source [
					newline pad + 4
					append buffer "source: "
					append buffer mold/flat/part pc/1/source 20
				]
				if pc/1/uri [
					newline pad + 4
					append buffer "uri: "
					append buffer pc/1/uri
				]
				if all [
					semantic
					pc/1/syntax
				][
					newline pad + 4
					append buffer "syntax: ["
					
					if pc/1/syntax/word [
						newline pad + 6
						append buffer "word: "
						append buffer pc/1/syntax/word
					]

					if pc/1/syntax/step [
						newline pad + 6
						append buffer "step: "
						append buffer pc/1/syntax/step
					]

					if value: pc/1/syntax/value [
						newline pad + 6
						append buffer "value: "
						append buffer mold/flat to-range src value
					]

					if cast: pc/1/syntax/cast [
						newline pad + 6
						append buffer "cast: "
						append buffer mold/flat to-range src cast
					]

					if recent: pc/1/syntax/recent [
						newline pad + 6
						append buffer "recent: "
						append buffer mold/flat to-range src recent
					]

					if declare: pc/1/syntax/declare [
						newline pad + 6
						append buffer "declare: "
						append buffer mold/flat to-range src declare
					]

					if resolved: pc/1/syntax/resolved [
						newline pad + 6
						append buffer "resolved: ["
						i: 0
						len: (length? resolved) / 2
						loop len [
							newline pad + 8
							append buffer resolved/(i * 2 + 1)
							append buffer ": "
							value: resolved/(i * 2 + 2)
							append buffer mold/flat to-range src value
							i: i + 1
						]
						newline pad + 6
						append buffer "]"
					]

					if extra: pc/1/syntax/extra [
						newline pad + 6
						append buffer "extra: ["
						forall extra [
							newline pad + 8
							append buffer mold/flat to-range src extra
						]
						newline pad + 6
						append buffer "]"
					]

					if type: pc/1/syntax/type [
						newline pad + 6
						append buffer "type: "
						append buffer type
					]

					if parent: pc/1/syntax/parent [
						newline pad + 6
						append buffer "parent: "
						append buffer mold/flat to-range src parent
					]

					if args: pc/1/syntax/args [
						newline pad + 6
						append buffer "args: ["
						i: 0
						len: (length? args) / 2
						loop len [
							newline pad + 8
							either 'params = key: args/(i * 2 + 1) [
								append buffer "params: ["
								value: args/(i * 2 + 2)
								forall value [
									newline pad + 10
									append buffer mold/flat to-range src value
								]
								newline pad + 8
								append buffer "]"
							][
								append buffer key
								append buffer ": "
								value: args/(i * 2 + 2)
								append buffer mold/flat to-range src value
							]
							i: i + 1
						]
						newline pad + 6
						append buffer "]"
					]

					newline pad + 4
					append buffer "]"
				]
				if pc/1/error [
					newline pad + 4
					append buffer "error: "
					append buffer mold/flat pc/1/error
				]
				newline pad + 2
				append buffer "]"
			]
			newline pad
			append buffer "]"
		]
		format* top 0
		buffer
	]

	form-range: function [src [string!] pc [block!]][
		ast/to-range ast/form-pos at src pc/1/s ast/form-pos at src pc/1/e
	]

	collect-errors: function [top [block!]][
		ret: make block! 4
		collect-errors*: function [pc [block!]][
			forall pc [
				if pc/1/error [
					error: pc/1/error
					either block? error/1 [
						forall error [
							err: make map! error/1
							err/range: form-range top/1/source pc
							append ret err
						]
					][
						err: make map! error
						err/range: form-range top/1/source pc
						append ret err
					]
				]
				if pc/1/nested [
					collect-errors* pc/1/nested
				]
			]
		]
		collect-errors* top
		ret
	]

	contain-error?: function [top [block!]][
		contain-error*: function [pc [block!]][
			forall pc [
				if pc/1/error [return true]
				if pc/1/nested [
					if contain-error* pc/1/nested [return true]
				]
			]
			false
		]
		contain-error* top
	]
]



source-syntax: context [
	sources: []

	find-top: function [uri [string!]][
		ss: sources
		forall ss [
			if ss/1/1/uri = uri [
				return ss/1
			]
		]
		false
	]

	find-source: function [uri [string!]][
		ss: sources
		forall ss [
			if ss/1/1/uri = uri [
				return ss
			]
		]
		false
	]

	add-source-to-table: function [uri [string!] syntax [block!]][
		repend syntax/1 ['uri uri]
		either item: find-source uri [
			item/1: syntax
		][
			append/only sources syntax
		]
	]

	add-source: function [uri [string!] code [string!] /change?][
		if all [
			change?
			top: find-top uri
			top/1/source = code
		][return none]
		diagnostics: clear []
		if map? res: ast/analysis code [
			range: ast/to-range res/pos res/pos
			line-cs: charset [#"^M" #"^/"]
			info: res/error/arg2
			if part: find info line-cs [info: copy/part info part]
			message: rejoin [res/error/id " ^"" res/error/arg1 "^" at: ^"" info "^""]
			diag: make map! reduce [
				'uri uri
				'diagnostics make map! reduce [
					'range range
					'severity 1
					'code 1
					'source "lexer"
					'message message
				]
			]
			return reduce [diag]
		]
		add-source-to-table uri res
		unless change? [
			clear file-block
			semantic/analysis res
			err: semantic/collect-errors res
			diags: make map! reduce [
				'uri uri
				'diagnostics err
			]
			return diags
		]
		none
	]
]

completion: context [
	last-comps: clear []

	complete-file: function [top [block!] pc [block!] comps [block!]][
		range: semantic/form-range top/1/source pc
		str: to string! pc/1/expr/1
		insert str: to string! file: pc/1/expr/1 "%"
		if error? result: try [red-complete-ctx/red-complete-file str no][
			exit
		]
		either #"/" = last file [
			filter: ""
			range/start: range/end
		][
			either item: find/tail/last file "/" [
				range/start/character: range/start/character + index? item
				filter: find/tail/last str "/"
			][
				range/start/character: range/start/character + 1
				filter: next str
			]
		]
		forall result [
			if file? item-str: result/1 [
				item-str: to string! item-str
				insert item-str "%"
			]
			slash-end?: no
			if #"/" = last item-str [
				remove back tail item-str
				slash-end?: yes
			]
			either item2: find/tail/last item-str "/" [
				item-str: item2
			][
				item-str: next item-str
			]
			if slash-end? [
				append item-str "/"
			]
			item-file: next mold to file item-str
			append comps make map! reduce [
				'label item-str
				'kind CompletionItemKind/File
				'filterText? filter
				'insertTextFormat 1
				'textEdit make map! reduce [
					'range range
					'newText item-file
				]
			]
		]
	]

	unique?: function [npc [block!] word [word!]][
		forall npc [
			if word = to word! npc/1/1/expr/1 [return false]
		]
		true
	]

	collect-word*: function [pc [block!] word [word!] result [block!]][
		string: to string! word
		collect*: function [npc [block!] type [block!] info [word!] /back?][
			until [
				if find type type?/word npc/1/expr/1 [
					nword: to word! npc/1/expr/1
					nstring: to string! nword
					if find/match nstring string [
						if unique? result nword [
							repend npc/1 ['info info]
							append/only result npc
						]
					]
				]
				either back? [
					npc2: back npc
					either npc = npc2 [
						npc: none
					][
						npc: npc2
					]
				][
					if tail? npc: next npc [npc: none]
				]
				none? npc
			]
		]
		npc: npc2: pc
		forever [
			npc: back npc
			collect*/back? npc [set-word!] 'set
			either all [
				not tail? npc2
				par: npc2/1/upper
				none? par/1/source
			][
				if all [
					par/-1
					block? par/-1/expr/1
					spec: par/-1/nested
					par/-2
					find [func function has] par/-2/expr/1
				][
					collect* spec [word! lit-word! refinement!] 'declare
				]
				npc2: par
				npc: tail par
			][break]
		]
	]

	collect-word: function [top [block!] pc [block!] result [block!]][
		sources: source-syntax/sources
		forall sources [
			either sources/1 = top [
				collect-word* pc to word! pc/1/expr/1 result
			][
				collect-word* tail sources/1/1/nested to word! pc/1/expr/1 result
			]
		]
	]

	complete-word: function [top [block!] pc [block!] comps [block!]][
		system-completion-kind: function [word [word!]][
			type: type?/word get word
			kind: case [
				datatype? get word [
					CompletionItemKind/Keyword
				]
				typeset? get word [
					CompletionItemKind/Keyword
				]
				'op! = type [
					CompletionItemKind/Operator
				]
				find [action! native! function! routine!] type [
					CompletionItemKind/Function
				]
				'object! = type [
					CompletionItemKind/Class
				]
				true [
					CompletionItemKind/Variable
				]
			]
		]
		range: semantic/form-range top/1/source pc
		if any [
			lit-word? pc/1/expr/1
			get-word? pc/1/expr/1
		][
			range/start/character: range/start/character + 1
		]
		string: to string! to word! pc/1/expr/1
		collect-word top pc result: clear []
		forall result [
			rpc: result/1
			top: rpc
			while [par: top/1/upper][top: par]
			kind: CompletionItemKind/Variable
			type: type?/word rpc/1/expr/1
			rstring: to string! to word! rpc/1/expr/1
			case [
				find [word! lit-word! refinement!] type [
					kind: CompletionItemKind/TypeParameter
				]
				type = 'set-word! [
					npc: rpc
					while [
						all [
							not tail? npc: next npc
							set-word? npc/1/expr/1
						]
					][]
					unless tail? npc [
						case [
							find [func function does has] npc/1/expr/1 [
								kind: CompletionItemKind/Function
							]
							npc/1/expr/1 = 'context [
								kind: CompletionItemKind/Struct
							]
						]
					]
				]
			]
			append comps make map! reduce [
				'label rstring
				'kind kind
				'filterText? string
				'insertTextFormat 1
				'preselect true
				'textEdit make map! reduce [
					'range range
					'newText rstring
				]
				'data make map! reduce [
					'uri top/1/uri
					's rpc/1/s
					'e rpc/1/e
					'type "word"
				]
			]
		]
		words: system-words/system-words
		forall words [
			sys-string: to string! words/1
			if find/match sys-string string [
				append comps make map! reduce [
					'label sys-string
					'kind system-completion-kind words/1
					'filterText? string
					'insertTextFormat 1
					'textEdit make map! reduce [
						'range range
						'newText sys-string
					]
					'data make map! reduce [
						'type "system"
					]
				]
			]
		]
	]

	find-set-context: function [pc [block!] specs [block! none!]][
		word: to word! pc/1/expr/1
		find-set-context*: function [npc [block!]][
			npc2: npc
			until [
				npc: npc2
				if all [
					set-word? npc/1/expr/1
					word = to word! npc/1/expr/1
					npc/2
					any [
						all [
							npc/2/expr/1 = 'context
							npc/3
							block? npc/3/expr/1
							spec: npc/3/nested
						]
						all [
							npc/2/expr/1 = 'make
							npc/3
							npc/3/expr/1 = 'block!
							npc/4
							block? npc/4/expr/1
							spec: npc/4/nested
						]
						all [
							npc/2/expr/1 = 'make
							npc/3
							word? npc/3/expr/1
							word <> npc/3/expr/1
							npc/4
							block? npc/4/expr/1
							spec: npc/4/nested
							ret: find-set-context* skip npc 2
						]
					]
				][
					if specs [
						append/only specs spec
					]
					return true
				]
				npc2: back npc
				npc = npc2
			]
			if par: npc/1/upper [
				if ret: find-set-context* back tail par [
					return ret
				]
			]
			false
		]
		find-set-context* pc
	]

	collect-root-word*: function [pc [block!] word [word!]][
		result: make block! 16
		collect*: function [npc [block!]][
			until [
				if all [
					set-word? npc/1/expr/1
					word = to word! npc/1/expr/1
					npc/2
					any [
						all [
							find [func function] npc/2/expr/1
							npc/3
							block? npc/3/expr/1
							npc/4
							block? npc/4/expr/1
							spec: npc/3/nested
						]
						all [
							npc/2/expr/1 = 'context
							npc/3
							block? npc/3/expr/1
							spec: npc/3/nested
						]
						all [
							npc/2/expr/1 = 'make
							npc/3
							any [
								all [
									word? npc/3/expr/1
									npc/3/expr/1 <> word
									find-set-context skip npc 2 result
								]
								npc/3/expr/1 = 'object!
							]
							npc/4
							block? npc/4/expr/1
							spec: npc/4/nested
						]
					]
				][
					append/only result spec
					break
				]

				npc2: back npc
				either npc = npc2 [
					npc: none
				][
					npc: npc2
				]
				none? npc
			]
		]
		npc: npc2: pc
		forever [
			npc: back npc
			collect* npc
			either all [
				not tail? npc2
				par: npc2/1/upper
				none? par/1/source
			][
				npc2: par
				npc: tail par
			][break]
		]
		result
	]

	collect-sub-word*: function [pc [block!] word [word!] result [block!] slash-end? [logic!]][
		string: to string! word
		collect*: function [npc [block!]][
			until [
				if all [
					not slash-end?
					any [
						set-word? npc/1/expr/1
						all [
							refinement? npc/1/expr/1
							par: npc/1/upper
							find [func function] par/-1/expr/1
						]
					]
					find/match to string! npc/1/expr/1 string
				][
					if unique? result to word! npc/1/expr/1 [
						append/only result npc
					]
				]
				if all [
					slash-end?
					set-word? npc/1/expr/1
					word = to word! npc/1/expr/1
					npc/2
				][
					case [
						all [
							find [func function] npc/2/expr/1
							npc/3
							block? npc/3/expr/1
							spec: npc/3/nested
							npc/4
							block? npc/4/expr/1
						][
							forall spec [
								if all [
									refinement? spec/1/expr/1
									unique? result to word! spec/1/expr/1
								][
									append/only result spec
								]
							]
						]
						any [
							all [
								npc/2/expr/1 = 'context
								npc/3
								block? npc/3/expr/1
								spec: npc/3/nested
							]
							all [
								npc/2/expr/1 = 'make
								npc/3
								npc/3/expr/1 = 'object!
								npc/4
								block? npc/4/expr/1
								spec: npc/4/nested
							]
						][
							forall spec [
								if all [
									set-word? spec/1/expr/1
									unique? result to word! spec/1/expr/1
								][
									append/only result spec
								]
							]
						]
						all [
							npc/2/expr/1 = 'make
							npc/3
							word? npc/3/expr/1
							npc/3/expr/1 <> npc/1/expr/1
							npc/4
							block? npc/4/expr/1
							spec: npc/4/nested
						][
							forall spec [
								if all [
									set-word? spec/1/expr/1
									unique? result to word! spec/1/expr/1
								][
									append/only result spec
								]
							]
							specs: clear []
							if find-set-context skip npc 2 specs [
								forall specs [
									spec: specs/1
									if all [
										set-word? spec/1/expr/1
										unique? result to word! spec/1/expr/1
									][
										append/only result spec
									]
								]
							]
						]
					]
				]

				npc2: back npc
				either npc = npc2 [
					npc: none
				][
					npc: npc2
				]
				none? npc
			]
		]
		collect* back pc
		result
	]

	collect-path*: function [pc [block!] path [path!] result [block!]][
		slash-end?: no
		if '`*?~+-= = last path [
			remove back tail path
			slash-end?: yes
		]

		ret: collect-root-word* pc path/1
		unless path/2 [
			tops: ret
			forall tops [
				npc: npc2: back tail tops/1
				until [
					if set-word? npc/1/expr/1 [
						if unique? result to word! npc/1/expr/1 [
							append/only result npc
						]
					]
					npc2: back npc
					either npc = npc2 [
						npc: none
					][
						npc: npc2
					]
					none? npc
				]
			]
			exit
		]
		path: next path
		until [
			tops: ret
			ret: make block! 4
			slash?: slash-end?
			unless tail? next path [
				slash?: yes
			]
			forall tops [
				collect-sub-word* tail tops/1 path/1 ret slash?
			]
			tail? path: next path
		]
		append result ret
	]

	collect-path: function [top [block!] pc [block!] result [block!]][
		sources: source-syntax/sources
		forall sources [
			either sources/1 = top [
				collect-path* pc to path! pc/1/expr/1 result
			][
				collect-path* tail sources/1/1/nested to path! pc/1/expr/1 result
			]
		]
	]

	complete-path: function [top [block!] pc [block!] comps [block!]][
		complete-sys-path: function [][
			words: system-words/system-words
			unless find words fword [exit]
			if error? result: try [red-complete-ctx/red-complete-path to string! pc/1/expr/1 no][
				exit
			]
			forall result [
				unless nstring: find/tail/last result/1 [
					nstring: result/1
				]
				append comps make map! reduce [
					'label nstring
					'kind CompletionItemKind/Field
					'filterText? filter
					'insertTextFormat 1
					'preselect true
					'textEdit make map! reduce [
						'range range
						'newText nstring
					]
					'data make map! reduce [
						'path to string! path
						'type "system-path"
					]
				]
			]
		]
		path: copy pc/1/expr/1
		fword: pc/1/expr/1/1
		fstring: to string! fword
		filter: to string! last pc/1/expr/1
		slash-end?: no
		if '`*?~+-= = last pc/1/expr/1 [
			remove back tail path
			slash-end?: yes
			filter: ""
		]
		range: semantic/form-range top/1/source pc
		either slash-end? [
			range/start/character: range/end/character
		][
			range/start/character: range/end/character - length? filter
		]
		pcs: clear []
		collect-path top pc pcs
		forall pcs [
			rpc: pcs/1
			ntop: rpc
			while [par: ntop/1/upper][ntop: par]
			nstring: to string! rpc/1/expr/1
			append comps make map! reduce [
				'label nstring
				'kind CompletionItemKind/Field
				'filterText? filter
				'insertTextFormat 1
				'preselect true
				'textEdit make map! reduce [
					'range range
					'newText nstring
				]
				'data make map! reduce [
					'uri ntop/1/uri
					's rpc/1/s
					'e rpc/1/e
					'type "path"
				]
			]
		]
		complete-sys-path
	]

	complete: function [uri [string!] line [integer!] column [integer!]][
		unless top: source-syntax/find-top uri [return none]
		pos: ast/to-pos top/1/source line column
		unless pc: semantic/position? top index? pos [
			return none
		]
		type: type?/word pc/1/expr/1
		unless find [word! lit-word! get-word! path! lit-path! get-path! file!] type [
			return none
		]
		comps: clear last-comps
		if type = 'file! [
			complete-file top pc comps
			return comps
		]
		if find [word! lit-word! get-word!] type [
			complete-word top pc comps
			return comps
		]
		if find [path! lit-path! get-path!] type [
			complete-path top pc comps
			return comps
		]
		none
	]

	func-info: function [fn [word!] spec [block! none!] name [string!]][
		if error? *-*spec*-*: try [
			either spec [
				do reduce [fn spec []]
			][
				do reduce [fn []]
			]
		][
			return rejoin [name " is a funtion with invalid spec"]
		]
		str: help-string *-*spec*-*
		replace/all str "*-*spec*-*" name
		return str
	]

	resolve-word: function [top [block!] pc [block!] string [string!]][
		if pc/1/info = 'declare [
			ret: rejoin [string " is a function argument!"]
			if all [
				pc/2
				block? pc/2/expr/1
			][
				return rejoin [ret "^/type: " mold pc/2/expr/1]
			]
			return ret
		]
		if all [
			set-word? pc/1/expr/1
			pc/2
		][
			if find-set-context pc none [
				return rejoin [string " is a context!"]
			]
			case [
				find [func function has] pc/2/expr/1 [
					if all [
						pc/3
						block? pc/3/expr/1
					][
						return func-info pc/2/expr/1 pc/3/expr/1 to string! pc/1/expr/1
					]
				]
				pc/2/expr/1 = 'does [
					return func-info pc/2/expr/1 [] to string! pc/1/expr/1
				]
				word? pc/2/expr/1 [
					return rejoin [string ": " mold pc/2/expr/1]
				]
			]
			return rejoin [string " is a " mold type?/word pc/2/expr/1 " variable."]
		]
		if refinement? pc/1/expr/1 [
			return rejoin [string " is a function's refinement!"]
		]
		none
	]

	resolve: function [params [map!]][
		if params/kind = CompletionItemKind/File [return none]
		if all [
			params/data
			params/data/type = "system"
		][
			word: to word! params/label
			if datatype? get word [
				return rejoin [params/label " is a base datatype!"]
			]
			return system-words/get-word-info word
		]
		if all [
			params/data
			params/data/type = "system-path"
			params/data/path
		][
			path: to path! params/data/path
			return system-words/get-path-info path
		]
		if all [
			params/data
			any [
				params/data/type = "word"
				params/data/type = "path"
			]
		][
			uri: params/data/uri
			s: to integer! params/data/s
			e: to integer! params/data/e
			unless top: source-syntax/find-top uri [return none]
			unless pc: semantic/find-expr top s e [
				return none
			]
			if str: resolve-word top pc params/label [
				append str rejoin ["^/^/FILE: " mold ast/uri-to-file uri]
			]
			return str
		]
		none
	]
]
