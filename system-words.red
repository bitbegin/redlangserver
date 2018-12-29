Red [
	Title:   "Red system-words for Red language server"
	Author:  "bitbegin"
	File: 	 %system-words.red
	Tabs:	 4
	Rights:  "Copyright (C) 2011-2019 Red Foundation. All rights reserved."
	License: "BSD-3 - https://github.com/red/red/blob/origin/BSD-3-License.txt"
]

system-words: context [
	get-words: has [sys words] [
		sys: words-of system/words
		words: make block! length? sys
		forall sys [
			if value? sys/1 [
				append words sys/1
			]
		]
		words
	]
	system-words: get-words

	get-word-info: func [word [word!]][
		either find system-words word [
			help-string :word
		][none]
	]

	ws: charset " ^-^M"
	word-char: complement charset {/\^^,[](){}"#%$@:;}

	;-- datatype! or typeset!
	get-data-types: func [type [word!] /local info out][
		info: get-word-info type
		info: split info "^/"
		out: make block! 30
		forall info [
			trim/head info/1
			if parse info/1 [to word-char copy type thru #"!" e: thru end][
				unless empty? type [
					append out to word! type
				]
			]
		]
		out
	]

	get-typeset: func [type [word!] /local info out types blk][
		info: get-word-info type
		out: make block! 30
		parse info [thru "make typeset! [" copy types to "]" thru end
			(blk: split types ws
				forall blk [
					unless empty? blk/1 [
						append out to word! blk/1
					]
				]
			)
		]
		out
	]

	get-typesets: has [types out][
		types: get-data-types 'typeset!
		out: make block! 60
		forall types [
			append out reduce [types/1 get-typeset types/1]
		]
		out
	]

	base-types: get-data-types 'datatype!
	typesets: get-typesets

	get-type: func [word [word!]][type? get word]

	get-spec: func [word [word!] /local type info args refines returns lines][
		type: get-type word
		unless any [
			type = action!
			type = native!
			type = function!
			type = routine!
			type = op!
		][return none]
		info: get-word-info word
		args: either parse info [thru "ARGUMENTS:^/" to word-char copy blk to ["^/^/" | "REFINEMENTS:^/" | "RETURNS:^/" | end] thru end][
			lines: split blk "^/"
			forall lines [
				clear find lines/1 "^""
			]
			blk: clear []
			forall lines [
				append/only blk load lines/1
			]
			blk
		][none]
		refines: either parse info [thru "REFINEMENTS:^/" to word-char copy blk to ["^/^/" | "RETURNS:^/" | end] thru end][
			lines: split blk "^/"
			forall lines [
				clear find lines/1 "^""
				clear find lines/1 "=>"
			]
			blk: clear []
			forall lines [
				append blk load lines/1
			]
			blk
		][none]
		returns: either parse info [thru "RETURNS:^/" to word-char copy blk to ["^/^/" | end] thru end][
			load blk
		][none]
		reduce [info args refines returns]
	]

	get-completions: func [str [string! none!] /local result sys-word ptr][
		result: make block! 4
		if any [
			none? str
			empty? str
		][return result]
		case [
			all [
				#"%" = str/1
				1 < length? str
			][
				append result 'file
				append result red-complete-ctx/red-complete-file str no
			]
			all [
				#"/" <> str/1
				ptr: find str #"/"
				find system-words to word! copy/part str ptr
			][
				append result 'path
				append result red-complete-ctx/red-complete-path str no
			]
			true [
				append result 'word
				forall system-words [
					sys-word: mold system-words/1
					if find/match sys-word str [
						append result sys-word
					]
				]
			]
		]
		result
	]
]
