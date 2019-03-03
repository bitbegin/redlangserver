Red [
	Title:   "Red syntax for Red language server"
	Author:  "bitbegin"
	File: 	 %syntax.red
	Tabs:	 4
	Rights:  "Copyright (C) 2011-2019 Red Foundation. All rights reserved."
	License: "BSD-3 - https://github.com/red/red/blob/origin/BSD-3-License.txt"
]

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

	position?: function [top [block!] pos [integer!] /outer][
		position*: function [pc [block!] pos [integer!]][
			cascade: [
				if pc/1/nested [
					if ret: position* pc/1/nested pos [return ret]
				]
				return pc
			]
			forall pc [
				if all [
					pc/1/s <= pos
					pc/1/e >= pos
				][
					if any [
						outer
						pc/1/e <> pos
					][do cascade]
					if all [
						outer
						any [
							tail? next pc
							pc/2/s <> pos
						]
					][
						return pc
					]
					break
				]
			]
			none
		]
		position* top pos
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

	collect-completions: function [top [block!] pc [block!] /extra][
		ret: clear []
		str: clear ""
		unique?: function [word [string!]][
			npc: ret
			forall npc [
				if word = to string! npc/1/expr/1 [return false]
			]
			true
		]
		collect*: function [npc [block!]][
			word: to string! npc/1/expr/1
			if any [
				empty? str
				find/match word str
			][
				if all [
					unique? word
					npc <> pc
				][
					append/only ret npc/1
				]
			]
		]
		collect-set-word: function [npc [block!]][
			forall npc [
				if set-word? npc/1/expr/1 [
					collect* npc
				]
			]
		]

		collect-arg: function [spec [block!]][
			if npc: spec/1/nested [
				forall npc [
					if find [word! lit-word! get-word! refinement!] type?/word npc/1/expr/1 [
						collect* npc
					]
				]
			]
		]

		collect-func-spec: function [pc [block! none!]][
			unless pc [exit]
			par: pc/1/upper
			if all [
				par
				block? par/1/expr/1
				par/1/syntax
				par/1/syntax/type = 'body
				parent: par/1/syntax/parent
				find [func has function does] parent/1/syntax/word
				spec: parent/1/syntax/resolved/spec
			][
				collect-arg spec
			]
		]

		either extra [
			str: to string! pc/1/expr/1
			npc: top/1/nested
			forall npc [
				if set-word? npc/1/expr/1 [
					collect* npc
				]
			]
		][
			either pc/1/nested [
				collect-func-spec pc
				collect-set-word pc/1/nested
			][
				unless find [word! get-word! file!] type?/word pc/1/expr/1 [
					return reduce [reduce ['expr [] 'source top/1/source 's top/1/s 'e top/1/e 'nested ret]]
				]
				str: to string! pc/1/expr/1
			]

			npc: pc
			until [
				par: npc/1/upper
				collect-func-spec par
				collect-set-word head npc
				not npc: par
			]
		]
		if npc: top/1/syntax/extra [
			forall npc [
				if set-word? npc/1/expr/1 [
					collect* npc
				]
			]
		]
		reduce [reduce ['expr [] 'source top/1/source 's top/1/s 'e top/1/e 'nested ret]]
	]
]

source-syntax: context [
	sources: make block! 4
	last-comps: []

	find-source: function [uri [string!]][
		forall sources [
			if sources/1/uri = uri [
				return sources
			]
		]
		false
	]

	find-top: function [uri [string!]][
		unless item: find-source uri [
			return none
		]
		item/1/syntax
	]

	add-source-to-table: function [uri [string!] syntax [block!]][
		either item: find-source uri [
			item/1/syntax: syntax
		][
			append/only sources reduce ['uri uri 'syntax syntax]
		]
	]

	add-source: function [uri [string!] code [string!] /change?][
		if map? res: ast/analysis code change? [
			range: ast/to-range res/pos res/pos
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
		semantic/analysis res
		semantic/collect-errors res
	]

	semicolon?: function [pc [block!] pos [string!] column [integer!]][
		if pos/1 = #";" [return true]
		repeat count column [
			if pos/(0 - count) = #";" [return true]
		]
		false
	]

	complete-file: function [uri [string!] top [block!] pc [block!] comps [block!]][
		range: semantic/form-range top/1/source pc
		str: to string! pc/1/expr/1
		insert str: to string! file: pc/1/expr/1 "%"
		if error? completions: try [red-complete-ctx/red-complete-file str no][
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
		forall completions [
			if file? item-str: completions/1 [
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

	complete-word: function [uri [string!] top [block!] pc [block!] comps [block!]][
		range: semantic/form-range top/1/source pc
		str: to string! pc/1/expr/1
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
		complete-system-word: function [][
			words: system-words/system-words
			forall words [
				sys-word: mold words/1
				if find/match sys-word str [
					append comps make map! reduce [
						'label sys-word
						'kind system-completion-kind words/1
						'filterText? str
						'insertTextFormat 1
						'textEdit make map! reduce [
							'range range
							'newText sys-word
						]
						'data make map! reduce [
							'type "system"
						]
					]
				]
			]
		]
		variable-kind: function [pc [block!]][
			if cast: pc/1/syntax/cast [
				if find [func function does has] cast/1/expr/1 [
					return CompletionItemKind/Function
				]
				if cast/1/expr/1 = 'context [
					return CompletionItemKind/Class
				]
				return CompletionItemKind/Variable
			]
			if pc/1/syntax/declare [
				return CompletionItemKind/TypeParameter
			]
			CompletionItemKind/Variable
		]
		forall sources [
			top2: sources/1/syntax
			ctop: either sources/1/uri = uri [
				semantic/collect-completions top2 pc
			][
				semantic/collect-completions/extra top2 pc
			]
			if collects: ctop/1/nested [
				forall collects [
					comp: make map! reduce [
						'label lable: to string! collects/1/expr/1
						'kind variable-kind collects
						'filterText? str
						'insertTextFormat 1
						'textEdit make map! reduce [
							'range range
							'newText lable
						]
						'data make map! reduce [
							'uri uri
							's collects/1/s
							'e collects/1/e
						]
					]
					if sources/1/uri = uri [
						put comp 'preselect true
					]
					append comps comp
				]
			]
		]
		complete-system-word
	]

	complete-path: function [uri [string!] top [block!] pc [block!] comps [block!]][
		range: semantic/form-range top/1/source pc
		str: to string! pc/1/expr/1
		completions: red-complete-ctx/red-complete-path str no
		forall completions [
			append comps make map! reduce [
				'label completions/1
				'kind CompletionItemKind/Property
			]
		]
	]

	get-completions: function [uri [string!] line [integer!] column [integer!]][
		unless top: find-top uri [return none]
		pos: ast/to-pos top/1/source line column
		unless pc: semantic/position?/outer top index? pos [
			return none
		]
		if all [
			block? pc/1/expr/1
			semicolon? pc pos column
		][
			return none
		]
		comps: clear last-comps
		case [
			file? pc/1/expr/1 [complete-file uri top pc comps]
			path? pc/1/expr/1 [complete-path uri top pc comps]
			word? pc/1/expr/1 [complete-word uri top pc comps]
			true [comps: none]
		]
		comps
	]

	func-info: function [pc [block!] name [string!]][
		func-info*: function [fn [word!] spec [block! none!] name [string!]][
			either spec [
				*-*spec*-*: do reduce [fn spec []]
			][
				*-*spec*-*: do reduce [fn []]
			]
			str: help-string *-*spec*-*
			replace/all str "*-*spec*-*" name
			return str
		]
		if pc/1/syntax/resolved [
			if all [
				find [func function has] pc/1/syntax/word
				spec: pc/1/syntax/resolved/spec
			][
				if any [
					none? spec/1/nested
					semantic/contain-error? spec/1/nested
				][
					return func-info* pc/1/syntax/word [] name
				]
				return func-info* pc/1/syntax/word spec/1/expr/1 name
			]
			if pc/1/syntax/word = 'does [
				return func-info* pc/1/syntax/word none name
			]
		]
		none
	]

	resolve-completion: function [params [map!]][
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
			uri: params/data/uri
			s: params/data/s
			e: params/data/e
		][
			s: to integer! s
			e: to integer! e
			unless top: find-top uri [return none]
			unless pc: semantic/find-expr top s e [
				return none
			]
			if declare: pc/1/syntax/declare [
				if any [
					word? declare/1/expr/1
					get-word? declare/1/expr/1
					refinement? declare/1/expr/1
				][
					if declare/1/syntax/args/refs [
						return rejoin [params/label " is a local argument"]
					]
					if all [
						declare/2
						block? declare/2/expr/1
					][
						return rejoin [params/label " is a function argument^/type: " mold declare/2/expr/1]
					]
					return rejoin [params/label " is a function argument"]
				]
				return rejoin [params/label " is a local argument"]
				
			]
			if cast: pc/1/syntax/cast [
				if info: func-info cast params/label [
					return info
				]
				if cast/1/syntax/word = 'context [
					return rejoin [params/label " is a context!"]
				]
			]
			return rejoin [params/label " is a variable!"]
		]
		none
	]

	hover: function [uri [string!] line [integer!] column [integer!]][
		has-spec?: function [npc [block!]][
			if cast: npc/1/syntax/cast [
				if info: func-info cast mold npc/1/expr/1 [
					return info
				]
				if cast/1/syntax/word = 'context [
					return rejoin [mold npc/1/expr/1 " is a context"]
				]
			]
			return none
		]
		unless top: find-top uri [return none]
		pos: ast/to-pos top/1/source line column
		unless pc: semantic/position?/outer top index? pos [
			return none
		]
		if all [
			block? pc/1/expr/1
			semicolon? pc pos column
		][
			return none
		]
		unless pc/1/syntax [
			case [
				word? pc/1/expr/1 [
					word: pc/1/expr/1
					if datatype? get word [
						return rejoin [mold pc/1/expr/1 " is a base datatype!"]
					]
				]
				path? pc/1/expr/1 [
					word: pc/1/expr/1/1
				]
				true [
					type: type?/word pc/1/expr/1
					if find [block! paren! map!] type [
						return rejoin [mold mold/flat/part pc/1/expr/1 16 "...^/is a " mold type]
					]
					unless find [set-word! set-path!] type [
						return rejoin [mold pc/1/expr/1 " is a literal^/type: " mold type]
					]
					return none
				]
			]
			return system-words/get-word-info word
		]
		if any [
			lit-word? pc/1/expr/1
			set-word? pc/1/expr/1
		][
			if value: pc/1/syntax/value [
				return rejoin [mold pc/1/expr/1 
					either pc/1/syntax/declare [
						" is a function argument^/"
					][
						" is a variable^/"
					]
					"value type: "
					mold type?/word value/1/expr/1
				]
			]
			return has-spec? pc
		]

		if any [
			word? pc/1/expr/1
			get-word? pc/1/expr/1
			path? pc/1/expr/1
			get-path? pc/1/expr/1
		][
			if pc/1/syntax/declare [
				return rejoin [mold pc/1/expr/1 " is a function argument"]
			]
			if recent: pc/1/syntax/recent [
				if value: recent/1/syntax/value [
					return rejoin [mold pc/1/expr/1 " is a variable^/"
						"value type: " mold type?/word value/1/expr/1
					]
				]
				return has-spec? recent
			]
			if all [
				pc/1/syntax/word
				system-words/system? pc/1/syntax/word
			][
				return system-words/get-word-info pc/1/syntax/word
			]
			if all [
				word? word: pc/1/expr/1
				pc/1/syntax/type = 'func-type-item
				datatype? get word
			][
				return rejoin [mold word " is a base datatype!"]
			]
		]
		none
	]
]
