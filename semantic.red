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
					if ret: find-expr* pc/1/nested pos [return ret]
				]
			]
			none
		]
		find-expr* top pos
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
					pc/1/s >= pos
					pc/1/e <= pos
				][
					if pc/1/e <> pos [do cascade]
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
		position* top line column
	]

	get-parent: function [top [block!] item [block!]][
		get-parent*: function [pc [block!] par [block!]][
			forall pc [
				if all [
					item/s = pc/1/s
					item/e = pc/1/e
				][return par]
				if pc/1/nested [
					if ret: get-parent* pc/1/nested pc [return ret]
				]
			]
			none
		]
		if top/1 = item [return none]
		get-parent* top/1/nested top
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
					expr2: npc2/1/nested
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
			expr2: npc2/1/nested
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
			next npc2
		]
		check-refines: function [npc [block!]][
			collect-args: function [npc [block!] par [block!]][
				while [not tail? npc][
					either word? npc/1/expr/1 [
						append/only par/1/syntax/args/params npc
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
		pc: par/1/nested
		if all [
			block? pc
			empty? pc
		][
			exit
		]
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
			npc: spec/1/nested
			forall npc [
				if all [
					find [word! lit-word! get-word! refinement!] type?/word npc/1/expr/1
					word = to word! npc/1/expr/1
				][
					return npc
				]
			]
		]
		none
	]

	spec-of-func-body: function [top [block!] pc [block!]][
		npc: head pc
		forall npc [
			if all [
				npc/1/syntax
				find [func function has] npc/1/syntax/word
				npc/1/syntax/resolved
				npc/1/syntax/resolved/body = pc
			][
				return npc/1/syntax/resolved/spec
			]
		]
		none
	]

	func-spec-declare?: function [top [block!] pc [block!]][
		word: to word! pc/1/expr/1
		find-func-spec: function [par [block!]][
			if all [
				block? par/1/expr/1
				par <> top
				spec: spec-of-func-body top par
				ret: func-arg? spec word
			][
				return ret
			]
			none
		]
		par: pc
		forever [
			unless par: get-parent top par/1 [
				return none
			]
			if ret: find-func-spec par [
				return ret
			]
		]
		none
	]

	recent-set?: function [top [block!] pc [block!]][
		word: to word! pc/1/expr/1
		find-set-word: function [npc [block! paren!]][
			forall npc [
				if all [
					pc <> npc
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
			not npc: get-parent top npc/1
		]
		none
	]

	resolve: function [top [block! paren!]][
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
				declare: func-spec-declare? top pc
			][
				repend pc/1/syntax ['declare declare]
			]
			resolve-set* pc
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
				resolve-set recent
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

		set-into: function [pc [block!]][
			either pc/1/syntax [
				unless pc/1/syntax/into [
					repend pc/1/syntax ['into true]
				]
			][
				repend pc/1 ['syntax reduce ['into true]]
			]
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
				set-into spec
				if spec/1/nested [resolve-refer spec/1/nested]
				return step
			][
				repend resolved ['spec spec]
				if find [context all any] pc/1/syntax/word [
					set-into spec
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
			spec: ret/1
			set-into spec
			repend resolved ['body spec]
			if spec/1/nested [resolve-refer spec/1/nested]
			step
		]

		resolve-each: function [pc [block!]][
			if pc/1/syntax [return 1]
			if pc/1/expr/1 = 'set [
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
			if any [
				set-word? pc/1/expr/1
				set-path? pc/1/expr/1
			][
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
			'name "top"
			'step 1
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

	format: function [top [block!] /semantic][
		buffer: make string! 1000
		newline: function [cnt [integer!]] [
			append buffer lf
			append/dup buffer " " cnt
		]
		format*: function [pc [block! paren!] depth [integer!]][
			pad: depth * 4
			newline pad
			append buffer "["
			forall pc [
				newline pad + 2
				append buffer "["
				newline pad + 4
				append buffer "expr: "
				append buffer mold/flat/part pc/1/expr/1 20
				newline pad + 4
				append buffer "s: "
				append buffer mold pc/1/s
				newline pad + 4
				append buffer "e: "
				append buffer mold pc/1/e
				newline pad + 4
				append buffer "depth: "
				append buffer mold pc/1/depth
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
				if pc/1/max-depth [
					newline pad + 4
					append buffer "max-depth: "
					append buffer pc/1/max-depth
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

					if pc/1/syntax/into [
						newline pad + 6
						append buffer "into: "
						append buffer pc/1/syntax/into
					]

					if pc/1/syntax/step [
						newline pad + 6
						append buffer "step: "
						append buffer pc/1/syntax/step
					]

					if value: pc/1/syntax/value [
						newline pad + 6
						append buffer "value: "
						append buffer mold/flat reduce [value/1/s value/1/e]
					]

					if cast: pc/1/syntax/cast [
						newline pad + 6
						append buffer "cast: "
						append buffer mold/flat reduce [cast/1/s cast/1/e]
					]

					if declare: pc/1/syntax/declare [
						newline pad + 6
						append buffer "declare: "
						append buffer mold/flat reduce [declare/1/s declare/1/e]
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
							append buffer mold/flat reduce [value/1/s value/1/e]
							i: i + 1
						]
					]

					if type: pc/1/syntax/type [
						newline pad + 6
						append buffer "type: "
						append buffer type
					]

					if parent: pc/1/syntax/parent [
						newline pad + 6
						append buffer "parent: "
						append buffer mold/flat reduce [parent/1/s parent/1/e]
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
									append buffer mold/flat reduce [value/1/1/s value/1/1/e]
								]
								newline pad + 8
								append buffer "]"
							][
								append buffer key
								append buffer ": "
								value: args/(i * 2 + 2)
								append buffer mold/flat reduce [value/1/s value/1/e]
							]
							i: i + 1
						]
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

	to-range: function [src [string!] pc [block!]][
		ast/to-range ast/form-pos at src pc/1/s ast/form-pos at src pc/1/e
	]

	collect-errors: function [top [block!]][
		ret: make block! 4
		collect-errors*: function [pc [block!]][
			blk: [
				if pc/1/error [
					error: pc/1/error
					either block? error/1 [
						forall error [
							err: make map! error/1
							err/range: to-range pc
							append ret err
						]
					][
						err: make map! error
						err/range: to-range top/1/source pc
						append ret err
					]
				]
			]
			forall pc [
				either pc/1/nested [
					do blk
					collect-errors* pc/1/nested
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
