Red [
	Title:   "Red lexer for Red language server"
	Author:  "bitbegin"
	File: 	 %lexer.red
	Tabs:	 4
	Rights:  "Copyright (C) 2011-2019 Red Foundation. All rights reserved."
	License: "BSD-3 - https://github.com/red/red/blob/origin/BSD-3-License.txt"
]

#include %lexer.red

ast-lexer: context [

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

	form-range: function [range [block!]][
		start: reduce [range/1 range/2]
		end: reduce [range/3 range/4]
		to-range start end
	]

	analysis: function [start [string!]][
		code: make block! 1000
		ast: make block! 1000
		top: reduce ['expr code 's index? start 'e index? back tail start 'nested ast 'source start]
		res: lexer/transcode/ast start code true ast
		if error? res/3 [
			return make map! reduce ['pos form-pos res/2 'error res/3 'stack top]
		]
		append top reduce ['max-depth res/4]
		reduce [top]
	]

	format: function [top [block!]][
		buffer: make string! 1000
		newline: function [cnt [integer!]] [
			append buffer lf
			append/dup buffer " " cnt
		]
		format*: function [pc [block! paren!] depth [integer!]][
			pad: depth * 4
			newline pad
			append buffer "["
			forall pc [
				newline pad + 2
				append buffer "["
				newline pad + 4
				append buffer "expr: "
				append buffer mold/flat/part pc/1/expr 20
				newline pad + 4
				append buffer "s: "
				append buffer mold pc/1/s
				newline pad + 4
				append buffer "e: "
				append buffer mold pc/1/e
				newline pad + 4
				append buffer "depth: "
				append buffer mold pc/1/depth
				if pc/1/nested [
					newline pad + 4
					append buffer "nested: "
					format* pc/1/nested depth + 1
				]
				if pc/1/source [
					newline pad + 4
					append buffer "source: "
					append buffer mold/flat/part pc/1/source 20
				]
				if pc/1/max-depth [
					newline pad + 4
					append buffer "max-depth: "
					append buffer pc/1/max-depth
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
]
