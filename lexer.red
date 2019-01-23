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

	push-stack: function [stack [block!] expr start [string!] end [string!] origin [block! paren! none!]][
		append stack make map! reduce [
			'expr expr
			'start form-pos start
			'end form-pos end
			'syntax make map! 4
			'origin origin
		]
	]

	analysis*: function [start [string!] end [string!]][
		stack: make block! 10000

		pos: start
		out: make block! 1
		until [
			forever [
				case [
					(index? pos) >= index? end [
						return stack
					]
					whitespace? pos/1 [
						pos: next pos
					]
					pos/1 = #";" [
						either npos: find pos #"^/" [
							if (index? npos) > index? end [
								npos: end
							]
						][npos: end]
						push-stack stack copy/part pos npos pos npos none
						pos: npos
					]
					true [break]
				]
			]
			npos: try [system/lexer/transcode/one pos clear out false]
			if npos = pos [
				npos: make error! [
					type: 'syntax
					id: 'invalid
					arg1: to string! pos/1
					arg2: to string! pos/1
					arg3: none
				]
			]
			if error? npos [
				return make map! reduce ['pos form-pos pos 'error npos 'stack stack]
			]
			case [
				all [
					block? out/1
					not empty? out/1
				][
					start2: next pos end2: back npos
					stack2: analysis start2 end2
					push-stack stack stack2 pos npos out/1
				]
				all [
					paren? out/1
					not empty? out/1
				][
					start2: next pos end2: back npos
					stack2: analysis start2 end2
					paren: make paren! 4
					append paren stack2
					push-stack stack paren pos npos out/1
				]
				true [
					push-stack stack out/1 pos npos none
				]
			]
			pos: npos
			tail? pos
		]
		stack
	]
	analysis: function [start [string!]][
		stack: clear []
		end: tail start
		if map? sub: analysis* start end [
			return sub
		]
		push-stack stack sub start end none
		stack
	]
]
