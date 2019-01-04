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

	get-spec: func [word [word!] /local type info args refines returns lines][
		type: type? get word
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

	get-completions: function [str [string! none!]][
		if any [
			none? str
			empty? str
		][return none]
		result: make block! 4
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
