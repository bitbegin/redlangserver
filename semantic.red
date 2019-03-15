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
	diagnostics: []
	write-log: :probe

	find-expr: function [top [block!] range [block!]][
		find-expr*: function [pc [block!]][
			forall pc [
				if pc/1/range = range [
					return pc
				]
				if pc/1/nested [
					if ret: find-expr* pc/1/nested [return ret]
				]
			]
			none
		]
		find-expr* top
	]

	position?: function [top [block!] line [integer!] column [integer!]][
		position?*: function [pc [block!]][
			forall pc [
				if any [
					pc/1/range/1 > line
					all [
						pc/1/range/1 = line
						pc/1/range/2 > column
					]
				][
					return reduce ['head pc]
				]
				if any [
					pc/1/range/3 < line
					all [
						pc/1/range/3 = line
						pc/1/range/4 < column
					]
				][
					if pc = top [
						if pc/1/nested [
							return position?* pc/1/nested
						]
						return reduce ['top-err pc]
					]
					unless pc/2 [
						return reduce ['tail pc]
					]
					if any [
						pc/2/range/1 > line
						all [
							pc/2/range/1 = line
							pc/2/range/2 > column
						]
					][
						return reduce ['insert pc]
					]
				]
				if all [
					any [
						pc/1/range/1 < line
						all [
							pc/1/range/1 = line
							pc/1/range/2 <= column
						]
					]
					any [
						pc/1/range/3 > line
						all [
							pc/1/range/3 = line
							pc/1/range/4 >= column
						]
					]
				][
					if all [
						pc/1/range/1 = line
						pc/1/range/2 = column
						pc <> top
					][
						return reduce ['first pc]
					]
					if all [
						pc/1/range/3 = line
						pc/1/range/4 = column
					][
						if pc = top [
							if pc/1/nested [
								return position?* pc/1/nested
							]
							return reduce ['top-err pc]
						]
						unless pc/2 [
							return reduce ['last pc]
						]
						if all [
							pc/2/range/1 = line
							pc/2/range/2 = column
						][
							return reduce ['mid pc]
						]
						return reduce ['last pc]
					]
					unless pc/1/nested [
						if find reduce [block! map! paren!] pc/1/expr/1 [
							return reduce ['empty pc]
						]
						return reduce ['one pc]
					]
					return position?* pc/1/nested
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

	format: function [top [block!] /semantic][
		buffer: make string! 1000
		newline: function [cnt [integer!]] [
			append buffer lf
			append/dup buffer " " cnt
		]

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
				newline pad + 4
				append buffer "range: "
				append buffer mold/flat pc/1/range
				if pc/1/nested [
					newline pad + 4
					append buffer "nested: "
					format* pc/1/nested depth + 1
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

	collect-errors: function [top [block!]][
		ret: make block! 4
		collect-errors*: function [pc [block!]][
			forall pc [
				if errors: pc/1/error [
					forall errors [
						if all [
							pc/1/expr/1 = path!
							pc/2
							pc/2/expr/1 = paren!
						][continue]
						append ret make map! reduce [
							'severity DiagnosticSeverity/(errors/1/level)
							'code mold errors/1/type
							'source "Syntax"
							'message errors/1/msg
							'range lexer/form-range pc/1/range ;-- TBD: calc error position reduce [pc/1/range/1 pc/1/range/2 errors/1/at/1 errors/1/at/2]
						]
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

	related-file: function [dir [file!] file [file!]][
		dir-back: function [dir* [file!]][
			dir: copy dir*
			if #"/" <> last dir [return none]
			remove back tail dir
			unless t1: find/last/tail dir "/" [
				return none
			]
			copy/part dir t1
		]
		if #"/" = last file [
			return none
		]
		if #"/" = first file [
			return file
		]
		dir: copy dir
		unless find file "/" [
			append dir file
			return dir
		]
		nfile: file
		forever [
			unless t1: find/tail nfile "/" [
				append dir nfile
				return dir
			]
			t2: copy/part nfile t1
			case [
				t2 = %../ [
					unless dir: dir-back dir [
						return none
					]
				]
				t2 = %./ []
				true [
					append dir t2
				]
			]
			nfile: t1
		]
		none
	]

	add-include-file: function [top [block!]][
		include-file: function [file [file!]][
			if all [
				exists? file
				code: read file
			][
				uri: lexer/file-to-uri file
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
				if nfile: related-file origin-dir file [
					include-file nfile
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

		origin-file: lexer/uri-to-file top/1/uri
		tfile: find/tail/last origin-file "/"
		origin-dir: copy/part origin-file tfile

		if top/1/nested [
			include-iter top/1/nested
		]
	]

	add-source*: function [uri [string!] code [string!]][
		top: lexer/transcode code
		unless empty? errors: collect-errors top [
			append diagnostics make map! reduce [
				'uri uri
				'diagnostics errors
			]
		]
		add-source-to-table uri top
		add-include-file top
	]

	add-source: function [uri [string!] code [string!]][
		clear diagnostics
		add-source* uri code
		diagnostics
	]

	new-lines?: function [text [string!]][
		ntext: text
		n: 0
		while [ntext: find/tail ntext "^/"][
			n: n + 1
		]
		n
	]

	update-ws: function [
			pcs [block!] s-line [integer!] s-column [integer!] e-line [integer!]
			e-column [integer!] text [string!] line-stack [block!] forward? [logic!]
	][
		update-pc: function [npc* [block!] lines [integer!] end-chars [integer!]][
			;-- head [tail next] [insert next] [last next] [mid next][empty] [one next, before]
			update*: function [npc [block!] first* [logic!]][
				if first* [
					npc/1/range/1: npc/1/range/1 + lines
					if npc/1/range/1 = s-line [
						npc/1/range/2: npc/1/range/2 - s-column + end-chars + 1
					]
				]
				npc/1/range/3: npc/1/range/3 + lines
				if npc/1/range/3 = s-line [
					npc/1/range/4: npc/1/range/4 - s-column + end-chars + 1
				]
			]
			update*-sub: function [npc [block!] first* [logic!]][
				if first* [
					npc/1/range/1: npc/1/range/1 - lines
					if npc/1/range/1 = e-line [
						npc/1/range/2: npc/1/range/2 - e-column + s-column
					]
				]
				npc/1/range/3: npc/1/range/3 - lines
				if npc/1/range/3 = s-line [
					npc/1/range/4: npc/1/range/4 - e-column + s-column
				]
			]
			update-pc-nested: function [npc [block!] first* [logic!]][
				forall npc [
					either forward? [
						update*-sub npc first*
					][
						update* npc first*
					]
					if npc/1/nested [
						update-pc-nested npc/1/nested first*
					]
				]
			]
			update-pc-nested npc* yes
			either tail? npc* [
				par: back npc*
			][
				par: npc*
			]
			while [par: par/1/upper][
				either forward? [
					update*-sub par no
				][
					update* par no
				]
				update-pc-nested next par no
			]
		]
		write-log "update-ws"
		lines: new-lines? text
		either lines = 0 [
			end-chars: length? text
		][
			end-chars: length? find/last/tail text "^/"
		]
		pc: pcs/2
		switch/default pcs/1 [
			head empty		[]
			tail insert last mid one [
				pc: next pc
			]
		][exit]
		either pcs/1 = 'one [
			update-pc next pc lines end-chars
		][
			update-pc pc lines end-chars
		]
		if pcs/1 = 'one [
			npc: pcs/2
			either forward? [
				npc/1/range/3: npc/1/range/3 - lines
				if npc/1/range/3 = e-line [
					npc/1/range/4: npc/1/range/4 - e-column + s-column
				]
			][
				npc/1/range/3: npc/1/range/3 + lines
				if npc/1/range/3 = s-line [
					npc/1/range/4: npc/1/range/4 - s-column + end-chars + 1
				]
			]
			spos: lexer/line-pos? line-stack npc/1/range/1 npc/1/range/2
			epos: lexer/line-pos? line-stack npc/1/range/3 npc/1/range/4
			str: copy/part spos epos
			if any [
				not top: lexer/transcode str
				none? nested: top/1/nested
				1 < length? nested
			][
				return false
			]
			pc/1/expr: nested/1/expr
			either pc/1/error [
				pc/1/error: nested/1/error
			][
				repend pc/1 ['error nested/1/error]
			]
		]
		true
	]

	update-one: function [
			pcs [block!] s-line [integer!] s-column [integer!] e-line [integer!]
			e-column [integer!] end-chars [integer!] line-stack [block!]
	][
		update-pc: function [npc* [block!] end-chars [integer!]][
			;-- head [tail next] [insert next] [last next] [mid next][empty] [one next, before]
			update*: function [npc [block!] first* [logic!]][
				if first* [
					if npc/1/range/1 = s-line [
						npc/1/range/2: npc/1/range/2 + end-chars
					]
				]
				if npc/1/range/3 = s-line [
					npc/1/range/4: npc/1/range/4 + end-chars
				]
			]
			update-pc-nested: function [npc [block!] first* [logic!]][
				forall npc [
					update* npc first*
					if npc/1/nested [
						update-pc-nested npc/1/nested first*
					]
				]
			]
			update-pc-nested npc* yes
			either tail? npc* [
				par: back npc*
			][
				par: npc*
			]
			while [par: par/1/upper][
				update* par no
				update-pc-nested next par no
			]
		]
		write-log "update-one"
		pc: pcs/2
		update-pc next pc end-chars
		if pc/1/range/3 = s-line [
			pc/1/range/4: pc/1/range/4 + end-chars
		]
		spos: lexer/line-pos? line-stack pc/1/range/1 pc/1/range/2
		epos: lexer/line-pos? line-stack pc/1/range/3 pc/1/range/4
		if empty? str: copy/part spos epos [
			remove pc
			write-log "update-one: remove"
			return true
		]
		write-log mold pc/1/range
		write-log mold str
		if any [
			not top: lexer/transcode str
			none? nested: top/1/nested
			1 < length? nested
		][
			return false
		]
		pc/1/expr: nested/1/expr
		either pc/1/error [
			pc/1/error: nested/1/error
		][
			repend pc/1 ['error nested/1/error]
		]
		true
	]

	ws: charset " ^M^/^-"
	update-source: function [uri [string!] changes [block!]][
		clear diagnostics
		not-trigger-charset: complement charset "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/%.+-_=?*&~?`"
		;write-log mold changes
		unless ss: find-source uri [
			return false
		]
		write %f-log1.txt ss/1/1/source
		write/append %f-log1.txt "^/"
		write/append %f-log1.txt format ss/1
		;write-log format ss/1
		code: ss/1/1/source
		ncode: code
		line-stack: ss/1/1/lines
		forall changes [
			range: changes/1/range
			text: changes/1/text
			rangeLength: changes/1/rangeLength
			s-line: range/start/line + 1
			s-column: range/start/character + 1
			e-line: range/end/line + 1
			e-column: range/end/character + 1
			spos: lexer/line-pos? line-stack s-line s-column
			epos: lexer/line-pos? line-stack e-line e-column
			otext: copy/part spos epos
			code2: copy/part ncode spos
			append code2 text
			append code2 epos
			line-stack: make block! 1000
			lexer/parse-line line-stack code2
			ss/1/1/source: code2
			ss/1/1/lines: line-stack
			otext-ws?: parse otext [some ws]
			text-ws?: parse text [some ws]
			if ss/1/1/nested [
				spcs: epcs: position? ss/1 s-line s-column
				if all [
					s-line <> e-line
					s-column <> e-column
				][
					epcs: position? ss/1 e-line e-column
				]
				if any [
					none? spcs
					none? epcs
				][
					write-log "add-source 1"
					add-source* uri code2
					ncode: code2
					continue
				]
				pc: spcs/2
				epc: epcs/2
				;-- insert spaces in spaces or string!
				if all [
					any [
						epcs/1 <> 'one
						string? epc/1/expr/1
					]
					all [
						any [
							empty? text
							text-ws?
						]
						any [
							empty? otext
							otext-ws?
						]
					]
				][
					unless empty? text [
						unless update-ws epcs s-line s-column e-line e-column text line-stack no [
							write-log "add-source 2"
							add-source* ss/1/1/uri code2
						]
					]
					unless empty? otext [
						unless update-ws epcs s-line s-column e-line e-column otext line-stack yes [
							write-log "add-source 3"
							add-source* ss/1/1/uri code2
						]
					]
					ncode: code2
					continue
				]
				;-- token internal
				if all [
					any [
						all [
							find [first last one] spcs/1
							find [first last one] epcs/1
							spcs/2 = epcs/2
							not find reduce [block! map! paren!] pc/1/expr/1
						]
						all [
							spcs/1 = 'mid
							find [last one mid] epcs/1
							epcs/2 = next spcs/2
							not find reduce [block! map! paren!] epc/1/expr/1
						]
						all [
							epcs/1 = 'mid
							find [last one] spcs/1
							epcs/2 = next spcs/2
							not find reduce [block! map! paren!] epc/1/expr/1
						]
					]
					any [
						empty? text
						not find not-trigger-charset text
					]
					any [
						empty? otext
						not find not-trigger-charset otext
					]
				][
					unless update-one epcs s-line s-column e-line e-column (length? text) - (length? otext) line-stack [
						write-log "add-source 4"
						add-source* ss/1/1/uri code2
					]
					ncode: code2
					continue
				]
				;-- insert a new token
				if all [
					spcs = epcs
					empty? otext
					not find not-trigger-charset text
				][
					if any [
						spcs/1 = 'head
						all [
							spcs/1 = 'tail
							(pc: next pc true)
						]
						spcs/1 = 'insert
						all [
							spcs/1 = 'first
							find reduce [block! paren!] pc/1/expr/1
						]
						all [
							spcs/1 = 'last
							find reduce [block! paren!] pc/1/expr/1
							(pc: next pc true)
						]
						all [
							spcs/1 = 'mid
							find reduce [block! paren!] pc/1/expr/1
							pc: next pc
							find reduce [block! paren!] pc/1/expr/1
						]
					][
						range: reduce [s-line s-column e-line e-column + length? text]
						write-log "insert pc: "
						write-log mold range
						if any [
							not top: lexer/transcode text
							none? nested: top/1/nested
							1 < length? nested
						][
							write-log "update-insert: add-source"
							add-source* uri code2
							ncode: code2
							continue
						]
						insert/only pc reduce ['expr nested/1/expr 'range range 'upper epc/1/upper 'error nested/1/error]
						ncode: code2
						continue
					]
				]
			]
			write-log "add-source end"
			add-source* uri code2
			ncode: code2
		]
		write %f-log2.txt ss/1/1/source
		write/append %f-log2.txt "^/"
		write/append %f-log2.txt format ss/1
		unless empty? errors: collect-errors ss/1 [
			append diagnostics make map! reduce [
				'uri ss/1/1/uri
				'diagnostics errors
			]
		]
		diagnostics
	]
]

completion: context [
	last-comps: clear []

	complete-file: function [top [block!] pc [block!] comps [block!]][
		range: lexer/form-range pc/1/range
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

	collect-word*: function [pc [block!] word [word!] result [block!] /match][
		string: to string! word
		collect*: function [npc [block!] type [block!] /back?][
			if empty? npc [
				either back? [npc: back npc][exit]
			]
			until [
				if find type type?/word npc/1/expr/1 [
					nword: to word! npc/1/expr/1
					nstring: to string! nword
					either match [
						if all [
							nstring = string
							unique? result nword
						][
							append/only result npc
						]
					][
						if all [
							find/match nstring string
							unique? result nword
						][
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
			either all [
				not tail? npc2
				par: npc2/1/upper
				none? par/1/source
			][
				if all [
					par/-1
					block! = par/-1/expr/1
					spec: par/-1/nested
					par/-2
					find [func function has] par/-2/expr/1
				][
					collect* spec [word! lit-word! refinement!]
				]
				npc2: par
				collect*/back? npc [set-word!]
				collect* npc [set-word!]
				npc: tail par
			][
				collect*/back? npc [set-word!]
				collect* npc [set-word!]
				break
			]
		]
	]

	collect-word: function [top [block!] pc [block!] result [block!]][
		word: to word! pc/1/expr/1
		sources: semantic/sources
		forall sources [
			either sources/1 = top [
				collect-word* pc word result
			][
				collect-word* back tail sources/1/1/nested word result
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
					block! = pc/2/expr/1
					spec: pc/2
				]
				all [
					pc/1/expr/1 = 'make
					pc/3
					block! = pc/3/expr/1
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
			block! = pc/2/expr/1
			any [
				all [
					find [func function] pc/1/expr/1
					pc/3
					block! = pc/3/expr/1
					spec: pc/2
				]
				pc/1/expr/1 = 'does
				all [
					pc/1/expr/1 = 'has
					pc/3
					block! = pc/3/expr/1
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
		check-set?: function [npc [block!]][
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
		]
		find-set?*: function [pc [block!]][
			npc: pc
			until [
				if ret: check-set? npc [return ret]
				npc2: npc
				npc: back npc
				head? npc2
			]
			npc: next pc
			forall npc [
				if ret: check-set? npc [return ret]
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
		range: lexer/form-range pc/1/range
		if any [
			lit-word? pc/1/expr/1
			get-word? pc/1/expr/1
		][
			range/start/character: range/start/character + 1
		]
		if empty? string: to string! to word! pc/1/expr/1 [
			exit
		]
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
					'range rpc/1/range
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

	collect-slash-context*: function [pc [block!] word [word!] result [block!] slash-end? [logic!] match? [logic!]][
		string: to string! word
		collect*: function [npc [block!]][
			until [
				if all [
					not slash-end?
					set-word? npc/1/expr/1
					any [
						all [
							not match?
							find/match to string! npc/1/expr/1 string
						]
						string = to string! npc/1/expr/1
					]
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
					if find-set?/*func?/*context? npc word result false [
						break
					]
				]
				npc2: npc
				npc: back npc
				head? npc2
			]
		]
		collect* back tail pc
	]

	collect-slash-func*: function [pc [block!] word [word!] result [block!] slash-end? [logic!] match? [logic!]][
		string: to string! word
		collect*: function [npc [block!]][
			forall npc [
				if all [
					refinement? npc/1/expr/1
					any [
						slash-end?
						all [
							not match?
							find/match to string! npc/1/expr/1 string
						]
						string = to string! npc/1/expr/1
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

	collect-path*: function [pc [block!] path [block!] result [block!] match? [logic!]][
		specs: make block! 16
		unless type: find-set?/*func?/*context? pc to word! path/1 specs true [
			exit
		]
		if empty? path/2 [
			switch type [
				context		[collect-context-set-word* specs result]
				func		[collect-func-refinement* specs result]
			]
			exit
		]
		path: next path
		until [
			tops: specs
			either path/2 [
				slash?: yes
			][
				slash?: no
			]
			forall tops [
				either any [
					type = 'func
					all [
						par: tops/1/1/upper
						find [func function] par/-1/expr/1
					]
				][
					collect-slash-func* tops/1 to word! path/1 nspecs: make block! 4 slash? match?
					if any [
						none? path/2
						empty? path/2
					][
						append result nspecs
					]
				][
					collect-slash-context* tops/1 to word! path/1 specs: make block! 4 slash? match?
					if any [
						none? path/2
						empty? path/2
					][
						append result specs
					]
				]
			]
			any [
				tail? path: next path
				empty? path/1
			]
		]
	]

	collect-path: function [top [block!] pc [block!] path [block!] result [block!] match? [logic!]][
		collect-path* pc path result match?
		if 0 < length? result [exit]
		sources: semantic/sources
		forall sources [
			if sources/1 <> top [
				collect-path* back tail sources/1/1/nested path result match?
				if 0 < length? result [exit]
			]
		]
	]

	complete-path: function [top [block!] pc [block!] comps [block!]][
		complete-sys-path: function [][
			tstr: find/tail/last pure-path "/"
			tstr: copy/part pure-path tstr
			unless system-words/system? fword [exit]
			if error? result: try [red-complete-ctx/red-complete-path pure-path no][
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
		spos: lexer/line-pos? top/1/lines pc/1/range/1 pc/1/range/2
		epos: lexer/line-pos? top/1/lines pc/1/range/3 pc/1/range/4
		path-str: copy/part spos epos
		paths: split path-str "/"
		fword: to word! paths/1
		filter: last paths
		pure-path: path-str
		if any [
			pure-path/1 = #"'"
			pure-path/1 = #":"
		][
			pure-path: next pure-path
		]
		slash-end?: no
		if empty? filter [
			slash-end?: yes
		]
		range: lexer/form-range pc/1/range
		either slash-end? [
			range/start/character: range/end/character
		][
			range/start/character: range/end/character - length? filter
		]
		pcs: clear []
		collect-path top pc paths pcs no
		forall pcs [
			rpc: pcs/1
			ntop: rpc
			while [par: ntop/1/upper][ntop: par]
			nstring: to string! rpc/1/expr/1
			kind: CompletionItemKind/Variable
			type: type?/word rpc/1/expr/1
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
				'label nstring
				'kind kind
				'filterText? filter
				'insertTextFormat 1
				'preselect true
				'textEdit make map! reduce [
					'range range
					'newText nstring
				]
				'data make map! reduce [
					'uri ntop/1/uri
					'range rpc/1/range
					'type "path"
				]
			]
		]
		complete-sys-path
	]

	complete: function [uri [string!] line [integer!] column [integer!]][
		unless top: semantic/find-top uri [return none]
		unless pcs: semantic/position? top line column [
			return none
		]
		pc: pcs/2
		switch/default pcs/1 [
			one		[]
			last	[]
			mid		[
				type: type?/word pc/1/expr/1
				lstr: pick lexer/line-pos? top/1/lines pc/1/range/3 pc/1/range/4 - 1 1
				unless any [
					find [word! lit-word! get-word! path! lit-path! get-path! file!] type
					all [
						any [
							pc/1/expr/1 = path!
							pc/1/expr/1 = lit-path!
							pc/1/expr/1 = get-path!
						]
						#"/" = lstr
					]
				][
					pc: next pc
				]
			]
		][return none]
		type: type?/word pc/1/expr/1
		lstr: pick lexer/line-pos? top/1/lines pc/1/range/3 pc/1/range/4 - 1 1
		unless any [
			find [word! lit-word! get-word! path! lit-path! get-path! file!] type
			all [
				any [
					pc/1/expr/1 = path!
					pc/1/expr/1 = lit-path!
					pc/1/expr/1 = get-path!
				]
				#"/" = lstr
			]
		][
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
		if any [
			find [path! lit-path! get-path!] type
			all [
				any [
					pc/1/expr/1 = path!
					pc/1/expr/1 = lit-path!
					pc/1/expr/1 = get-path!
				]
				#"/" = lstr
			]
		][
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

	get-block: function [pc [block!]][
		ret: make block! 4
		forall pc [
			if find reduce [block! map! paren!] pc/1/expr/1 [
				append/only ret make pc/1/expr/1
					either pc/1/nested [
						get-block pc/1/nested
					][[]]
				continue
			]
			append ret pc/1/expr/1
		]
		ret
	]

	get-func-spec: function [pc [block!]][
		ret: get-block pc
		until [
			if all [
				reduce [ret/1] = [return:]
				ret/2
				block? ret/2
				ret/3
				string? ret/3
			][
				remove ret: skip ret 2
				break
			]
			tail? ret: next ret
		]
		ret
	]

	get-top: function [pc [block!]][
		while [par: pc/1/upper][
			pc: par
		]
		pc
	]

	resolve-word: function [pc [block!] string [string!]][
		top: get-top pc
		resolve-word*: function [][
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
							return func-info upper/-1/expr/1 get-func-spec upper/1/nested to string! pc/1/expr/1
						]
						return func-info 'func [] to string! pc/1/expr/1
					]
					value		[
						if word? expr: specs/1/1/expr/1 [
							return rejoin [string ": " mold expr]
						]
						if datatype? expr [
							return rejoin [string " is a " mold expr " variable."]
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
					block! = pc/2/expr/1
					pc/2/nested
				][
					return rejoin [ret "^/type: " mold get-block pc/2/nested]
				]
				return ret
			]
			none
		]
		if str: resolve-word* [
			append str rejoin ["^/^/FILE: " mold lexer/uri-to-file top/1/uri]
		]
		str
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
			range: params/data/range
			unless top: semantic/find-top uri [return none]
			unless pc: semantic/find-expr top range [
				return none
			]
			return resolve-word pc params/label
		]
		none
	]

	hover-word*: function [top [block!] pc [block!] result [block!]][
		word: to word! pc/1/expr/1
		collect-word*/match pc word result
		if 0 < length? result [exit]
		sources: semantic/sources
		forall sources [
			if sources/1 <> top [
				collect-word*/match back tail sources/1/1/nested word result
				if 0 < length? result [exit]
			]
		]
	]

	hover-word: function [top [block!] pc [block!]][
		result: make block! 4
		hover-word* top pc result
		if 0 = length? result [return none]
		forall result [
			unless set-word? result/1/1/expr/1 [
				pc: result/1
				top: get-top pc
				return resolve-word pc to string! pc/1/expr/1
			]
		]
		pc: result/1
		top: get-top pc
		resolve-word pc to string! pc/1/expr/1
	]

	hover-path: function [top [block!] pc [block!]][
		path: to string! pc/1/expr/1
		paths: split path "/"
		result: make block! 4
		collect-path top pc paths result yes
		if 0 = length? result [return none]
		pc: result/1
		top: get-top pc
		resolve-word pc to string! pc/1/expr/1
	]

	hover: function [uri [string!] line [integer!] column [integer!]][
		unless top: semantic/find-top uri [return none]
		unless pcs: semantic/position? top line column [
			return none
		]
		pc: pcs/2
		switch/default pcs/1 [
			one		[]
			first	[]
			last	[]
			mid		[
				type: type?/word pc/1/expr/1
				unless find [word! lit-word! get-word! set-word! path! lit-path! get-path! set-path! file!] type [
					pc: next pc
				]
			]
		][return none]
		type: type?/word pc/1/expr/1
		unless find [word! lit-word! get-word! set-word! path! lit-path! get-path! set-path!] type [
			return none
		]
		either any-path? expr: pc/1/expr/1 [
			word: expr/1
			if ret: hover-path top pc [return ret]
		][
			word: to word! expr
			if ret: hover-word top pc [return ret]
		]
		if system-words/system? word [
			if all[
				any-word? expr
				datatype? get word
			][
				return rejoin [mold word " is a base datatype!"]
			]
			return system-words/get-word-info word
		]
		none
	]

	definition-word: function [top [block!] pc [block!]][
		result: make block! 4
		hover-word* top pc result
		if 0 = length? result [return none]
		ret: make block! 4
		forall result [
			top: get-top pc: result/1
			append ret make map! reduce [
				'uri top/1/uri
				'range lexer/form-range pc/1/range
			]
		]
		ret
	]

	definition-path: function [top [block!] pc [block!]][
		path: to string! pc/1/expr/1
		paths: split path "/"
		result: make block! 4
		collect-path top pc paths result yes
		if 0 = length? result [return none]
		ret: make block! 4
		forall result [
			top: get-top pc: result/1
			append ret make map! reduce [
				'uri top/1/uri
				'range lexer/form-range pc/1/range
			]
		]
		ret
	]

	definition: function [uri [string!] line [integer!] column [integer!]][
		unless top: semantic/find-top uri [return none]
		unless pcs: semantic/position? top line column [
			return none
		]
		pc: pcs/2
		switch/default pcs/1 [
			one		[]
			first	[]
			last	[]
			mid		[
				type: type?/word pc/1/expr/1
				unless find [word! lit-word! get-word! set-word! path! lit-path! get-path! set-path! file!] type [
					pc: next pc
				]
			]
		][return none]
		type: type?/word pc/1/expr/1
		unless find [word! lit-word! get-word! set-word! path! lit-path! get-path! set-path!] type [
			return none
		]
		either any-path? expr: pc/1/expr/1 [
			return definition-path top pc
		][
			return definition-word top pc
		]
	]
]
