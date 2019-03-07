Red [
	Title:   "Red syntax for Red language server"
	Author:  "bitbegin"
	File: 	 %syntax.red
	Tabs:	 4
	Rights:  "Copyright (C) 2011-2019 Red Foundation. All rights reserved."
	License: "BSD-3 - https://github.com/red/red/blob/origin/BSD-3-License.txt"
]

semantic: context [
	sources: []
	file-block: []
	diagnostics: []

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

	syntax-error: function [pc [block!] word [word!] args][
		switch/default word [
			invalid-path [
				path: copy pc/1/expr/1
				remove back tail path
				create-error pc/1 'Error 'invalid-path
					rejoin [mold path "/ -- invalid path"]
			]
			invalid-spec [
				create-error pc/1 'Error 'invalid-spec
					rejoin ["invalid function spec: " args]
			]
		][
			create-error pc/1 'Error 'unknown
				rejoin [mold pc/1/expr/1 " -- unknown error: " mold word]
		]
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

	analysis-error: function [top [block!]][
		analysis-each: function [pc [block!]][
			if all [
				path? pc/1/expr/1
				'`*?~+-= = last pc/1/expr/1
			][
				syntax-error pc 'invalid-path none
				return 1
			]
			if all [
				find [func function has] pc/1/expr/1
				pc/2
				block? pc/2/expr/1
				pc/3
				block? pc/3/expr/1
			][
				spec: pc/2/expr/1
				if error? err: try [do reduce [pc/1/expr/1 spec []]] [
					syntax-error next pc 'invalid-spec form err
				]
				if pc/3/nested [
					analysis-iter pc/3/nested
				]
				return 3
			]
			if all [
				find [does context object] pc/1/expr/1
				pc/2
				block? pc/2/expr/1
				nested: pc/2/nested
			][
				analysis-iter nested
				return 2
			]
			if all [
				pc/1/expr/1 = 'make
				pc/2
				any [
					pc/2/expr/1 = 'object!
					word? pc/2/expr/1
				]
				pc/3
				block? pc/3/expr/1
				nested: pc/3/nested
			][
				analysis-iter nested
				return 3
			]
			1
		]

		analysis-iter: function [pc [block!]][
			while [not tail? pc] [
				step: analysis-each pc
				pc: skip pc step
			]
		]

		write-log "analysis-error: begin"
		write-log mold now/precise

		analysis-iter top/1/nested
		err: collect-errors top
		append diagnostics make map! reduce [
			'uri top/1/uri
			'diagnostics err
		]
		write-log mold now/precise
		write-log "analysis-error: end"
	]

	add-include-file: function [top [block!]][
		include-file: function [file [file!]][
			if all [
				exists? file
				code: read file
			][
				uri: ast/file-to-uri file
				write-log rejoin ["include: " uri]
				if any [
					not top: find-top uri
					top/1/source <> code
				][
					write-log "will parse code..."
					add-source* uri code
				]
			]
		]

		include-each: function [pc [block!]][
			if all [
				issue? pc/1/expr/1
				"include" = to string! pc/1/expr/1
				pc/2
				file? file: pc/2/expr/1
			][
				if #"/" = last file [
					return 2
				]
				if #"/" = first file [
					include-file file
					return 2
				]
				dir: copy origin-dir
				unless find file "/" [
					append dir file
					include-file dir
					return 2
				]
				nfile: copy file
				forever [
					unless t1: find/tail nfile "/" [
						append dir nfile
						include-file dir
						return 2
					]
					t2: copy/part nfile t1
					case [
						t2 = %../ [
							unless dir: dir-back dir [
								return 2
							]
						]
						t2 = %./ []
						true [
							append dir t2
						]
					]
					nfile: t1
				]
				return 2
			]
			1
		]

		include-iter: function [pc [block!]][
			while [not tail? pc] [
				step: include-each pc
				pc: skip pc step
			]
		]

		dir-back: function [dir* [file!]][
			dir: copy dir*
			if #"/" = last dir [return none]
			remove back tail dir
			unless t1: find/last/tail dir "/" [
				return none
			]
			copy/part dir t1
		]

		write-log "add-include-file: begin"
		write-log mold now/precise

		origin-file: ast/uri-to-file top/1/uri
		tfile: find/tail/last origin-file "/"
		origin-dir: copy/part origin-file tfile

		include-iter top/1/nested
		write-log "add-include-file: end"
		write-log mold now/precise
	]

	add-source*: function [uri [string!] code [string!]][
		if map? res: ast/analysis code [
			range: ast/to-range res/pos res/pos
			line-cs: charset [#"^M" #"^/"]
			info: res/error/arg2
			if part: find info line-cs [info: copy/part info part]
			message: rejoin [res/error/id " ^"" res/error/arg1 "^" at: ^"" info "^""]
			append diagnostics make map! reduce [
				'uri uri
				'diagnostics reduce [
					make map! reduce [
						'range range
						'severity 1
						'code 1
						'source "lexer"
						'message message
					]
				]
			]
			return diagnostics
		]

		add-source-to-table uri res
		add-include-file res
	]

	add-source: function [uri [string!] code [string!]][
		clear diagnostics
		clear file-block
		add-source* uri code
		diagnostics
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
		collect*: function [npc [block!] type [block!] /back?][
			until [
				if find type type?/word npc/1/expr/1 [
					nword: to word! npc/1/expr/1
					nstring: to string! nword
					if find/match nstring string [
						if unique? result nword [
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
			collect*/back? npc [set-word!]
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
					collect* spec [word! lit-word! refinement!]
				]
				npc2: par
				npc: tail par
			][break]
		]
	]

	collect-word: function [top [block!] pc [block!] result [block!]][
		sources: semantic/sources
		forall sources [
			either sources/1 = top [
				collect-word* pc to word! pc/1/expr/1 result
			][
				collect-word* tail sources/1/1/nested to word! pc/1/expr/1 result
			]
		]
	]

	next-context?: function [opc [block!] pc [block!] specs [block! none!] upper [logic!]][
		spec: none
		if all [
			pc/1
			pc/2
			any [
				all [
					find [context object] pc/1/expr/1
					block? pc/2/expr/1
					spec: pc/2
				]
				all [
					pc/1/expr/1 = 'make
					pc/3
					spec: pc/3
					any [
						pc/2/expr/1 = 'object!
						all [
							word? pc/2/expr/1
							pc/2/expr/1 <> to word! opc/1/expr/1
							find-set?/*context? next pc pc/2/expr/1 specs upper
						]
					]
				]
			]
		][
			if all [
				specs
				spec
				spec/nested
			][
				append/only specs spec/nested
			]
			return true
		]
		false
	]

	next-func?: function [pc [block!] specs [block! none!]][
		spec: none
		if all [
			pc/1
			pc/2
			find [func function has does] pc/1/expr/1
			block? pc/2/expr/1
			any [
				all [
					find [func function] pc/1/expr/1
					pc/3
					block? pc/3/expr/1
					spec: pc/2
				]
				pc/1/expr/1 = 'does
				all [
					pc/1/expr/1 = 'has
					pc/3
					block? pc/3/expr/1
				]
			]
		][
			if all [
				specs
				spec
				spec/nested
			][
				append/only specs spec/nested
			]
			return true
		]
		false
	]

	find-set?: function [pc* [block!] word [word!] specs [block! none!] upper [logic!] /*func? /*context? /*all?][
		find-set?*: function [pc [block!]][
			npc: pc
			until [
				if all [
					set-word? npc/1/expr/1
					word = to word! npc/1/expr/1
				][
					npc2: npc
					while [
						all [
							not tail? npc2: next npc2
							set-word? npc2/1/expr/1
						]
					][]
					unless tail? npc2 [
						if all [
							any [*context? *all?]
							next-context? npc npc2 specs upper
						][
							return 'context
						]
						if all [
							any [*func? *all?]
							next-func? npc2 specs
						][
							return 'func
						]
						if *all? [
							if specs [
								append/only specs npc2
							]
							return 'value
						]
					]
				]
				npc2: npc
				npc: back npc
				head? npc2
			]
			none
		]
		if ret: find-set?* pc* [
			return ret
		]
		npc: pc*
		if upper [
			while [
				all [
					par: npc/1/upper
					none? par/1/source
				]
			][
				npc: par
				if ret: find-set?* back tail npc [
					return ret
				]
			]
		]
		none
	]

	snippets: [
		"red.title.snippet"		"Red [ Title ]"					"Red [^/^-Title: ^"${2:title}^"^/]^/"
		"red.view.snippet"		"Red [ Title NeedsView ]"		"Red [^/^-Title: ^"${2:title}^"^/^-Needs: 'View^/]^/"
		"either.snippet"		"either condition [ ][ ]"		"either ${1:condition} [^/^-${2:exp}^/][^/^-${3:exp}^/]^/"
		"func.snippet"			"func [args][ ]"				"func [${1:arg}][^/^-${2:exp}^/]^/"
		"function.snippet"		"function [args][ ]"			"function [${1:arg}][^/^-${2:exp}^/]^/"
		"while.snippet"			"while [ condition ] [ ]"		"while [${1:condition}][^/^-${2:exp}^/]^/"
		"forall.snippet"		"forall series [ ]"				"forall ${1:series} [^/^-${2:exp}^/]^/"
		"foreach.snippet"		"foreach iteration series [ ]"	"foreach ${1:iteration} ${2:series} [^/^-${3:exp}^/]^/"
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
		complete-snippet: function [][
			if word? pc/1/expr/1 [
				len: (length? snippets) / 3
				repeat i len [
					if find/match snippets/(i * 3 - 2) string [
						append comps make map! reduce [
							'label snippets/(i * 3 - 2)
							'kind CompletionItemKind/Keyword
							'filterText? string
							'insertTextFormat 2
							'textEdit make map! reduce [
								'range range
								'newText snippets/(i * 3)
							]
							'data make map! reduce [
								'type "snippet"
								'index (i * 3 - 1)
							]
						]
					]
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
					switch ret: find-set?/*all? rpc to word! rpc/1/expr/1 none no [
						context		[kind: CompletionItemKind/Struct]
						func		[kind: CompletionItemKind/Function]
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
		complete-snippet
	]

	collect-func-refinement*: function [specs [block!] result [block!]][
		forall specs [
			npc: specs/1
			forall npc [
				if refinement? npc/1/expr/1 [
					if npc/1/expr = [/local] [break]
					if unique? result to word! npc/1/expr/1 [
						append/only result npc
					]
				]
			]
		]
	]
	collect-context-set-word*: function [specs [block!] result [block!]][
		forall specs [
			npc: back tail specs/1
			until [
				if all [
					set-word? npc/1/expr/1
					unique? result to word! npc/1/expr/1
				][
					append/only result npc
				]
				npc2: npc
				npc: back npc
				head? npc2
			]
		]
	]

	collect-slash-context*: function [pc [block!] word [word!] result [block!] slash-end? [logic!]][
		string: to string! word
		collect*: function [npc [block!]][
			until [
				if all [
					not slash-end?
					set-word? npc/1/expr/1
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
					specs: clear []
					switch find-set?/*func?/*context? npc word specs false [
						context [
							collect-context-set-word* specs result
							break
						]
						func [
							collect-func-refinement* specs result
							break
						]
					]
				]
				npc2: npc
				npc: back npc
				head? npc2
			]
		]
		collect* back tail pc
	]

	collect-slash-func*: function [pc [block!] word [word!] result [block!] slash-end? [logic!]][
		string: to string! word
		collect*: function [npc [block!]][
			forall npc [
				if all [
					refinement? npc/1/expr/1
					any [
						slash-end?
						find/match to string! npc/1/expr/1 string
					]
				][
					if npc/1/expr = [/local][break]
					if unique? result to word! npc/1/expr/1 [
						append/only result npc
					]
				]
			]
		]
		collect* pc
	]

	collect-path*: function [pc [block!] path [path!] result [block!]][
		slash-end?: no
		if '`*?~+-= = last path [
			remove back tail path
			slash-end?: yes
		]

		specs: make block! 16
		unless type: find-set?/*func?/*context? pc path/1 specs true [
			exit
		]
		unless path/2 [
			switch type [
				context		[collect-context-set-word* specs result]
				func		[collect-func-refinement* specs result]
			]
			exit
		]
		path: next path
		until [
			tops: specs
			slash?: slash-end?
			unless tail? next path [
				slash?: yes
			]
			forall tops [
				either any [
					type = 'func
					all [
						par: tops/1/1/upper
						find [func function] par/-1/expr/1
					]
				][
					collect-slash-func* tops/1 path/1 nspecs: make block! 4 slash?
					unless path/2 [
						append result nspecs
					]
				][
					collect-slash-context* tops/1 path/1 specs: make block! 4 slash?
					unless path/2 [
						append result specs
					]
				]
			]
			tail? path: next path
		]
	]

	collect-path: function [top [block!] pc [block!] result [block!]][
		sources: semantic/sources
		forall sources [
			either sources/1 = top [
				collect-path* pc to path! pc/1/expr/1 result
			][
				collect-path* back tail sources/1/1/nested to path! pc/1/expr/1 result
			]
		]
	]

	complete-path: function [top [block!] pc [block!] comps [block!]][
		complete-sys-path: function [][
			words: system-words/system-words
			cstr: to string! path
			if slash-end? [
				append cstr "/"
			]
			tstr: find/tail/last cstr "/"
			tstr: copy/part cstr tstr
			unless find words fword [exit]
			if error? result: try [red-complete-ctx/red-complete-path cstr no][
				exit
			]
			forall result [
				unless nstring: find/tail/last result/1 "/" [
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
						'path append copy tstr nstring
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
		unless top: semantic/find-top uri [return none]
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
		if all [
			set-word? pc/1/expr/1
			pc/2
		][
			specs: clear []
			switch ret: find-set?/*all? pc to word! pc/1/expr/1 specs no [
				context		[return rejoin [string " is a context!"]]
				func		[
					if all [
						not empty? specs
						upper: specs/1/1/upper
						upper/-1
						word? upper/-1/expr/1
					][
						return func-info upper/-1/expr/1 upper/1/expr/1 to string! pc/1/expr/1
					]
					return func-info 'func [] to string! pc/1/expr/1
				]
				value		[
					if word? expr: specs/1/1/expr/1 [
						return rejoin [string ": " mold expr]
					]
					return rejoin [string " is a " mold type?/word expr " variable."]
				]
			]
		]
		if all [
			upper: pc/1/upper
			upper/-1
			find [func function has] upper/-1/expr/1
		][
			if refinement? pc/1/expr/1 [
				return rejoin [string " is a function refinement!"]
			]
			ret: rejoin [string " is a function argument!"]
			if all [
				pc/2
				block? pc/2/expr/1
			][
				return rejoin [ret "^/type: " mold pc/2/expr/1]
			]
			return ret
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
			params/data/type = "snippet"
			index: params/data/index
		][
			return snippets/:index
		]
		if all [
			params/data
			params/data/type = "system-path"
			params/data/path
		][
			path: load params/data/path
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
			unless top: semantic/find-top uri [return none]
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
