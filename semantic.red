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
	excluded-folders: []
	root-folders: []

	read-file: func [
		file	[file!]
		return:	[string!]
	][
		if error? ret: try [to string! read/binary file][
			ret: ""
		]
		ret
	]

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

	;-- IMPORTANT NOTE: token's range/y = last-char-pos + 1
	position?: function [top [block!] line [integer!] column [integer!]][
		position?*: function [pc [block!]][
			forall pc [
				if any [
					pc/1/range/1/x > line
					all [
						pc/1/range/1/x = line
						pc/1/range/1/y > column
					]
				][
					;--  "   token"
					;--    ^
					return reduce ['head pc]
				]
				if any [
					pc/1/range/2/x < line
					all [
						pc/1/range/2/x = line
						pc/1/range/2/y < column
					]
				][
					if pc = top [
						if pc/1/nested [
							return position?* pc/1/nested
						]
						return reduce ['top-err pc]
					]
					unless pc/2 [
						;-- "token   "
						;--        ^
						return reduce ['tail pc]
					]
					if any [
						pc/2/range/1/x > line
						all [
							pc/2/range/1/x = line
							pc/2/range/1/y > column
						]
					][
						;-- "token   token"
						;--        ^
						return reduce ['insert pc]
					]
				]
				if all [
					any [
						pc/1/range/1/x < line
						all [
							pc/1/range/1/x = line
							pc/1/range/1/y <= column
						]
					]
					any [
						pc/1/range/2/x > line
						all [
							pc/1/range/2/x = line
							pc/1/range/2/y >= column
						]
					]
				][
					in-path?: no
					type: none
					if pc/1/type [
						in-path?: find [path! lit-path! get-path! set-path!] type: to word! pc/1/type
					]
					if all [
						pc/1/range/1/x = line
						pc/1/range/1/y = column
						pc <> top
						not in-path?
					][
						;-- "   token"
						;--     ^
						return reduce ['first pc]
					]
					if all [
						pc/1/range/2/x = line
						pc/1/range/2/y = column
						not in-path?
					][
						if pc = top [
							if pc/1/nested [
								return position?* pc/1/nested
							]
							return reduce ['top-err pc]
						]
						unless pc/2 [
							;-- "token   "
							;--      ^
							return reduce ['last pc]
						]
						if all [
							pc/2/range/1/x = line
							pc/2/range/1/y = column
						][
							;-- word[]
							;--     ^
							return reduce ['mid pc]
						]
						;-- "token   "
						;--      ^
						return reduce ['last pc]
					]
					unless pc/1/nested [
						if find [block! map! paren!] type [
							;-- "[]"
							;--   ^
							return reduce ['empty pc]
						]
						;-- "token"
						;--   ^
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
			if any [
				uri = nuri: ss/1/1/uri
				(lexer/uri-to-file uri) = (lexer/uri-to-file nuri)
			][
				return ss/1
			]
		]
		false
	]

	find-source: function [uri [string!]][
		ss: sources
		forall ss [
			if any [
				uri = nuri: ss/1/1/uri
				(lexer/uri-to-file uri) = (lexer/uri-to-file nuri)
			][
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

	collect-errors: function [top [block!]][
		ret: make block! 4
		collect-errors*: function [pc [block!]][
			while [not tail? pc] [
				if error: pc/1/error [
					msg: either block? error [error/code][error]
					range: reduce [pc/1/range/1 pc/1/range/1]
					append ret make map! reduce [
						'severity 1							;-- DiagnosticSeverity/Error
						'code mold pc/1/type
						'source "Syntax"
						'message mold msg
						'range lexer/form-range range		;-- TBD: calc error position reduce [pc/1/range/1 pc/1/range/2 errors/1/at/1 errors/1/at/2]
					]
				]
				if nested: pc/1/nested [
					collect-errors* nested
				]
				pc: next pc
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
				code: read-file file
			][
				uri: lexer/file-to-uri file
				write-log rejoin ["include: " uri]
				add-source* uri code
			]
		]

		include-each: function [pc [block!]][
			if all [
				issue! = pc/1/type
				"include" = to string! pc/1/expr
				pc/2
				file! = pc/2/type
				file: pc/2/expr
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

	update-diags: func [
		top			[block!]
		uri			[string!]
		/local errors diags f nuri
	][
		unless top [exit]
		if empty? errors: collect-errors top [exit]
		diags: diagnostics
		f: none
		forall diags [
			if any [
				uri = nuri: diags/1/uri
				(lexer/uri-to-file uri) = (lexer/uri-to-file nuri)
			][
				f: diags/1
				break
			]
		]
		either f [
			f/diagnostics: errors
		][
			append diagnostics make map! reduce [
				'uri uri
				'diagnostics errors
			]
		]
	]

	add-source*: function [uri [string!] code [string!]][
		either any [
			not top: find-top uri
			top/1/source <> code
		][
			write-log rejoin ["parse uri: " uri]
			top: lexer/transcode code
			update-diags top uri
			add-source-to-table uri top
			add-include-file top
		][
			update-diags top uri
		]
	]

	add-source: function [uri [string!] code [string!]][
		clear diagnostics
		write-log rejoin ["add source: " uri]
		add-source* uri code
		diagnostics
	]

	add-folder*: function [folder [file!]][
		if error? files: try [read folder][exit]
		forall files [
			if all [
				dir? file: rejoin [folder files/1]
				not find excluded-folders file
			][
				add-folder* file
				continue
			]
			ext: find/last file "."
			if any [
				%.red = ext
				;%.reds = ext
			][
				add-source* lexer/file-to-uri file read-file file
			]
		]
	]

	add-folder: function [folders [block!] excluded [string!]][
		write-log rejoin ["add folder: " mold folders " excluded: " mold excluded]
		clear diagnostics
		clear root-folders
		forall folders [
			unless exists? folder: dirize lexer/uri-to-file folders/1 [
				continue
			]
			append root-folders folder
		]
		ex: split excluded ";"
		clear excluded-folders
		forall root-folders [
			forall ex [
				unless empty? ex/1 [
					append excluded-folders rejoin [root-folders/1 to file! ex/1]
				]
			]
		]
		forall root-folders [
			add-folder* root-folders/1
		]
		diagnostics
	]

	remove-folder*: function [folder [file!]][
		if error? files: try [read folder][exit]
		forall files [
			if dir? file: rejoin [folder files/1][
				remove-folder* file
				continue
			]
			uri: lexer/file-to-uri file
			if ss: find-source uri [
				remove ss
				append diagnostics make map! reduce [
					'uri uri
					'diagnostics make block! 1
				]
			]
		]
	]

	remove-folder: function [folders [block!]][
		clear diagnostics
		clear root-folders
		forall folders [
			unless exists? folder: dirize lexer/uri-to-file folders/1 [
				continue
			]
			append root-folders folder
		]

		forall root-folders [
			remove-folder* root-folders/1
		]
		diagnostics
	]

	workspace-file?: function [uri [string!]][
		file: lexer/uri-to-file uri
		forall root-folders [
			if find/match file root-folders/1 [
				return true
			]
		]
		false
	]

	new-lines?: function [text [string!]][
		ntext: text
		n: 0
		while [ntext: find/tail ntext "^/"][
			n: n + 1
		]
		n
	]

	update-range: function [
		npc* [block!] lines [integer!] end-chars [integer!]
		s-line [integer!] s-column [integer!]
		e-line [integer!] e-column [integer!] /only
	][
		update-pc: function [npc [block!] first* [logic!]][
			if first* [
				either lines = 0 [
					if npc/1/range/1/x = e-line [
						npc/1/range/1/y: npc/1/range/1/y - e-column + s-column + end-chars
					]
				][
					if npc/1/range/1/x = e-line [
						npc/1/range/1/y: npc/1/range/1/y - e-column + end-chars + 1
					]
					npc/1/range/1/x: npc/1/range/1/x + lines
				]
			]
			either lines = 0 [
				if npc/1/range/2/x = e-line [
					npc/1/range/2/y: npc/1/range/2/y - e-column + s-column + end-chars
				]
			][
				if npc/1/range/2/x = e-line [
					npc/1/range/2/y: npc/1/range/2/y - e-column + end-chars + 1
				]
				npc/1/range/2/x: npc/1/range/2/x + lines
			]
		]

		update-pc-nested: function [npc [block!] first* [logic!]][
			forall npc [
				update-pc npc first*
				if npc/1/nested [
					update-pc-nested npc/1/nested first*
				]
			]
		]
		if only [
			update-pc npc* no
			exit
		]
		update-pc-nested npc* yes
		either tail? npc* [
			par: back npc*
		][
			par: npc*
		]
		while [par: par/1/upper][
			update-pc par no
			update-pc-nested next par no
		]
	]

	update-upper: function [pc [block!] /remove?][
		forall pc [
			if all [
				find [block! paren! map!] to word! pc/1/type
				npc: pc/1/nested
			][
				forall npc [
					npc/1/upper: either remove? [back npc/1/upper][next npc/1/upper]
				]
			]
		]
	]

	update-ws: function [
			system? [logic!]
			pcs [block!] s-line [integer!] s-column [integer!] e-line [integer!]
			e-column [integer!] otext [string!] text [string!] line-stack [block!]
	][
		write-log "update-ws"
		olines: new-lines? otext
		lines: new-lines? text
		either lines = 0 [
			end-chars: length? text
		][
			end-chars: length? find/last/tail text "^/"
		]
		lines: lines - olines
		pc: pcs/2
		switch/default pcs/1 [
			head empty first [npc: pc]
			tail insert last mid one [
				npc: next pc
			]
		][return false]
		update-range npc lines end-chars s-line s-column e-line e-column
		if pcs/1 = 'one [
			npc: pcs/2
			update-range/only npc lines end-chars s-line s-column e-line e-column
			spos: lexer/line-pos? line-stack npc/1/range/1/x npc/1/range/1/y
			epos: lexer/line-pos? line-stack npc/1/range/2/x npc/1/range/2/y
			str: copy/part spos epos
			write-log mold npc/1/range
			write-log mold str
			if any [
				not top: lexer/transcode str
				none? nested: top/1/nested
				1 < length? nested
			][
				return false
			]
			npc/1/expr: nested/1/expr
			either find npc/1 'error [
				npc/1/error: nested/1/error
			][
				repend npc/1 ['error nested/1/error]
			]
		]
		true
	]

	update-one: function [
			system? [logic!]
			pcs [block!] s-line [integer!] s-column [integer!] e-line [integer!]
			e-column [integer!] otext [string!] text [string!] line-stack [block!]
	][
		write-log "update-one"
		olines: new-lines? otext
		lines: new-lines? text
		either lines = 0 [
			end-chars: length? text
		][
			end-chars: length? find/last/tail text "^/"
		]
		lines: lines - olines
		pc: pcs/2
		update-range next pc lines end-chars s-line s-column e-line e-column
		update-range/only pc lines end-chars s-line s-column e-line e-column
		spos: lexer/line-pos? line-stack pc/1/range/1/x pc/1/range/1/y
		epos: lexer/line-pos? line-stack pc/1/range/2/x pc/1/range/2/y
		if empty? str: copy/part spos epos [
			remove pc
			update-upper/remove? pc
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
		either find pc/1 'error [
			pc/1/error: nested/1/error
		][
			repend pc/1 ['error nested/1/error]
		]
		true
	]

	ws: charset " ^M^/^-"
	update-source: function [uri [string!] changes [block!]][
		switch/default find/last uri "." [
			".red"	[system?: no]
			;".reds"	[system?: yes]
		][return false]
		clear diagnostics
		not-trigger-charset: complement charset "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/%.+-_=?*&~?`"
		;write-log mold changes
		forall changes [
			unless top: find-top uri [
				return false
			]
			;write %f-log1.txt top/1/source
			;write/append %f-log1.txt "^/"
			;write/append %f-log1.txt lexer/format top
			code: top/1/source
			line-stack: top/1/lines
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
			ncode: copy/part code spos
			append ncode text
			append ncode epos
			line-stack: make block! 1000
			lexer/parse-line line-stack ncode
			top/1/source: ncode
			top/1/lines: line-stack
			otext-ws?: parse otext [some ws]
			text-ws?: parse text [some ws]
			if top/1/nested [
				spcs: epcs: position? top s-line s-column
				if all [
					s-line <> e-line
					s-column <> e-column
				][
					epcs: position? top e-line e-column
				]
				if any [
					none? spcs
					none? epcs
				][
					write-log "position failed"
					add-source* uri ncode
					continue
				]
				pc: spcs/2
				epc: epcs/2
				;-- insert/remove spaces in spaces or string!
				if all [
					any [
						epcs/1 <> 'one
						string! = epc/1/type
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
					unless update-ws system? epcs s-line s-column e-line e-column otext text line-stack [
						write-log "update-ws failed"
						add-source* uri ncode
					]
					continue
				]
				;-- token internal
				if all [
					any [
						all [
							find [first last one] spcs/1
							find [first last one] epcs/1
							spcs/2 = epcs/2
							not find reduce [block! map! paren!] pc/1/type
						]
						all [
							spcs <> epcs
							spcs/1 = 'mid
							epcs/1 = 'mid
							epcs/2 = next spcs/2
							not find reduce [block! map! paren!] epc/1/type
						]
						all [
							spcs <> epcs
							spcs/1 = 'mid
							find [last one] epcs/1
							epcs/2 = next spcs/2
							not find reduce [block! map! paren!] epc/1/type
						]
						all [
							spcs <> epcs
							epcs/1 = 'mid
							find [first one] spcs/1
							epcs/2 = next spcs/2
							not find reduce [block! map! paren!] pc/1/type
							epcs: spcs
						]
					]
					any [
						empty? text
						not find text not-trigger-charset
					]
					any [
						empty? otext
						not find otext not-trigger-charset
					]
				][
					unless update-one system? epcs s-line s-column e-line e-column otext text line-stack [
						write-log "update-one failed"
						add-source* uri ncode
					]
					continue
				]
				;-- insert a new token
				if all [
					spcs = epcs
					empty? otext
					any [
						not find text not-trigger-charset
						text = "[]"
						text = "()"
						text = "{}"
						text = {""}
					]
				][
					;write-log text
					;write-log mold spcs/1
					;write-log mold spcs/2/1/range
					if any [
						spcs/1 = 'head
						all [
							spcs/1 = 'tail
							(pc: next pc true)
						]
						all [
							spcs/1 = 'insert
							(pc: next pc true)
						]
						all [
							spcs/1 = 'first
							find reduce [block! paren!] pc/1/type
						]
						all [
							spcs/1 = 'last
							find reduce [block! paren!] pc/1/type
							(pc: next pc true)
						]
						all [
							spcs/1 = 'mid
							find reduce [block! paren!] pc/1/type
							pc: next pc
							find reduce [block! paren!] pc/1/type
						]
						spcs/1 = 'empty
					][
						end-chars: length? text
						if spcs/1 = 'empty [
							update-range next pc 0 end-chars s-line s-column e-line e-column
							update-range/only pc 0 end-chars s-line s-column e-line e-column
							repend pc/1 ['nested make block! 1]
							npc: pc/1/nested
							range: reduce [s-line s-column e-line e-column + end-chars]
							write-log "empty insert npc: "
							write-log mold range
							if any [
								not top: lexer/transcode text
								none? nested: top/1/nested
								1 < length? nested
							][
								write-log "empty insert failed"
								add-source* uri ncode
								ncode: ncode
								continue
							]
							append/only npc reduce ['expr nested/1/expr 'range range 'upper pc 'error nested/1/error]
							continue
						]
						update-range pc 0 end-chars s-line s-column e-line e-column
						update-upper pc
						range: reduce [s-line s-column e-line e-column + end-chars]
						write-log "insert pc: "
						write-log mold range
						if any [
							not top: lexer/transcode text
							none? nested: top/1/nested
							1 < length? nested
						][
							write-log "insert failed"
							add-source* uri ncode
							continue
						]
						either pc/1 [upper: pc/1/upper][
							upper: pc/-1/upper
						]
						insert/only pc reduce ['expr nested/1/expr 'range range 'upper upper 'error nested/1/error]
						ncode: ncode
						continue
					]
				]
			]
			write-log "diff failed"
			add-source* uri ncode
		]
		unless top: find-top uri [
			return false
		]
		;write %f-log2.txt top/1/source
		;write/append %f-log2.txt "^/"
		;write/append %f-log2.txt lexer/format top
		unless empty? errors: collect-errors top [
			append diagnostics make map! reduce [
				'uri uri
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
		insert str: to string! file: pc/1/expr "%"
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
			if word = to word! npc/1/1/expr [return false]
		]
		true
	]

	unique2?: function [specs [block!] word [word!]][
		forall specs [
			npc: specs/1/2
			if word = to word! npc/1/expr [return false]
		]
		true
	]

	collect-word*: function [pc [block!] word [word!] result [block!] *all? [logic!] /match?][
		string: to string! word
		collect*: function [word* [word!] pc* [block!]][
			string*: to string! word*
			either match? [
				if string = string* [
					append/only result pc*
				]
			][
				if all [
					find/match string* string
					any [
						*all?
						unique? result word*
					]
				][
					append/only result pc*
				]
			]
		]
		collect*-set: function [npc [block!] /back?][
			if empty? npc [
				either back? [
					if empty? npc: back npc [exit]
				][exit]
			]
			until [
				case [
					set-word! = npc/1/type [
						collect* to word! npc/1/expr npc
					]
					all [
						npc/1/type = issue!
						'define = to word! npc/1/expr
						npc/2
						word! = npc/2/type
					][
						collect* npc/2/expr next npc
					]
					all [
						npc/1/type = issue!
						'enum = to word! npc/1/expr
						npc/2
						word! = npc/2/type
						npc/3
						block! = npc/3/type
						epc: npc/3/nested
					][
						collect* to word! npc/2/expr next npc
						forall epc [
							if any [
								word! = epc/1/type
								set-word! = epc/1/type
							][
								collect* to word! epc/1/expr epc
							]
						]
					]
					all [
						npc/1/type = issue!
						'if = to word! npc/1/expr
						npc/2
						npc/3
					][
						npc2: npc
						while [
							all [
								not tail? npc2: next npc2
								npc2/1/type <> block!
							]
						][]
						if all [
							not tail? npc2
							nested: npc2/1/nested
						][
							either back? [
								collect*-set/back? tail nested
							][
								collect*-set nested
							]
						]
					]
					all [
						npc/1/type = issue!
						'either = to word! npc/1/expr
						npc/2
						npc/3
						npc/4
					][
						npc2: npc
						loop 2 [
							while [
								all [
									not tail? npc2: next npc2
									npc2/1/type <> block!
								]
							][]
							if all [
								not tail? npc2
								nested: npc2/1/nested
							][
								either back? [
									collect*-set/back? tail nested
								][
									collect*-set nested
								]
							]
						]
					]
					all [
						npc/1/type = issue!
						'switch = to word! npc/1/expr
						npc/2
						npc/3
					][
						npc2: npc
						while [
							all [
								not tail? npc2: next npc2
								npc2/1/type <> block!
							]
						][]
						if all [
							not tail? npc2
							nested: npc2/1/nested
						][
							forall nested [
								if all [
									nested/1/type = block!
									n2: nested/1/nested
								][
									collect*-set/back? back tail n2
								]
							]
						]
					]
					all [
						npc/1/type = issue!
						'import = to word! npc/1/expr
						npc/2
						npc/2/type = block!
						nested: npc/2/nested
					][
						forall nested [
							if all [
								nested/1/type = block!
								n2: nested/1/nested
							][
								collect*-set/back? back tail n2
							]
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
		collect*-func: function [npc [block!]][
			forall npc [
				if all [
					find [word! lit-word! refinement!] to word! npc/1/type
					npc/1/expr <> /local
				][
					collect* to word! npc/1/expr npc
				]
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
					block! = par/-1/type
					spec: par/-1/nested
					par/-2
					find [func function has] par/-2/expr
				][
					collect*-func spec
				]
				npc2: par
				collect*-set/back? npc
				collect*-set next npc
				npc: tail par
			][
				collect*-set/back? npc
				collect*-set next npc
				break
			]
		]
	]

	collect-word: function [top [block!] pc [block!] system? [logic!]][
		result: make block! 4
		word: to word! pc/1/expr
		collect-word* pc word result no
		sources: semantic/sources
		forall sources [
			if sources/1 <> top [
				switch/default find/last sources/1/1/uri "." [
					".red"	[nsystem?: no]
					;".reds"	[nsystem?: yes]
				][continue]
				if all [
					nsystem? = system?
					nested: sources/1/1/nested
				][
					collect-word* back tail nested word result no
				]
			]
		]
		result
	]

	next-context?: function [opc [block!] pc [block!] specs [block! none!] upper [logic!]][
		spec: none
		if all [
			pc/1
			pc/2
			any [
				all [
					word! = pc/1/type
					find [context object] pc/1/expr
					block! = pc/2/type
					spec: pc/2
				]
				all [
					word! = pc/1/type
					pc/1/expr = 'make
					pc/3
					block! = pc/3/type
					spec: pc/3
					any [
						all [
							word! = pc/2/type
							pc/2/expr = 'object!
						]
						all [
							word! = pc/2/type
							pc/2/expr <> to word! opc/1/expr
							res: find-set?/*context? next pc pc/2/expr upper no
							not empty? res
							res/1/1 = 'context
							spec: res/1/3
						]
					]
				]
			]
		][
			if all [
				specs
				spec
				nested: spec/nested
			][
				append/only specs nested
			]
			return true
		]
		false
	]

	next-block?: function [pc [block!] specs [block! none!]][
		spec: none
		if all [
			pc/1
			block! = pc/1/type
		][
			if all [
				specs
				nested: pc/1/nested
			][
				append/only specs nested
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
			word! = pc/1/type
			find [func function has does] pc/1/expr
			block! = pc/2/type
			any [
				all [
					find [func function] pc/1/expr
					pc/3
					block! = pc/3/type
					spec: pc/2
				]
				pc/1/expr = 'does
				all [
					pc/1/expr = 'has
					pc/3
					block! = pc/3/type
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

	find-set?: function [
		pc* [block!] word [word!] upper [logic!] *all? [logic!]
		/*func? /*context? /*block? /*define? /*enum? /*any?
	][
		result: make block! 4
		check-set?: function [npc [block!]][
			if all [
				set-word! = npc/1/type
				word = to word! npc/1/expr
			][
				npc2: npc
				while [
					all [
						not tail? npc2: next npc2
						set-word! = npc2/1/type
					]
				][]
				either tail? npc2 [
					repend/only result ['value npc []]
					unless *all? [
						return true
					]
				][
					if all [
						any [*context? *any?]
						next-context? npc npc2 specs: make block! 4 upper
					][
						repend/only result ['context npc specs]
						unless *all? [
							return true
						]
						return none
					]
					if all [
						any [*block? *any?]
						next-block? npc2 specs: make block! 4
					][
						repend/only result ['block npc specs]
						unless *all? [
							return true
						]
						return none
					]
					if all [
						any [*func? *any?]
						next-func? npc2 specs: make block! 4
					][
						repend/only result ['func npc specs]
						unless *all? [
							return true
						]
						return none
					]
					if *any? [
						repend/only result ['value npc reduce [npc2]]
						unless *all? [
							return true
						]
						return none
					]
				]
				return none
			]
			if all [
				npc/1/type = issue!
				'if = to word! npc/1/expr
				npc/2
				npc/3
			][
				npc2: npc
				while [
					all [
						not tail? npc2: next npc2
						npc2/1/type <> block!
					]
				][]
				if all [
					not tail? npc2
					nested: npc2/1/nested
				][
					if ret: find-set?* back tail nested [
						return ret
					]
				]
				return none
			]
			if all [
				npc/1/type = issue!
				'either = to word! npc/1/expr
				npc/2
				npc/3
				npc/4
			][
				npc2: npc
				ret: none
				ret2: none
				while [
					all [
						not tail? npc2: next npc2
						npc2/1/type <> block!
					]
				][]
				if all [
					not tail? npc2
					nested: npc2/1/nested
				][
					ret: find-set?* back tail nested
				]
				while [
					all [
						not tail? npc2: next npc2
						npc2/1/type <> block!
					]
				][]
				if all [
					not tail? npc2
					nested: npc2/1/nested
				][
					ret2: find-set?* back tail nested
				]
				if ret [return ret]
				if ret2 [return ret2]
				return none
			]
			if all [
				npc/1/type = issue!
				'switch = to word! npc/1/expr
				npc/2
				npc/3
			][
				npc2: npc
				while [
					all [
						not tail? npc2: next npc2
						npc2/1/type <> block!
					]
				][]
				if all [
					not tail? npc2
					nested: npc2/1/nested
				][
					ret: none
					ret2: none
					forall nested [
						if all [
							nested/1/type = block!
							n2: nested/1/nested
						][
							ret2: find-set?* back tail n2
							unless ret [ret: ret2]
						]
					]
					return ret
				]
				return none
			]
			if all [
				npc/1/type = issue!
				'import = to word! npc/1/expr
				npc/2
				npc/2/type = block!
				nested: npc/2/nested
			][
				ret: none
				ret2: none
				forall nested [
					if all [
						nested/1/type = block!
						n2: nested/1/nested
					][
						ret2: find-set?* back tail n2
						unless ret [ret: ret2]
					]
				]
				return ret
			]
			if all [
				npc/1/type = issue!
				'define = to word! npc/1/expr
				npc/2
				word! = npc/2/type
				word = npc/2/expr
			][
				if any [*define? *any?][
					repend/only result ['define next npc make block! 1]
					unless *all? [
						return true
					]
				]
				return none
			]
			if all [
				npc/1/type = issue!
				'enum = to word! npc/1/expr
				npc/2
				word! = npc/2/type
				npc/3
				npc/3/type = block!
				nested: npc/3/nested
			][
				if word = npc/2/expr [
					if any [*enum? *any?][
						repend/only result ['enum next npc make block! 1]
						unless *all? [
							return true
						]
					]
					return none
				]
				forall nested [
					if any [
						all [
							word! = nested/1/type
							word = nested/1/expr
						]
						all [
							set-word! = nested/1/type
							word = to word! nested/1/expr
						]
					][
						if any [*enum? *any?][
							repend/only result ['enum nested make block! 1]
							unless *all? [
								return true
							]
						]
					]
				]
				return none
			]
			none
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
		if all [
			find-set?* pc*
			not *all?
		][
			return result
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
				if all [
					find-set?* back tail npc
					not *all?
				][
					return result
				]
			]
		]
		result
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

	snippets-sys: [
		"reds.title.snippet"	"Red/System [ Title ]"			"Red/System [^/^-Title: ^"${2:title}^"^/]^/"
	]

	complete-word: function [top [block!] pc [block!] comps [block!]][
		switch/default find/last top/1/uri "." [
			".red"	[system?: no]
			;".reds"	[system?: yes]
		][exit]
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
		complete-snippet: function [system? [logic!]][
			nsnippets: either system? [snippets-sys][snippets]
			if word! = pc/1/type [
				len: (length? nsnippets) / 3
				repeat i len [
					if find/match nsnippets/(i * 3 - 2) string [
						append comps make map! reduce [
							'label nsnippets/(i * 3 - 2)
							'kind CompletionItemKind/Keyword
							'filterText? string
							'insertTextFormat 2
							'textEdit make map! reduce [
								'range range
								'newText nsnippets/(i * 3)
							]
							'data make map! reduce [
								'type either system? ["snippet-sys"]["snippet"]
								'index (i * 3 - 1)
							]
						]
					]
				]

			]
		]
		range: lexer/form-range pc/1/range
		if any [
			lit-word! = pc/1/type
			get-word! = pc/1/type
		][
			range/start/character: range/start/character + 1
		]
		if empty? string: to string! to word! pc/1/expr [
			exit
		]
		result: collect-word top pc system?
		forall result [
			rpc: result/1
			top: rpc
			while [par: top/1/upper][top: par]
			kind: CompletionItemKind/Variable
			type: rpc/1/type
			rstring: to string! to word! rpc/1/expr
			case [
				find [word! lit-word! refinement!] to word! type [
					kind: CompletionItemKind/Field
				]
				type = set-word! [
					ret: find-set?/*any? rpc to word! rpc/1/expr no no
					unless empty? ret [
						switch ret/1/1 [
							context		[kind: CompletionItemKind/Struct]
							func		[kind: CompletionItemKind/Function]
							block		[kind: CompletionItemKind/Array]
							value		[
								npc: ret/1/2
								if all [
									npc/2
									string! = npc/2/type
									par1: npc/1/upper
									par2: par1/1/upper
									par2/-1
									issue! = par2/-1/type
									'import = to word! par2/-1/expr
								][
									kind: CompletionItemKind/Module
								]
							]
						]
					]
				]
				type = 'word! [
					kind: CompletionItemKind/Constant
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

		words: system-words/get-words system?
		forall words [
			sys-string: to string! words/1
			if find/match sys-string string [
				append comps make map! reduce [
					'label sys-string
					'kind either system? [CompletionItemKind/Keyword][system-completion-kind words/1]
					'filterText? string
					'insertTextFormat 1
					'textEdit make map! reduce [
						'range range
						'newText sys-string
					]

					'data make map! reduce [
						'type either system? ["keyword-sys"]["keyword"]
					]
				]
			]
		]
		complete-snippet system?
	]

	collect-func-refinement*: function [specs [block!] *all? [logic!]][
		result: make block! 4
		forall specs [
			npc: specs/1
			forall npc [
				if all [
					refinement! = npc/1/type
					any [
						*all?
						unique2? result to word! npc/1/expr
					]
				][
					if 'local = to word! npc/1/expr [break]
					repend/only result ['ref npc make block! 1]
				]
			]
		]
		result
	]
	collect-context-set-word*: function [specs [block!] *all? [logic!]][
		result: make block! 4
		forall specs [
			npc: back tail specs/1
			until [
				if all [
					set-word! = npc/1/type
					any [
						*all?
						unique2? result to word! npc/1/expr
					]
				][
					unless empty? ret: find-set?/*any? npc to word! npc/1/expr false no [
						append result ret
					]
				]
				npc2: npc
				npc: back npc
				head? npc2
			]
		]
		result
	]
	collect-block-word*: function [specs [block!] *all? [logic!]][
		result: make block! 4
		forall specs [
			npc: specs/1
			forall npc [
				if all [
					npc/1/expr
					any-word? npc/1/expr
					any [
						*all?
						unique2? result to word! npc/1/expr
					]
				][
					either all [
						npc/2
						block! = npc/2/type
						spec: npc/2/nested
					][
						repend/only result ['block npc reduce [spec]]
					][
						repend/only result ['field npc make block! 1]
					]
				]
			]
		]
		result
	]

	collect-slash-context*: function [specs [block!] word [word!] slash-end? [logic!] end? [logic!] *all? [logic!] match? [logic!]][
		result: make block! 4
		string: to string! word
		collect*: function [npc [block!]][
			until [
				if all [
					npc/1/expr
					set-word? npc/1/expr
					any [
						*all?
						unique2? result to word! npc/1/expr
					]
				][
					either any [
						all [
							not end?
							not slash-end?
						]
						all [
							end?
							match?
						]
					][
						if word = to word! npc/1/expr [
							unless empty? specs: find-set?/*any? npc word false no [
								append result specs
								unless *all? [return result]
							]
						]
					][
						if all [
							end?
							find/match to string! npc/1/expr string
						][
							unless empty? specs: find-set?/*any? npc to word! npc/1/expr false no [
								append result specs
							]
						]
						if all [
							slash-end?
							word = to word! npc/1/expr
						][
							unless empty? specs: find-set?/*any? npc word false no [
								forall specs [
									switch specs/1/1 [
										context [
											unless empty? ret: collect-context-set-word* specs/1/3 *all? [
												append result ret
											]
										]
										func [
											unless empty? ret: collect-func-refinement* specs/1/3 *all? [
												append result ret
											]
										]
										block [
											unless empty? ret: collect-block-word* specs/1/3 *all? [
												append result ret
											]
										]
									]
								]
								unless empty? result [
									unless *all? [return result]
								]
							]
						]
					]
				]
				npc2: npc
				npc: back npc
				head? npc2
			]
		]
		forall specs [
			collect* back tail specs/1
		]
		result
	]

	collect-slash-block*: function [specs [block!] word [word! integer!] slash-end? [logic!] end? [logic!] *all? [logic!] match? [logic!]][
		result: make block! 4
		if word? word [
			string: to string! word
		]
		collect*: function [npc [block!]][
			forall npc [
				either integer? word [
					if word = index? npc [
						if any [
							all [
								not end?
								not slash-end?
							]
							all [
								end?
								match?
							]
						][
							either all [
								block! = npc/1/type
								spec: npc/1/nested
							][
								repend/only result ['block npc reduce [spec]]
							][
								repend/only result ['field npc make block! 1]
							]
							return result
						]
						either all [
							block! = npc/1/type
							spec: npc/1/nested
						][
							either slash-end? [
								unless empty? ret: collect-block-word* reduce [spec] *all? [
									append result ret
									return result
								]
							][
								repend/only result ['block npc reduce [spec]]
								return result
							]
						][
							return result
						]
					]
				][
					if all [
						npc/1/expr
						any-word? npc/1/expr
						any [
							*all?
							unique2? result to word! npc/1/expr
						]
					][
						if any [
							all [
								not end?
								not slash-end?
							]
							all [
								end?
								match?
							]
						][
							if word = to word! npc/1/expr [
								either all [
									npc/2
									block! = npc/2/type
									spec: npc/2/nested
								][
									repend/only result ['block npc reduce [spec]]
								][
									repend/only result ['field npc make block! 1]
								]
								unless *all? [return result]
							]
							continue
						]
						if all [
							end?
							find/match to string! npc/1/expr string
						][
							either all [
								npc/2
								block! = npc/2/type
								spec: npc/2/nested
							][
								repend/only result ['block npc reduce [spec]]
							][
								repend/only result ['field npc make block! 1]
							]
						]
						if all [
							slash-end?
							word = to word! npc/1/expr
							npc/2
							block! = npc/2/type
							spec: npc/2/nested
						][
							unless empty? ret: collect-block-word* reduce [spec] *all? [
								append result ret
								unless *all? [return result]
							]
						]
					]
				]
			]
		]
		forall specs [
			collect* specs/1
		]
		result
	]

	collect-slash-func*: function [specs [block!] word [word!] slash-end? [logic!] end? [logic!] *all? [logic!] match? [logic!]][
		result: make block! 4
		string: to string! word
		collect*: function [npc [block!]][
			forall npc [
				if all [
					refinement! = npc/1/type
					any [
						*all?
						unique2? result to word! npc/1/expr
					]
				][
					if any [
						all [
							not end?
							not slash-end?
						]
						all [
							end?
							match?
						]
					][
						if word = to word! npc/1/expr [
							if npc/1/expr = /local [exit]
							repend/only result ['ref npc make block! 1]
							unless *all? [return result]
						]
						continue
					]
					if slash-end? [
						if 'local = to word! npc/1/expr [exit]
						repend/only result ['ref npc make block! 1]
					]
					if end? [
						if find/match to string! npc/1/expr string [
							if 'local = to word! npc/1/expr [exit]
							repend/only result ['ref npc make block! 1]
						]
					]
				]
			]
		]
		forall specs [
			collect* specs/1
		]
		result
	]

	collect-path*: function [pc [block!] path [block!] *all? [logic!] match? [logic!]][
		unless specs: find-set?/*func?/*context?/*block? pc to word! path/1 true *all? [
			return make block! 1
		]
		if empty? specs [return specs]
		if path/2 = '/ [
			nspecs: make block! 4
			forall specs [
				switch specs/1/1 [
					context [
						unless empty? ret: collect-context-set-word* specs/1/3 *all? [
							append nspecs ret
						]
					]
					func [
						unless empty? ret: collect-func-refinement* specs/1/3 *all? [
							append nspecs ret
						]
					]
					block [
						unless empty? ret: collect-block-word* specs/1/3 *all? [
							append nspecs ret
						]
					]
				]
			]
			return nspecs
		]

		path: next path
		until [
			slash-end?: no
			either path/2 [
				end?: no
				if path/2 = '/ [
					slash-end?: yes
				]
			][
				end?: yes
			]
			nspecs: make block! 4
			forall specs [
				switch specs/1/1 [
					context [
						if error? word: try [to word! path/1][return make block! 1]
						unless empty? ret: collect-slash-context* specs/1/3 word slash-end? end? *all? match? [
							append nspecs ret
						]
					]
					func [
						if error? word: try [to word! path/1][return make block! 1]
						either all [
							any [
								end?
								slash-end?
							]
							not empty? specs/1/3
						][
							unless empty? ret: collect-slash-func* specs/1/3 word slash-end? end? *all? match? [
								append nspecs ret
							]
						][
							append/only nspecs specs/1
						]
					]
					block [
						if error? word: try [to word! path/1][
							if error? word: try [to integer! path/1][
								return make block! 1
							]
						]
						unless empty? ret: collect-slash-block* specs/1/3 word slash-end? end? *all? match? [
							append nspecs ret
						]
					]
				]
			]
			specs: nspecs
			any [
				tail? path: next path
				path/1 = '/
			]
		]
		specs
	]

	collect-path: function [top [block!] pc [block!] path [block!] *all? [logic!] match? [logic!] system? [logic!]][
		specs: make block! 8
		ret: collect-path* pc path *all? match?
		if 0 < length? ret [
			append specs ret
			unless *all? [return specs]
		]
		sources: semantic/sources
		forall sources [
			if sources/1 <> top [
				switch/default find/last sources/1/1/uri "." [
					".red"	[nsystem?: no]
					;".reds"	[nsystem?: yes]
				][continue]
				if all [
					nsystem? = system?
					nested: sources/1/1/nested
				][
					ret: collect-path* back tail nested path *all? match?
					if 0 < length? ret [
						append specs ret
						unless *all? [return specs]
					]
				]
			]
		]
		specs
	]

	complete-path: function [top [block!] pc [block!] comps [block!]][
		switch/default find/last top/1/uri "." [
			".red"	[system?: no]
			;".reds"	[system?: yes]
		][exit]
		complete-sys-path: function [][
			tstr: find/tail/last pure-path "/"
			tstr: copy/part pure-path tstr
			unless system-words/keyword? no fword [exit]
			if error? result: try [red-complete-ctx/red-complete-path pure-path no][
				exit
			]
			forall result [
				unless nstring: find/tail/last result/1 "/" [
					nstring: result/1
				]
				append comps make map! reduce [
					'label nstring
					'kind CompletionItemKind/Property
					'filterText? filter
					'insertTextFormat 1
					'preselect true
					'textEdit make map! reduce [
						'range range
						'newText nstring
					]
					'data make map! reduce [
						'path append copy tstr nstring
						'type "keypath"
					]
				]
			]
		]
		spos: lexer/line-pos? top/1/lines pc/1/range/1/x pc/1/range/1/y
		epos: lexer/line-pos? top/1/lines pc/1/range/2/x pc/1/range/2/y
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
		pcs: collect-path top pc paths no no system?
		forall pcs [
			type: pcs/1/1
			npc: pcs/1/2
			words: pcs/1/3
			ntop: npc
			while [par: ntop/1/upper][ntop: par]
			nstring: to string! npc/1/expr
			kind: CompletionItemKind/Variable
			switch type [
				context [
					kind: CompletionItemKind/Struct
				]
				func [
					kind: CompletionItemKind/Function
				]
				ref [
					kind: CompletionItemKind/Field
				]
				block [
					kind: CompletionItemKind/Array
				]
				field [
					kind: CompletionItemKind/Property
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
					'range npc/1/range
					'type "path"
					'itype mold type
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
				type: pc/1/type
				lstr: pick lexer/line-pos? top/1/lines pc/1/range/2/x pc/1/range/2/y - 1 1
				unless any [
					find [word! lit-word! get-word! path! lit-path! get-path! file!] to word! type
					all [
						any [
							type = path!
							type = lit-path!
							type = get-path!
						]
						#"/" = lstr
					]
				][
					pc: next pc
				]
			]
		][return none]
		type: pc/1/type
		wtype: to word! type
		lstr: pick lexer/line-pos? top/1/lines pc/1/range/2/x pc/1/range/2/y - 1 1
		unless any [
			find [word! lit-word! get-word! path! lit-path! get-path! file!] wtype
			all [
				any [
					type = path!
					type = lit-path!
					type = get-path!
				]
				#"/" = lstr
			]
		][
			return none
		]
		comps: clear last-comps
		if type = file! [
			complete-file top pc comps
			return comps
		]
		if find [word! lit-word! get-word!] wtype [
			complete-word top pc comps
			return comps
		]
		if any [
			find [path! lit-path! get-path!] wtype
			all [
				any [
					type = path!
					type = lit-path!
					type = get-path!
				]
				#"/" = lstr
			]
		][
			complete-path top pc comps
			return comps
		]
		none
	]

	form-func-spec: function [spec [block! none!]][
		str: make string! 40
		append str "[^/"
		forall spec [
			nstr: mold spec/1
			append str rejoin ["^-" nstr]
			either any [
				block? spec/1
				all [
					not block? spec/1
					spec/2
					not block? spec/2
				]
			][
				append str lf
			][
				either 0 < len: 24 - length? nstr [
					append/dup str " " len
					append str "^-"
				][
					append str "^-^-"
				]
			]
		]
		append str "]"
		str
	]

	func-info: function [fn [word!] spec [block! none!] name [string!]][
		if error? *-*spec*-*: try [
			either spec [
				do reduce [fn spec []]
			][
				do reduce [fn []]
			]
		][
			ret: rejoin [name " is a funtion with invalid spec^/" to string! fn " "]
			append ret form-func-spec spec
			return ret
		]
		str: help-string *-*spec*-*
		replace/all str "*-*spec*-*" name
		return str
	]

	;-- TBD
	get-block: function [pc [block!]][
		ret: make block! 4
		forall pc [
			if find [block! map! paren!] to word! pc/1/type [
				append/only ret make pc/1/type
					either pc/1/nested [
						get-block pc/1/nested
					][[]]
				continue
			]
			append ret pc/1/expr
		]
		ret
	]

	;-- TBD
	get-func-spec: function [pc [block!]][
		get-func-block: function [pc [block!]][
			ret: make block! 4
			forall pc [
				if all [
					refinement! = pc/1/type
					'local = to word! pc/1/expr
				][return ret]
				if find [block! map! paren!] to word! pc/1/type [
					append/only ret make pc/1/type
						either pc/1/nested [
							get-func-block pc/1/nested
						][[]]
					continue
				]
				append ret pc/1/expr
			]
			ret
		]
		ret: get-func-block pc
		until [
			if all [
				ret/1 = to set-word! 'return
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
		head ret
	]

	get-top: function [pc [block!]][
		while [par: pc/1/upper][
			pc: par
		]
		pc
	]

	resolve-word: function [top [block!] pc [block!] string [string!] itype [word! none!]][
		switch/default find/last top/1/uri "." [
			".red"	[system?: no]
			;".reds"	[system?: yes]
		][return none]
		resolve-word*: function [][
			if all [
				set-word! = pc/1/type
				pc/2
			][
				unless ret: find-set?/*any? pc to word! pc/1/expr no no [
					return none
				]
				specs: ret/1/3
				switch ret/1/1 [
					context		[return rejoin [string " is a context!"]]
					func		[
						if system? [
							if all [
								not empty? specs
								upper: specs/1/1/upper
								upper/-1
								word! = upper/-1/type
								find [func function] fn: upper/-1/expr
							][
								ret: rejoin [string " is a function!^/" to string! fn " "]
								append ret form-func-spec get-func-spec upper/1/nested
								return ret
							]
							return rejoin [string " is a function!"]
						]
						if all [
							not empty? specs
							upper: specs/1/1/upper
							upper/-1
							word! = upper/-1/type
							find [func function] fn: upper/-1/expr
						][
							return func-info fn get-func-spec upper/1/nested to string! pc/1/expr
						]
						return func-info 'func [] to string! pc/1/expr
					]
					block		[
						return rejoin [string " is a block! variable."]
					]
					value		[
						npc: ret/1/2
						if all [
							npc/2
							string! = npc/2/type
							par1: npc/1/upper
							par2: par1/1/upper
							par2/-1
							par2/-1/expr = to issue! 'import
						][
							desc: none
							if all [
								npc/3
								npc/3/type = block!
								nested: npc/3/nested
							][
								desc: get-block nested
							]
							ret: rejoin [
								string " is import form " to string! par1/-2/expr
								"^/prototype: " npc/2/expr
							]
							if desc [
								append ret rejoin ["^/" form-func-spec desc]
							]
							return ret
						]
						if word! = specs/1/1/type [
							return rejoin [string ": " mold specs/1/1/expr]
						]
						return rejoin [string " is a " mold specs/1/1/type " variable."]
					]
				]
			]
			if all [
				word! = pc/1/type
				pc/-1
				pc/-1/expr = to issue! 'define
			][
				return rejoin [string " is a #define macro."]
			]
			if all [
				word! = pc/1/type
				pc/-1
				pc/-1/expr = to issue! 'enum
			][
				return rejoin [string " is a #enum type."]
			]
			if all [
				word! = pc/1/type
				upper: pc/1/upper
				upper/-2
				upper/-2/expr = to issue! 'enum
			][
				return rejoin [string " is a #enum value: " mold index? pc]
			]
			if all [
				none? itype
				upper: pc/1/upper
				upper/-1
				upper/-1/type = word!
				find [func function has] upper/-1/expr
			][
				if upper/-1/expr = 'has [
					return rejoin [string " is a local variable."]
				]
				if refinement! = pc/1/type [
					return rejoin [string " is a function refinement!"]
				]
				ret: rejoin [string " is a function argument or local variable!"]
				if all [
					pc/2
					block! = pc/2/type
					pc/2/nested
				][
					return rejoin [ret "^/type: " mold get-block pc/2/nested]
				]
				return ret
			]
			if itype [
				switch itype [
					ref [
						return rejoin [string " is a function refinement!"]
					]
					field block [
						if pc/2 [
							return rejoin [string " is a block item!^/next value: " mold pc/2/expr]
						]
						return rejoin [string " is a block item!"]
					]
				]
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
			params/data/type = "keyword"
		][
			word: to word! params/label
			if datatype? get word [
				return rejoin [params/label " is a base datatype!"]
			]
			return system-words/get-word-info no word
		]
		if all [
			params/data
			params/data/type = "keyword-sys"
		][
			word: to word! params/label
			return rejoin [params/label " is a keyword!"]
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
			params/data/type = "snippet-sys"
			index: params/data/index
		][
			return snippets-sys/:index
		]
		if all [
			params/data
			params/data/type = "keypath"
			params/data/path
		][
			path: load params/data/path
			return system-words/get-path-info no path
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
			itype: none
			if params/data/itype [
				itype: to word! params/data/itype
			]
			return resolve-word top pc params/label itype
		]
		none
	]

	hover-word*: function [top [block!] pc [block!] word [word!] *all? [logic!]][
		switch/default find/last top/1/uri "." [
			".red"	[system?: no]
			;".reds"	[system?: yes]
		][return make block! 1]
		result: make block! 4
		collect-word*/match? pc word result *all?
		if all [
			not *all?
			0 < length? result
		][return result]
		sources: semantic/sources
		forall sources [
			if sources/1 <> top [
				switch/default find/last sources/1/1/uri "." [
					".red"	[nsystem?: no]
					;".reds"	[nsystem?: yes]
				][continue]
				if all [
					nsystem? = system?
					nested: sources/1/1/nested
				][
					npc: back tail nested
					collect-word*/match? npc word result *all?
					if all [
						not *all?
						0 < length? result
					][return result]
				]
			]
		]
		result
	]

	hover-word: function [top [block!] pc [block!] word [word!]][
		result: hover-word* top pc word no
		if 0 = length? result [return none]
		forall result [
			unless set-word! = result/1/1/type [
				pc: result/1
				top: get-top pc
				return resolve-word top pc to string! pc/1/expr none
			]
		]
		pc: result/1
		top: get-top pc
		resolve-word top pc to string! pc/1/expr none
	]

	hover-path: function [top [block!] pc [block!] path [block!]][
		switch/default find/last top/1/uri "." [
			".red"	[system?: no]
			;".reds"	[system?: yes]
		][return none]
		result: collect-path top pc path no yes system?
		if 0 = length? result [return none]
		pc: result/1/2
		top: get-top pc
		resolve-word top pc to string! pc/1/expr result/1/1
	]

	hover-types: reduce [word! lit-word! get-word! set-word! path! lit-path! get-path! set-path! integer! float! pair! binary! char! email! logic! percent! tuple! time! date! file! url! string! refinement! issue!]
	literal-disp: skip hover-types 8
	get-pos-info: function [uri [string!] line [integer!] column [integer!]][
		unless top: semantic/find-top uri [return none]
		unless pcs: semantic/position? top line column [
			return none
		]
		pc: pcs/2
		unless find [one first last mid] pcs/1 [return none]
		unless find hover-types pc/1/type [return none]
		return reduce [top pc]
	]

	hover-keyword: function [word [word!]][
		if system-words/keyword? no word [
			if datatype? get word [
				return rejoin [mold word " is a base datatype!"]
			]
			return system-words/get-word-info no word
		]
		none
	]

	hover-keypath: function [path [block!]][
		if error? path: try [to path! path][return none]
		system-words/get-path-info no path
	]

	gain-path: function [pc [block!]][
		res: make block! 4
		forever [
			unless pc/1/expr [return none]
			insert res pc/1/expr
			if head? pc [break]
			pc: back pc
		]
		res
	]

	hover: function [uri [string!] line [integer!] column [integer!]][
		unless ret: get-pos-info uri line column [return none]
		top: ret/1 pc: ret/2
		upper: pc/1/upper
		in-path?: no
		if upper/1/type [
			in-path?: find [path! lit-path! get-path! set-path!] to word! upper/1/type
		]
		if in-path? [
			unless path: gain-path pc [return none]
			if 1 = length? path [
				if ret: hover-word top pc word: to word! path/1 [return ret]
				return hover-keyword word
			]
			if ret: hover-path top pc path [return ret]
			return hover-keypath path
		]
		if find literal-disp type: pc/1/type [
			if file! = type [
				return rejoin [mold type " : " form/part pc/1/expr 60]
			]
			return rejoin [mold type " : " mold/part pc/1/expr 60]
		]
		if ret: hover-word top pc word: to word! pc/1/expr [return ret]
		hover-keyword word
	]

	definition-word: function [top [block!] pc [block!] word [word!]][
		result: hover-word* top pc word yes
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

	definition-path: function [top [block!] pc [block!] path [block!]][
		switch/default find/last top/1/uri "." [
			".red"	[system?: no]
			;".reds"	[system?: yes]
		][return make block! 1]
		result: collect-path top pc path yes yes system?
		if 0 = length? result [return none]
		ret: make block! 4
		forall result [
			top: get-top pc: result/1/2
			append ret make map! reduce [
				'uri top/1/uri
				'range lexer/form-range pc/1/range
			]
		]
		ret
	]

	definition: function [uri [string!] line [integer!] column [integer!]][
		unless ret: get-pos-info uri line column [return none]
		top: ret/1 pc: ret/2
		upper: pc/1/upper
		in-path?: no
		if upper/1/type [
			in-path?: find [path! lit-path! get-path! set-path!] to word! upper/1/type
		]
		if in-path? [
			unless path: gain-path pc [return none]
			if 1 = length? path [
				return definition-word top pc to word! path/1
			]
			return definition-path top pc path
		]
		if find literal-disp pc/1/type [
			return none
		]
		definition-word top pc to word! pc/1/expr
	]

	unique3?: function [specs [block!] str [string!]][
		forall specs [
			if str = specs/1/name [return false]
		]
		true
	]

	symbols: function [uri [string!]][
		unless top: semantic/find-top uri [return none]
		unless pc: top/1/nested [return none]
		symbols*: function [npc [block!] depth [integer!]][
			result: make block! 4
			until [
				if all [
					set-word! = npc/1/type
					specs: find-set?/*any? npc to word! npc/1/expr no no
					not empty? specs
					unique3? result to string! npc/1/expr
				][
					forall specs [
						type: specs/1/1
						pc: specs/1/2
						spec: specs/1/3
						first-spec: spec/1
						switch/default type [
							context [
								either empty? first-spec [
									range: pc/1/range
								][
									upper: first-spec/1/upper
									range: reduce [pc/1/range/1 upper/1/range/2]
								]
								append result last-symbol: make map! reduce [
									'name		to string! pc/1/expr
									'detail		rejoin [mold pc/1/expr " is a context"]
									'kind		SymbolKind/Namespace
									'range		lexer/form-range range
									'selectionRange		lexer/form-range pc/1/range
								]
								if all [
									depth < 3
									not empty? first-spec
								][
									last-symbol/children: symbols* back tail first-spec depth + 1
								]
							]
							func [
								either empty? first-spec [
									range: pc/1/range
								][
									upper: first-spec/1/upper
									range: reduce [pc/1/range/1 upper/1/range/2]
								]
								append result last-symbol: make map! reduce [
									'name		to string! pc/1/expr
									'detail		rejoin [mold pc/1/expr " is a function"]
									'kind		SymbolKind/Function
									'range		lexer/form-range range
									'selectionRange		lexer/form-range pc/1/range
								]
							]
						][
							either empty? first-spec [
								range: pc/1/range
							][
								upper: first-spec/1/upper
								range: reduce [pc/1/range/1 upper/1/range/2]
							]
							append result last-symbol: make map! reduce [
								'name		to string! pc/1/expr
								'detail		rejoin [mold pc/1/expr " is a value"]
								'kind		SymbolKind/Variable
								'range		lexer/form-range range
								'selectionRange		lexer/form-range pc/1/range
							]
						]
					]
				]
				npc2: npc
				npc: back npc
				head? npc2
			]
			result
		]
		symbols* back tail top/1/nested 0
	]
]
