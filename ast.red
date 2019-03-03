Red [
	Title:   "Red lexer for Red language server"
	Author:  "bitbegin"
	File: 	 %ast.red
	Tabs:	 4
	Rights:  "Copyright (C) 2011-2019 Red Foundation. All rights reserved."
	License: "BSD-3 - https://github.com/red/red/blob/origin/BSD-3-License.txt"
]

#include %lexer.red

ast: context [
	form-pos: function [pos [string!]][
		start: end: head pos
		line: 0
		while [
			not all [
				(index? pos) >= (index? start)
				(index? pos) < (index? end)
			]
		][
			line: line + 1
			start: end
			unless end: find/tail start #"^/" [
				end: tail start break
			]
		]
		if line = 0 [line: 1]
		column: (index? pos) - (index? start)
		reduce [line column + 1]
	]

	to-pos: function [src [string!] line [integer!] column [integer!]][
		start: end: src
		cnt: 0
		until [
			cnt: cnt + 1
			start: end
			unless end: find/tail start #"^/" [
				end: tail start break
			]
			if line <= cnt [break]
		]
		if line <> cnt [return end]
		len: (index? end) - (index? start)
		if column > len [return end]
		skip start column - 1
	]

	to-range: function [start [block!] end [block!] /keep][
		make map! reduce [
			'start make map! reduce [
				'line either keep [start/1][start/1 - 1]
				'character either keep [start/2][start/2 - 1]
			]
			'end make map! reduce [
				'line either keep [end/1][end/1 - 1]
				'character either keep [end/2][end/2 - 1]
			]
		]
	]

	analysis: function [src [string!] allow-slash [logic!]][
		ast: make block! 1
		res: lexer/transcode/ast src none true allow-slash ast
		if error? res/3 [
			return make map! reduce ['pos form-pos res/2 'error res/3]
		]
		repend ast/1 ['source src]
		ast
	]
]
