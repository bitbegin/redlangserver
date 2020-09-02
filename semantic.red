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
	;-- types: top-err head tail insert first last mid empty one
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
						not find [path! set-path!] type
					][
						;-- "   token"
						;--     ^
						return reduce ['first pc]
					]
					if all [
						pc/1/range/2/x = line
						pc/1/range/2/y = column
						any [
							not in-path?
							all [
								item: back tail pc/1/nested
								item/1/range/2/y <> column
							]
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
					range: reduce [pc/1/range/1 pc/1/range/1]
					append ret make map! reduce [
						'severity 1							;-- DiagnosticSeverity/Error
						'code mold pc/1/type
						'source "Syntax"
						'message mold error/code
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

	add-include-file: function [top [block!] depth [integer!]][
		unless top [exit]
		if depth <= 0 [exit]
		include-file: function [file [file!]][
			if all [
				exists? file
				code: read-file file
			][
				uri: lexer/file-to-uri file
				write-log rejoin ["include: " uri]
				add-source* uri code depth - 1
			]
		]

		include-each: function [pc [block!]][
			if all [
				issue! = pc/1/type
				"include" = to string! pc/1/expr/1
				pc/2
				file! = pc/2/type
				file: pc/2/expr/1
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

	add-source-force: function [uri [string!] code [string!] return: [block!]][
		unless ext: find/last/tail uri "." [exit]
		case [
			ext = "red" [ftype: 'red]
			ext = "reds" [ftype: 'reds]
			true [exit]
		]
		write-log rejoin ["parse uri: " uri]
		top: lexer/transcode code
		repend top/1 ['uri uri 'ftype ftype]
		add-source-to-table uri top
		top
	]

	add-source*: function [uri [string!] code [string!] depth [integer!] return: [block!]][
		if any [
			not top: find-top uri
			top/1/source <> code
		][
			top: add-source-force uri code
			add-include-file top depth
		]
		update-diags top uri
		top
	]

	add-source: function [uri [string!] code [string!]][
		clear diagnostics
		write-log rejoin ["add source: " uri]
		add-source* uri code 1
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
			add-source* lexer/file-to-uri file read-file file 1
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
		npc* [block!] nlines [integer!] end-chars [integer!]
		s-line [integer!] s-column [integer!]
		e-line [integer!] e-column [integer!] /only
	][
		olines: e-line - s-line
		either nlines = 0 [
			include-line?: no
		][
			include-line?: yes
		]
		lines: nlines - olines
		update-pc: function [npc [block!] first* [logic!]][
			if first* [
				either include-line? [
					if npc/1/range/1/x = e-line [
						npc/1/range/1/y: npc/1/range/1/y - e-column + end-chars + 1
					]
				][
					if npc/1/range/1/x = e-line [
						npc/1/range/1/y: npc/1/range/1/y - e-column + s-column + end-chars
					]
				]
				npc/1/range/1/x: npc/1/range/1/x + lines
			]
			either include-line? [
				if npc/1/range/2/x = e-line [
					npc/1/range/2/y: npc/1/range/2/y - e-column + end-chars + 1
				]
			][
				if npc/1/range/2/x = e-line [
					npc/1/range/2/y: npc/1/range/2/y - e-column + s-column + end-chars
				]
			]
			npc/1/range/2/x: npc/1/range/2/x + lines
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
			update-pc-nested next par yes
		]
	]

	update-upper: function [pc [block!] /remove?][
		forall pc [
			if npc: pc/1/nested [
				forall npc [
					npc/1/upper: either remove? [back npc/1/upper][next npc/1/upper]
				]
			]
		]
	]

	remove-node: function [pc [block!]][
		upper: pc/1/upper
		either 1 = length? upper/1/nested [
			upper/1/nested: none
		][
			remove pc
		]
	]

	ws: charset " ^M^/^-"
	all-path!: reduce [path! lit-path! get-path! set-path!]
	all-pair!: reduce [block! paren! map!]
	pre-path!: reduce [lit-path! get-path!]
	update-token: function [
		tag [word!] pc [block!] etag [word!] epc [block!]
		otext [string!] text [string!] oline-stack [block!] line-stack [block!]
		s-line [integer!] s-column [integer!] e-line [integer!] e-column [integer!]
	][
		nlines: new-lines? text
		either nlines = 0 [
			end-chars: length? text
		][
			end-chars: length? find/last/tail text "^/"
		]
		rebuild: [
			type: nested/1/type
			range: nested/1/range
			either find [empty tail] tag [
				line: s-line column: s-column
			][
				wrange: wpc/1/range
				case [
					wrange/1/x = s-line [
						line: s-line
						column: either wrange/1/y >= s-column [s-column][wrange/1/y]
					]
					wrange/1/x > s-line [
						line: s-line column: s-column
					]
					true [
						line: wrange/1/x column: wrange/1/y
					]
				]
			]
			either range/1/x = 1 [
				start: as-pair line column + range/1/y - 1
			][
				start: as-pair line + range/1/x - 1 range/1/y
			]
			either range/2/x = 1 [
				stop: as-pair line column + range/2/y - 1
			][
				stop: as-pair line + range/2/x - 1 range/2/y
			]
			nested/1/range: reduce [start stop]
			case [
				find all-pair! type [
					if nested/1/nested [return false]
					if nested/1/error [return false]
					write-log "empty pair"
				]
				type = string! [
					if nested/1/error [return false]
					write-log "string"
				]
				type = file! [
					if nested/1/error [return false]
					write-log "file"
				]
				find all-path! type [
					start: nested/1/range/1
					nnested: nested/1/nested
					if find pre-path! type [start: start + 0x1]
					forall nnested [
						if nnested/1/nested [return false]
						stop: start + as-pair 0 nnested/1/range/2/y - nnested/1/range/1/y
						nnested/1/range: reduce [start stop]
						start: stop + 0x1
					]
					write-log "any path"
				]
				true [
					write-log "token"
				]
			]
		]

		replace-node: [
			ntext: copy text
			unless empty? head-str [
				insert ntext head-str
			]
			unless empty? tail-str [
				append ntext tail-str
			]
			write-log rejoin ["transcode: " ntext]
			ntop: lexer/transcode ntext
			unless nested: ntop/1/nested [
				write-log "remove token"
				update-upper/remove? next wpc
				update-range next wpc nlines end-chars s-line s-column e-line e-column
				remove-node wpc
				return true
			]
			if 1 <> length? nested [return false]
			if nested/1/type = 'comment [
				npc: next wpc
				if tail? npc [
					npc: wpc/1/upper
				]
				if all [
					(length? ntop/1/lines) - 1 = nested/1/range/1/x
					e-line = npc/1/range/1/x
				][return false]
			]
			do rebuild
			upper: wpc/1/upper
			wpc/1: nested/1
			wpc/1/upper: upper
			if nn: wpc/1/nested [
				forall nn [
					nn/1/upper: wpc
				]
			]
			write-log "change token"
			update-range next wpc nlines end-chars s-line s-column e-line e-column
		]

		in-path?: no
		if utype: pc/1/upper/1/type [
			in-path?: find all-path! utype
		]

		head-str: ""
		tail-str: ""
		wpc: pc

		switch tag [
			head [
				either find all-path! pc/1/type [
					switch etag [
						head [
							if pc <> epc [return false]
							write-log rejoin ["transcode: " text]
							ntop: lexer/transcode text
							unless nested: ntop/1/nested [
								write-log "remove/insert spaces"
								update-range pc nlines end-chars s-line s-column e-line e-column
								return true
							]
							if 1 <> length? nested [return false]
							if nested/1/type = 'comment [
								if all [
									(length? ntop/1/lines) - 1 = nested/1/range/1/x
									e-line = wpc/1/range/1/x
								][return false]
							]
							do rebuild
							upper: wpc/1/upper
							insert/only wpc nested/1
							wpc/1/upper: upper
							if nn: wpc/1/nested [
								forall nn [
									nn/1/upper: wpc
								]
							]
							write-log "insert new token"
							update-upper next wpc
							update-range next wpc nlines end-chars s-line s-column e-line e-column
							return true
						]
						first [
							unless any [
								pc = epc
								epc/1/upper = pc
							][return false]
							epos: lexer/line-pos? oline-stack e-line e-column
							npos: lexer/line-pos? oline-stack pc/1/range/2/x pc/1/range/2/y
							tail-str: copy/part epos npos
						]
						one [
							if epc/1/upper <> pc [return false]
							epos: lexer/line-pos? oline-stack e-line e-column
							npos: lexer/line-pos? oline-stack pc/1/range/2/x pc/1/range/2/y
							tail-str: copy/part epos npos
						]
						last [
							unless any [
								pc = epc
								epc/1/upper = pc
							][return false]
							if epc/1/upper = pc [
								epos: lexer/line-pos? oline-stack e-line e-column
								npos: lexer/line-pos? oline-stack pc/1/range/2/x pc/1/range/2/y
								tail-str: copy/part epos npos
							]
						]
						insert tail [
							if pc <> epc [return false]
						]
						mid [
							if pc <> epc [return false]
							unless parse text [any ws] [return false]
							write-log "remove token"
							update-upper/remove? next pc
							update-range next pc nlines end-chars s-line s-column e-line e-column
							remove-node pc
							return true
						]
						empty [return false]
					]
				][
					switch etag [
						head [
							if pc <> epc [return false]
							write-log rejoin ["transcode: " text]
							ntop: lexer/transcode text
							unless nested: ntop/1/nested [
								write-log "remove/insert spaces"
								update-range pc nlines end-chars s-line s-column e-line e-column
								return true
							]
							if 1 <> length? nested [return false]
							if nested/1/type = 'comment [
								if all [
									(length? ntop/1/lines) - 1 = nested/1/range/1/x
									e-line = wpc/1/range/1/x
								][return false]
							]
							do rebuild
							upper: wpc/1/upper
							insert/only wpc nested/1
							wpc/1/upper: upper
							if nn: wpc/1/nested [
								forall nn [
									nn/1/upper: wpc
								]
							]
							write-log "insert new token"
							update-upper next wpc
							update-range next wpc nlines end-chars s-line s-column e-line e-column
							return true
						]
						first one [
							if epc <> pc [return false]
							epos: lexer/line-pos? oline-stack e-line e-column
							npos: lexer/line-pos? oline-stack pc/1/range/2/x pc/1/range/2/y
							tail-str: copy/part epos npos
						]
						last insert tail [
							if epc <> pc [return false]
						]
						mid [
							if pc <> epc [return false]
							unless parse text [any ws] [return false]
							write-log "remove token"
							update-upper/remove? next pc
							update-range next pc nlines end-chars s-line s-column e-line e-column
							remove-node pc
							return true
						]
						empty [return false]
					]
				]
				do replace-node
				return true
			]
			;-- switch tag
			first [
				case [
					find all-path! pc/1/type [
						switch etag [
							head [return false]
							first [
								case [
									find all-path! epc/1/type [
										if pc <> epc [return false]
										spos: lexer/line-pos? oline-stack e-line e-column
										epos: lexer/line-pos? oline-stack pc/1/range/2/x pc/1/range/2/y
										tail-str: copy/part spos epos
									]
									epc/1/upper = pc [
										spos: lexer/line-pos? oline-stack e-line e-column
										epos: lexer/line-pos? oline-stack pc/1/range/2/x pc/1/range/2/y
										tail-str: copy/part spos epos
									]
									true [return false]
								]
							]
							one [
								if epc/1/upper <> pc [return false]
								spos: lexer/line-pos? oline-stack e-line e-column
								epos: lexer/line-pos? oline-stack pc/1/range/2/x pc/1/range/2/y
								tail-str: copy/part spos epos
							]
							last [
								either find all-path! epc/1/type [
									if pc <> epc [return false]
									;-- TBD: maybe need to check next pc, as last prior to mid
								][
									if epc/1/upper <> pc [return false]
									spos: lexer/line-pos? oline-stack e-line e-column
									epos: lexer/line-pos? oline-stack pc/1/range/2/x pc/1/range/2/y
									tail-str: copy/part spos epos
								]
							]
							insert tail [
								if pc <> epc [return false]
							]
							mid [
								if pc <> epc [return false]
								unless parse text [any ws][return false]
								write-log "remove token"
								update-upper/remove? next pc
								update-range next pc nlines end-chars s-line s-column e-line e-column
								remove-node pc
								return true
							]
							empty [return false]
						]
					]
					in-path? [
						wpc: pc/1/upper
						switch etag [
							head [return false]
							first one [
								if epc/1/upper <> wpc [return false]
								spos: lexer/line-pos? oline-stack wpc/1/range/1/x wpc/1/range/1/y
								epos: lexer/line-pos? oline-stack s-line s-column
								head-str: copy/part spos epos
								spos: lexer/line-pos? oline-stack e-line e-column
								epos: lexer/line-pos? oline-stack wpc/1/range/2/x wpc/1/range/2/y
								tail-str: copy/part spos epos
							]
							last [
								either find all-path! epc/1/type [
									if wpc <> epc [return false]
									spos: lexer/line-pos? oline-stack wpc/1/range/1/x wpc/1/range/1/y
									epos: lexer/line-pos? oline-stack s-line s-column
									head-str: copy/part spos epos
								][
									if epc/1/upper <> wpc [return false]
									spos: lexer/line-pos? oline-stack wpc/1/range/1/x wpc/1/range/1/y
									epos: lexer/line-pos? oline-stack s-line s-column
									head-str: copy/part spos epos
									spos: lexer/line-pos? oline-stack e-line e-column
									epos: lexer/line-pos? oline-stack wpc/1/range/2/x wpc/1/range/2/y
									tail-str: copy/part spos epos
								]
							]
							insert tail [
								if epc <> wpc [return false]
								spos: lexer/line-pos? oline-stack wpc/1/range/1/x wpc/1/range/1/y
								epos: lexer/line-pos? oline-stack s-line s-column
								head-str: copy/part spos epos
							]
							mid [return false]
							empty [return false]
						]
					]
					true [
						switch etag [
							head [return false]
							first one [
								if epc <> pc [return false]
								spos: lexer/line-pos? oline-stack e-line e-column
								epos: lexer/line-pos? oline-stack wpc/1/range/2/x wpc/1/range/2/y
								tail-str: copy/part spos epos
							]
							last insert tail [
								if epc <> pc [return false]
							]
							mid [
								if pc <> epc [return false]
								unless parse text [any ws][return false]
								write-log "remove token"
								update-upper/remove? next pc
								update-range next pc nlines end-chars s-line s-column e-line e-column
								remove-node pc
								return true
							]
							empty [return false]
						]
					]
				]
				do replace-node
				return true
			]
			;-- switch tag
			one [
				either in-path? [
					wpc: pc/1/upper
					switch etag [
						head [return false]
						one first [
							if epc/1/upper <> wpc [return false]
							spos: lexer/line-pos? oline-stack wpc/1/range/1/x wpc/1/range/1/y
							epos: lexer/line-pos? oline-stack s-line s-column
							head-str: copy/part spos epos
							spos: lexer/line-pos? oline-stack e-line e-column
							epos: lexer/line-pos? oline-stack wpc/1/range/2/x wpc/1/range/2/y
							tail-str: copy/part spos epos
						]
						last [
							either find all-path! epc/1/type [
								if wpc <> epc [return false]
								spos: lexer/line-pos? oline-stack wpc/1/range/1/x wpc/1/range/1/y
								epos: lexer/line-pos? oline-stack s-line s-column
								head-str: copy/part spos epos
							][
								if epc/1/upper <> wpc [return false]
								spos: lexer/line-pos? oline-stack wpc/1/range/1/x wpc/1/range/1/y
								epos: lexer/line-pos? oline-stack s-line s-column
								head-str: copy/part spos epos
								spos: lexer/line-pos? oline-stack e-line e-column
								epos: lexer/line-pos? oline-stack wpc/1/range/2/x wpc/1/range/2/y
								tail-str: copy/part spos epos
							]
						]
						insert tail [
							if epc <> wpc [return false]
							spos: lexer/line-pos? oline-stack wpc/1/range/1/x wpc/1/range/1/y
							epos: lexer/line-pos? oline-stack s-line s-column
							head-str: copy/part spos epos
						]
						mid empty [return false]
					]
				][
					switch etag [
						head first [return false]
						one [
							if epc <> pc [return false]
							spos: lexer/line-pos? oline-stack pc/1/range/1/x pc/1/range/1/y
							epos: lexer/line-pos? oline-stack s-line s-column
							head-str: copy/part spos epos
							spos: lexer/line-pos? oline-stack e-line e-column
							epos: lexer/line-pos? oline-stack pc/1/range/2/x pc/1/range/2/y
							tail-str: copy/part spos epos
						]
						last insert tail [
							if epc <> pc [return false]
							spos: lexer/line-pos? oline-stack pc/1/range/1/x pc/1/range/1/y
							epos: lexer/line-pos? oline-stack s-line s-column
							head-str: copy/part spos epos
						]
						mid empty [return false]
					]
				]
				do replace-node
				return true
			]
			;-- switch tag
			last [
				case [
					find all-path! pc/1/type [
						switch etag [
							head first one [return false]
							last insert tail [
								if epc <> pc [return false]
								spos: lexer/line-pos? oline-stack wpc/1/range/1/x wpc/1/range/1/y
								epos: lexer/line-pos? oline-stack s-line s-column
								head-str: copy/part spos epos
							]
							mid empty [return false]
						]
					]
					in-path? [
						wpc: pc/1/upper
						switch etag [
							head [return false]
							first one [
								if epc/1/upper <> wpc [return false]
								spos: lexer/line-pos? oline-stack wpc/1/range/1/x wpc/1/range/1/y
								epos: lexer/line-pos? oline-stack s-line s-column
								head-str: copy/part spos epos
								spos: lexer/line-pos? oline-stack e-line e-column
								epos: lexer/line-pos? oline-stack wpc/1/range/2/x wpc/1/range/2/y
								tail-str: copy/part spos epos
							]
							last [
								either all [
									xtype: epc/1/upper/1/type
									find all-path! xtype
								][
									if epc/1/upper <> wpc [return false]
									spos: lexer/line-pos? oline-stack wpc/1/range/1/x wpc/1/range/1/y
									epos: lexer/line-pos? oline-stack s-line s-column
									head-str: copy/part spos epos
									spos: lexer/line-pos? oline-stack e-line e-column
									epos: lexer/line-pos? oline-stack wpc/1/range/2/x wpc/1/range/2/y
									tail-str: copy/part spos epos
								][
									if epc <> wpc [return false]
									spos: lexer/line-pos? oline-stack wpc/1/range/1/x wpc/1/range/1/y
									epos: lexer/line-pos? oline-stack s-line s-column
									head-str: copy/part spos epos
								]
							]
							insert tail [
								if epc <> wpc [return false]
								spos: lexer/line-pos? oline-stack wpc/1/range/1/x wpc/1/range/1/y
								epos: lexer/line-pos? oline-stack s-line s-column
								head-str: copy/part spos epos
							]
							mid empty [return false]
						]
					]
					true [
						switch etag [
							head first one [return false]
							last insert tail [
								if pc <> epc [return false]
								spos: lexer/line-pos? oline-stack wpc/1/range/1/x wpc/1/range/1/y
								epos: lexer/line-pos? oline-stack s-line s-column
								head-str: copy/part spos epos
							]
							mid empty [return false]
						]
					]
				]
				do replace-node
				return true
			]
			;-- switch tag
			mid [
				switch etag [
					head first one [return false]
					last insert tail [
						if epc <> wpc: next pc [return false]
						unless parse text [any ws][return false]
						write-log "remove token"
						update-upper/remove? next wpc
						update-range next wpc nlines end-chars s-line s-column e-line e-column
						remove-node wpc
						return true
					]
					mid [
						if epc <> pc [return false]
						unless parse text [any ws][return false]
						write-log "insert spaces"
						update-range next pc nlines end-chars s-line s-column e-line e-column
						return true
					]
					empty [return false]
				]
			]
			;-- switch tag
			insert [
				wpc: next pc
				npc: next pc
				either find all-path! npc/1/type [
					switch etag [
						head [return false]
						first [
							unless any [
								epc = npc
								epc/1/upper = npc
							][return false]
							epos: lexer/line-pos? oline-stack e-line e-column
							npos: lexer/line-pos? oline-stack npc/1/range/2/x npc/1/range/2/y
							tail-str: copy/part epos npos
						]
						one [
							if epc/1/upper <> npc [return false]
							epos: lexer/line-pos? oline-stack e-line e-column
							npos: lexer/line-pos? oline-stack npc/1/range/2/x npc/1/range/2/y
							tail-str: copy/part epos npos
						]
						last [
							unless any [
								epc = npc
								epc/1/upper = npc
							][return false]
							if epc/1/upper = npc [
								epos: lexer/line-pos? oline-stack e-line e-column
								npos: lexer/line-pos? oline-stack npc/1/range/2/x npc/1/range/2/y
								tail-str: copy/part epos npos
							]
						]
						insert [
							unless any [
								epc = npc
								epc = pc
							][return false]
							if epc = pc [
								upper: pc/1/upper
								write-log rejoin ["transcode: " text]
								ntop: lexer/transcode text
								unless nested: ntop/1/nested [
									write-log "remove/insert spaces"
									update-range next pc nlines end-chars s-line s-column e-line e-column
									return true
								]
								if 1 <> length? nested [return false]
								if nested/1/type = 'comment [
									if all [
										(length? ntop/1/lines) - 1 = nested/1/range/1/x
										e-line = upper/1/range/2/x
									][return false]
								]
								do rebuild
								insert/only next pc nested/1
								pc/2/upper: upper
								if nn: pc/2/nested [
									forall nn [
										nn/1/upper: next pc
									]
								]
								write-log "insert new token"
								update-upper npc: skip pc 2
								update-range npc nlines end-chars s-line s-column e-line e-column
								return true
							]
						]
						tail [
							if npc <> epc [return false]
						]
						mid [
							if npc <> epc [return false]
							unless parse text [any ws] [return false]
							write-log "remove token"
							update-upper/remove? next npc
							update-range next npc nlines end-chars s-line s-column e-line e-column
							remove-node npc
							return true
						]
						empty [return false]
					]
				][
					switch etag [
						head [return false]
						first one [
							if epc <> npc [return false]
							epos: lexer/line-pos? oline-stack e-line e-column
							npos: lexer/line-pos? oline-stack npc/1/range/2/x npc/1/range/2/y
							tail-str: copy/part epos npos
						]
						last [
							if epc <> npc [return false]
						]
						insert [
							unless any [
								epc = npc
								epc = pc
							][return false]
							if epc = pc [
								upper: pc/1/upper
								write-log rejoin ["transcode: " text]
								ntop: lexer/transcode text
								unless nested: ntop/1/nested [
									write-log "remove/insert spaces"
									update-range next pc nlines end-chars s-line s-column e-line e-column
									return true
								]
								if 1 <> length? nested [return false]
								if nested/1/type = 'comment [
									if all [
										(length? ntop/1/lines) - 1 = nested/1/range/1/x
										e-line = upper/1/range/2/x
									][return false]
								]
								do rebuild
								insert/only next pc nested/1
								pc/2/upper: upper
								if nn: pc/2/nested [
									forall nn [
										nn/1/upper: next pc
									]
								]
								write-log "insert new token"
								update-upper npc: skip pc 2
								update-range npc nlines end-chars s-line s-column e-line e-column
								return true
							]
						]
						tail [
							if epc <> npc [return false]
						]
						mid [
							if npc <> epc [return false]
							unless parse text [any ws] [return false]
							write-log "remove token"
							update-upper/remove? next npc
							update-range next npc nlines end-chars s-line s-column e-line e-column
							remove-node npc
							return true
						]
						empty [return false]
					]
				]
				do replace-node
				return true
			]
			;-- switch tag
			tail [
				if etag <> 'tail [return false]
				if epc <> pc [return false]
				upper: pc/1/upper
				write-log rejoin ["transcode: " text]
				ntop: lexer/transcode text
				unless nested: ntop/1/nested [
					write-log "remove/insert spaces"
					update-range next pc nlines end-chars s-line s-column e-line e-column
					return true
				]
				if 1 <> length? nested [return false]
				if nested/1/type = 'comment [
					if all [
						(length? ntop/1/lines) - 1 = nested/1/range/1/x
						e-line = upper/1/range/2/x
					][return false]
				]
				do rebuild
				append/only pc nested/1
				pc/2/upper: upper
				if nn: pc/2/nested [
					forall nn [
						nn/1/upper: next pc
					]
				]
				write-log "append new token"
				update-range skip pc 2 nlines end-chars s-line s-column e-line e-column
				return true
			]
			empty [
				if etag <> 'empty [return false]
				if pc <> epc [return flase]
				write-log rejoin ["transcode: " text]
				ntop: lexer/transcode text
				unless nested: ntop/1/nested [
					write-log "remove/insert spaces"
					update-range next wpc nlines end-chars s-line s-column e-line e-column
					update-range/only wpc nlines end-chars s-line s-column e-line e-column
					return true
				]
				if 1 <> length? nested [return false]
				if nested/1/type = 'comment [
					if all [
						(length? ntop/1/lines) - 1 = nested/1/range/1/x
						e-line = wpc/1/range/1/x
					][return false]
				]
				do rebuild
				either find wpc/1 'nested [
					wpc/1/nested: reduce [nested/1]
				][
					repend/only wpc/1 ['nested reduce [nested/1]]
				]
				wnested: wpc/1/nested
				wnested/1/upper: wpc
				if nn: wnested/1/nested [
					forall nn [
						nn/1/upper: wnested
					]
				]
				write-log "insert new token"
				update-range next wpc nlines end-chars s-line s-column e-line e-column
				update-range/only wpc nlines end-chars s-line s-column e-line e-column
				return true
			]
		]
		false
	]

	tags: [head first one last mid insert tail empty]
	ws: charset " ^M^/^-"
	update-source: function [uri [string!] changes [block!]][
		unless ext: find/last/tail uri "." [return false]
		unless any [ext = "red" ext = "reds"][return false]
		clear diagnostics
		unless top: find-top uri [
			return false
		]
		forall changes [
			;write-log lexer/sformat top
			code: top/1/source
			oline-stack: top/1/lines
			range: changes/1/range
			text: changes/1/text
			rangeLength: changes/1/rangeLength
			s-line: range/start/line + 1
			s-column: range/start/character + 1
			e-line: range/end/line + 1
			e-column: range/end/character + 1
			spos: lexer/line-pos? oline-stack s-line s-column
			epos: lexer/line-pos? oline-stack e-line e-column
			otext: copy/part spos epos
			ncode: copy/part code spos
			append ncode text
			append ncode epos
			line-stack: make block! 100
			lexer/parse-line line-stack ncode
			if all [
				empty? otext
				empty? text
			][continue]
			write-log mold reduce [s-line s-column e-line e-column]
			write-log rejoin ["remove: " mold otext]
			write-log rejoin ["add: " mold text]
			if otext = text [continue]
			if top/1/nested [
				spcs: epcs: position? top s-line s-column
				if any [
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
					top: add-source-force uri ncode
					add-include-file top 1
					continue
				]
				write-log mold reduce [spcs/1 epcs/1]
				unless all [
					find tags spcs/1
					find tags epcs/1
				][
					write-log "position failed 2"
					top: add-source-force uri ncode
					add-include-file top 1
					continue
				]

				if update-token spcs/1 spcs/2 epcs/1 epcs/2
								otext text oline-stack line-stack
								s-line s-column e-line e-column [
					top/1/source: ncode
					top/1/lines: line-stack
					continue
				]
			]
			write-log "diff failed"
			top: add-source-force uri ncode
			add-include-file top 1
		]
		;write-log lexer/sformat top
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

	unique2?: function [specs [block!] word [word!]][
		forall specs [
			npc: specs/1/2
			if word = to word! npc/1/expr/1 [return false]
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
						collect* to word! npc/1/expr/1 npc
					]
					all [
						npc/1/type = issue!
						'define = to word! npc/1/expr/1
						npc/2
						word! = npc/2/type
					][
						collect* npc/2/expr/1 next npc
					]
					all [
						npc/1/type = issue!
						'enum = to word! npc/1/expr/1
						npc/2
						word! = npc/2/type
						npc/3
						block! = npc/3/type
						epc: npc/3/nested
					][
						collect* to word! npc/2/expr/1 next npc
						forall epc [
							if any [
								word! = epc/1/type
								set-word! = epc/1/type
							][
								collect* to word! epc/1/expr/1 epc
							]
						]
					]
					all [
						npc/1/type = issue!
						'if = to word! npc/1/expr/1
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
						'either = to word! npc/1/expr/1
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
						'switch = to word! npc/1/expr/1
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
						'import = to word! npc/1/expr/1
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
					npc/1/expr <> [/local]
				][
					collect* to word! npc/1/expr/1 npc
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
					find [func function has] par/-2/expr/1
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

	collect-word: function [top [block!] pc [block!]][
		result: make block! 4
		word: to word! pc/1/expr/1
		collect-word* pc word result no
		sources: semantic/sources
		forall sources [
			if all [
				sources/1 <> top
				sources/1/1/ftype = top/1/ftype
				nested: sources/1/1/nested
			][
				collect-word* back tail nested word result no
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
					find [context object] pc/1/expr/1
					block! = pc/2/type
					spec: pc/2
				]
				all [
					word! = pc/1/type
					pc/1/expr/1 = 'make
					pc/3
					block! = pc/3/type
					spec: pc/3
					any [
						all [
							word! = pc/2/type
							pc/2/expr/1 = 'object!
						]
						all [
							word! = pc/2/type
							pc/2/expr/1 <> to word! opc/1/expr/1
							res: find-set?/*context? next pc pc/2/expr/1 upper no
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
			find [func function has does] pc/1/expr/1
			block! = pc/2/type
			any [
				all [
					find [func function] pc/1/expr/1
					pc/3
					block! = pc/3/type
					spec: pc/2
				]
				pc/1/expr/1 = 'does
				all [
					pc/1/expr/1 = 'has
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
				word = to word! npc/1/expr/1
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
				'if = to word! npc/1/expr/1
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
				'either = to word! npc/1/expr/1
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
				'switch = to word! npc/1/expr/1
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
				'import = to word! npc/1/expr/1
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
				'define = to word! npc/1/expr/1
				npc/2
				word! = npc/2/type
				word = npc/2/expr/1
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
				'enum = to word! npc/1/expr/1
				npc/2
				word! = npc/2/type
				npc/3
				npc/3/type = block!
				nested: npc/3/nested
			][
				if word = npc/2/expr/1 [
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
							word = nested/1/expr/1
						]
						all [
							set-word! = nested/1/type
							word = to word! nested/1/expr/1
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
		system?: top/1/ftype = 'reds
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
		if empty? string: to string! to word! pc/1/expr/1 [
			exit
		]
		result: collect-word top pc
		forall result [
			rpc: result/1
			top: rpc
			while [par: top/1/upper][top: par]
			kind: CompletionItemKind/Variable
			type: rpc/1/type
			rstring: to string! to word! rpc/1/expr/1
			case [
				find [word! lit-word! refinement!] to word! type [
					kind: CompletionItemKind/Field
				]
				type = set-word! [
					ret: find-set?/*any? rpc to word! rpc/1/expr/1 no no
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
									'import = to word! par2/-1/expr/1
								][
									kind: CompletionItemKind/Module
								]
							]
						]
					]
				]
				type = word! [
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
						unique2? result to word! npc/1/expr/1
					]
				][
					if 'local = to word! npc/1/expr/1 [break]
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
						unique2? result to word! npc/1/expr/1
					]
				][
					unless empty? ret: find-set?/*any? npc to word! npc/1/expr/1 false no [
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
					any-word? npc/1/expr/1
					any [
						*all?
						unique2? result to word! npc/1/expr/1
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
					set-word? npc/1/expr/1
					any [
						*all?
						unique2? result to word! npc/1/expr/1
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
						if word = to word! npc/1/expr/1 [
							unless empty? specs: find-set?/*any? npc word false no [
								append result specs
								unless *all? [return result]
							]
						]
					][
						if all [
							end?
							find/match to string! npc/1/expr/1 string
						][
							unless empty? specs: find-set?/*any? npc to word! npc/1/expr/1 false no [
								append result specs
							]
						]
						if all [
							slash-end?
							word = to word! npc/1/expr/1
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
						any-word? npc/1/expr/1
						any [
							*all?
							unique2? result to word! npc/1/expr/1
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
							if word = to word! npc/1/expr/1 [
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
							find/match to string! npc/1/expr/1 string
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
							word = to word! npc/1/expr/1
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
						unique2? result to word! npc/1/expr/1
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
						if word = to word! npc/1/expr/1 [
							if npc/1/expr = [/local] [exit]
							repend/only result ['ref npc make block! 1]
							unless *all? [return result]
						]
						continue
					]
					if slash-end? [
						if 'local = to word! npc/1/expr/1 [exit]
						repend/only result ['ref npc make block! 1]
					]
					if end? [
						if find/match to string! npc/1/expr/1 string [
							if npc/1/expr = [/local] [exit]
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

	collect-path: function [top [block!] pc [block!] path [block!] *all? [logic!] match? [logic!]][
		specs: make block! 8
		ret: collect-path* pc path *all? match?
		if 0 < length? ret [
			append specs ret
			unless *all? [return specs]
		]
		sources: semantic/sources
		forall sources [
			if all [
				sources/1 <> top
				sources/1/1/ftype = top/1/ftype
				nested: sources/1/1/nested
			][
				ret: collect-path* back tail nested path *all? match?
				if 0 < length? ret [
					append specs ret
					unless *all? [return specs]
				]
			]
		]
		specs
	]

	complete-path: function [top [block!] pc [block!] comps [block!]][
		complete-sys-path: function [][
			unless system-words/keyword? no fword [exit]
			pure-path: to string! to path! path
			either slash-end? [
				append pure-path "/"
				tstr: copy pure-path
			][
				npath: copy path
				remove back tail npath
				tstr: to string! to path! npath
				append tstr "/"
			]
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
						'path rejoin [tstr nstring]
						'type "keypath"
					]
				]
			]
		]

		unless path: gain-path pc [exit]
		paths: copy path
		upper: pc/1/upper
		range: lexer/form-range upper/1/range
		either all [
			upper/1/error
			upper/1/error/code = 'slash
		][
			slash-end?: yes
			append paths '/
			range/start/character: range/end/character
		][
			slash-end?: no
			range/start/character: range/end/character - (pc/1/range/2/y - pc/1/range/1/y)
		]
		fword: to word! paths/1
		filter: to string! last paths

		pcs: collect-path top pc paths no no
		forall pcs [
			type: pcs/1/1
			npc: pcs/1/2
			words: pcs/1/3
			ntop: npc
			while [par: ntop/1/upper][ntop: par]
			nstring: to string! npc/1/expr/1
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
		unless pcs: semantic/position? top line column [return none]
		if pcs/1 <> 'last [return none]
		pc: pcs/2
		if pc/1/type = 'comment [return none]
		comps: clear last-comps
		if find [path! lit-path! get-path!] to word! pc/1/type [
			unless all [
				pc/1/error
				pc/1/error/code = 'slash
			][return none]
			complete-path top back tail pc/1/nested comps
			return comps
		]
		upper: pc/1/upper
		type: upper/1/type
		in-path?: no
		if all [upper type][
			in-path?: find [path! lit-path! get-path!] to word! type
		]
		if in-path? [
			complete-path top pc comps
			return comps
		]
		if pc/1/type = file! [
			complete-file top pc comps
			return comps
		]
		if find [word! lit-word! get-word!] to word! pc/1/type [
			complete-word top pc comps
			return comps
		]
		comps
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
			append ret pc/1/expr/1
		]
		ret
	]

	get-func-spec: function [pc [block!]][
		get-func-block: function [pc [block!]][
			ret: make block! 4
			forall pc [
				if all [
					refinement! = pc/1/type
					pc/1/expr = [/local]
				][return ret]
				if find [block! map! paren!] to word! pc/1/type [
					append/only ret make pc/1/type
						either pc/1/nested [
							get-func-block pc/1/nested
						][[]]
					continue
				]
				append ret pc/1/expr/1
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
		system?: top/1/ftype = 'reds
		resolve-word*: function [][
			if all [
				set-word! = pc/1/type
				pc/2
			][
				unless ret: find-set?/*any? pc to word! pc/1/expr/1 no no [
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
								find [func function] fn: upper/-1/expr/1
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
							find [func function] fn: upper/-1/expr/1
						][
							return func-info fn get-func-spec upper/1/nested to string! pc/1/expr/1
						]
						return func-info 'func [] to string! pc/1/expr/1
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
							par2/-1/expr/1 = to issue! 'import
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
								string " is import form " to string! par1/-2/expr/1
								"^/prototype: " npc/2/expr/1
							]
							if desc [
								append ret rejoin ["^/" form-func-spec desc]
							]
							return ret
						]
						if word! = specs/1/1/type [
							return rejoin [string ": " mold specs/1/1/expr/1]
						]
						return rejoin [string " is a " mold specs/1/1/type " variable."]
					]
				]
			]
			if all [
				word! = pc/1/type
				pc/-1
				pc/-1/expr
				pc/-1/expr/1 = to issue! 'define
			][
				return rejoin [string " is a #define macro."]
			]
			if all [
				word! = pc/1/type
				pc/-1
				pc/-1/expr
				pc/-1/expr/1 = to issue! 'enum
			][
				return rejoin [string " is a #enum type."]
			]
			if all [
				word! = pc/1/type
				upper: pc/1/upper
				upper/-2
				upper/-2/expr/1 = to issue! 'enum
			][
				return rejoin [string " is a #enum value: " mold index? pc]
			]
			if all [
				none? itype
				upper: pc/1/upper
				upper/-1
				upper/-1/type = word!
				find [func function has] upper/-1/expr/1
			][
				if upper/-1/expr/1 = 'has [
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
							return rejoin [string " is a block item!^/next value: " mold pc/2/expr/1]
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
		result: make block! 4
		collect-word*/match? pc word result *all?
		if all [
			not *all?
			0 < length? result
		][return result]
		sources: semantic/sources
		forall sources [
			if all [
				sources/1 <> top
				sources/1/1/ftype = top/1/ftype
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
		result
	]

	hover-word: function [top [block!] pc [block!] word [word!]][
		result: hover-word* top pc word no
		if 0 = length? result [return none]
		forall result [
			unless set-word! = result/1/1/type [
				pc: result/1
				top: get-top pc
				return resolve-word top pc to string! pc/1/expr/1 none
			]
		]
		pc: result/1
		top: get-top pc
		resolve-word top pc to string! pc/1/expr/1 none
	]

	hover-path: function [top [block!] pc [block!] path [block!]][
		result: collect-path top pc path no yes
		if 0 = length? result [return none]
		pc: result/1/2
		top: get-top pc
		resolve-word top pc to string! pc/1/expr/1 result/1/1
	]

	get-pos-info: function [uri [string!] line [integer!] column [integer!]][
		unless top: semantic/find-top uri [return none]
		unless pcs: semantic/position? top line column [
			return none
		]
		pc: pcs/2
		unless find [one first last mid] pcs/1 [return none]
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
			insert res pc/1/expr/1
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
		type: pc/1/type
		if type = 'comment [
			return "comment!"
		]
		if type = file! [
			return rejoin [mold type " : " form/part pc/1/expr/1 60]
		]
		wtype: to word! type
		if find [block! paren! map! path! lit-path! get-path! set-path!] wtype [
			return mold type
		]
		unless find [word! get-word! set-word!] wtype [
			return rejoin [mold type " : " mold/part pc/1/expr/1 60]
		]
		if ret: hover-word top pc word: to word! pc/1/expr/1 [return ret]
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
		result: collect-path top pc path yes yes
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

	definition-file: function [top [block!] file [file!]][
		ret: make block! 2
		if #"/" = first file [
			unless exists? file [return none]
			if dir? file [return none]
			append ret make map! reduce [
				'uri lexer/file-to-uri file
				'range lexer/form-range [1x1 1x1]
			]
			return ret
		]
		origin-file: lexer/uri-to-file top/1/uri
		tfile: find/tail/last origin-file "/"
		origin-dir: copy/part origin-file tfile
		nfile: semantic/related-file origin-dir file
		if all [
			nfile
			exists? nfile
			not dir? nfile
		][
			append ret make map! reduce [
				'uri lexer/file-to-uri nfile
				'range lexer/form-range [1x1 1x1]
			]
			return ret
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
		type: pc/1/type
		if type = file! [
			return definition-file top pc/1/expr/1
		]
		wtype: to word! type
		if find [block! paren! map! path! lit-path! get-path! set-path!] wtype [
			return none
		]
		if find [word! get-word! set-word!] wtype [
			return definition-word top pc to word! pc/1/expr/1
		]
		none
	]

	unique3?: function [specs [block!] str [string!]][
		forall specs [
			if str = specs/1/name [return false]
		]
		true
	]

	symbols: function [uri [string!]][
		unless top: semantic/find-top uri [return none]
		unless nested: top/1/nested [return none]
		symbols*: function [npc [block!] depth [integer!]][
			result: make block! 4
			until [
				if all [
					set-word! = npc/1/type
					specs: find-set?/*any? npc to word! npc/1/expr/1 no no
					not empty? specs
					unique3? result to string! npc/1/expr/1
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
									'name		to string! pc/1/expr/1
									'detail		rejoin [mold pc/1/expr/1 " is a context"]
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
									'name		to string! pc/1/expr/1
									'detail		rejoin [mold pc/1/expr/1 " is a function"]
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
								'name		to string! pc/1/expr/1
								'detail		rejoin [mold pc/1/expr/1 " is a value"]
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
		symbols* back tail nested 0
	]
]
