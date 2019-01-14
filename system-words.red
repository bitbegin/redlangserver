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

	append-last: function [blk [block!] v][
		if block? l: last blk [
			append l v
			exit
		]
		if none? l [
			append/only blk reduce [v]
			exit
		]
		remove back tail blk
		append/only blk reduce [l v]
	]

	get-spec: function [word [word!] field [word!]][
		type: type? get word
		unless any [
			type = action!
			type = native!
			type = function!
			type = routine!
			type = op!
		][return none]
		info: get-word-info word
		switch field [
			args [		
				if parse info [thru "ARGUMENTS:^/" to word-char copy blk to ["^/^/" | "REFINEMENTS:^/" | "RETURNS:^/" | end] thru end][
					lines: split blk "^/"
					forall lines [
						clear find lines/1 "^""
					]
					blk: clear []
					forall lines [
						args: load lines/1
						either block? args [
							unless empty? args [
								append/only blk args
							]
						][
							append/only blk reduce [args]
						]
					]
					return blk
				]
			]
			refines [
				if parse info [thru "REFINEMENTS:^/" to word-char copy blk to ["^/^/" | "RETURNS:^/" | end] thru end][
					lines: split blk "^/"
					forall lines [
						clear find lines/1 "^""
						clear find lines/1 "=>"
					]
					blk: clear []
					forall lines [
						refs: load lines/1
						case [
							refinement? refs [
								append/only blk reduce [refs]
							]
							any [
								word? refs
								block? refs
							][
								append-last blk refs
							]
						]
					]
					return blk
				]
			]
			returns [
				if parse info [thru "RETURNS:^/" to word-char copy blk to ["^/^/" | end] thru end][
					return load blk
				]
			]
		]
		none
	]

	form-completion: function [completions [block!]][
		either 1 = length? completions [
			comp: either #"/" = last completions/1 [
				copy/part completions/1 (length? completions/1) - 1
			][completions/1]
			unless res: find/last/tail comp #"/" [res: comp]
			res
		][completions]
	]

	get-completions: function [str [string! none!]][
		if any [
			none? str
			empty? str
		][return none]
		result: make block! 4
		completions: none
		item: none
		case [
			all [
				#"%" = str/1
				1 < length? str
			][
				append result 'file
				completions: red-complete-ctx/red-complete-file str no
				append result form-completion completions
			]
			all [
				#"/" <> str/1
				ptr: find str #"/"
				find system-words to word! copy/part str ptr
			][
				append result 'path
				completions: red-complete-ctx/red-complete-path str no
				append result form-completion completions
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
