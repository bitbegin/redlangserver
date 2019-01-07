Red [
	Title:   "Red lexer for Red language server"
	Author:  "bitbegin"
	File: 	 %lexer.red
	Tabs:	 4
	Rights:  "Copyright (C) 2011-2019 Red Foundation. All rights reserved."
	License: "BSD-3 - https://github.com/red/red/blob/origin/BSD-3-License.txt"
]

red-lexer: context [

	whitespace?: function [c [char!]][
		either any [
			c = #"^/"
			c = #"^M"
			c = #" "
			c = #"^-"
		][true][false]
	]

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

	analysis: function [source [string!]][
		words: make block! 10000

		pos: source
		out: make block! 1
		until [
			forever [
				case [
					all [
						not tail? pos
						whitespace? pos/1
					][
						pos: next pos
					]
					pos/1 = #";" [
						unless npos: find pos #"^/" [npos: tail pos]
						append/only words reduce [
							copy/part pos npos
							form-pos pos form-pos npos
							none none none none
						]
						pos: npos
					]
					tail? pos [
						return words
					]
					true [break]
				]
			]
			if error? npos: try [system/lexer/transcode/one pos clear out false][
				return make map! reduce ['pos form-pos pos 'err npos 'lexer words]
			]
			append/only words reduce [
				out/1 form-pos pos form-pos npos
				none none none none]
			pos: npos
			tail? pos
		]
		words
	]
]
