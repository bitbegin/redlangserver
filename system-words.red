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

	;-- for speed up
	func-spec: help-ctx/func-spec-ctx/parse-func-spec do to get-word! 'func
	has-spec: help-ctx/func-spec-ctx/parse-func-spec do to get-word! 'has
	does-spec: help-ctx/func-spec-ctx/parse-func-spec do to get-word! 'does
	function-spec: help-ctx/func-spec-ctx/parse-func-spec do to get-word! 'function
	context-spec: help-ctx/func-spec-ctx/parse-func-spec do to get-word! 'context
	do-spec: help-ctx/func-spec-ctx/parse-func-spec do to get-word! 'do
	bind-spec: help-ctx/func-spec-ctx/parse-func-spec do to get-word! 'bind
	all-spec: help-ctx/func-spec-ctx/parse-func-spec do to get-word! 'all
	any-spec: help-ctx/func-spec-ctx/parse-func-spec do to get-word! 'any

	get-spec: function [word [word!]][
		if find [func has does function context do bind all any] word [
			spec: to word! append to string! word "-spec"
			return do spec
		]
		either find system-words word [
			help-ctx/func-spec-ctx/parse-func-spec do to get-word! word
		][none]
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
