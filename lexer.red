Red [
	Title:   "Red lexer for Red language server"
	Author:  "bitbegin"
	File: 	 %lexer.red
	Tabs:	 4
	Rights:  "Copyright (C) 2011-2019 Red Foundation. All rights reserved."
	License: "BSD-3 - https://github.com/red/red/blob/origin/BSD-3-License.txt"
]

red-lexer: context [
	words-table: make block! 100

	whitespace?: func [c [char!]][
		either any [
			c = #"^/"
			c = #" "
			c = #"^-"
		][true][false]
	]

	analysis: func [file [file!] source [string!]
		/local words pos npos npos2 out
	][
		either words: select words-table file! [
			clear words
		][
			words: make block! 10000
		]
		append/only words-table reduce [file source words]
		pos: source
		out: make block! 1
		until [
			if error? npos: try [system/lexer/transcode/one pos clear out false][
				append/only words reduce [index? pos npos]
				return false
			]
			npos2: back npos
			if whitespace? npos2/1 [
				while [whitespace? npos2/1][
					npos2: back npos2
				]
			]
			append/only words reduce [out/1 index? pos index? npos2 []]
			pos: npos
			tail? pos
		]
		true
	]
]
