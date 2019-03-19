Red [
	Title:   "Red runtime lexer"
	Author:  "Nenad Rakocevic"
	File: 	 %lexer.red
	Tabs:	 4
	Rights:  "Copyright (C) 2014-2018 Red Foundation. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

lexer: context [
	uri-to-file: function [uri [string!]][
		src: copy find/tail uri "file:///"
		replace src "%3A" ""
		insert src "%/"
		load src
	]
	file-to-uri: function [file [file!]][
		src: mold file
		either system/platform = 'Windows [
			src: copy skip src 2
			insert next src "%3A"
			insert src "file:///"
		][
			src: copy skip src 1
			insert src "file://"
		]
		src
	]
	semicolon?: function [pc [block!] pos [string!] column [integer!]][
		if pos/1 = #";" [return true]
		repeat count column [
			if pos/(0 - count) = #";" [return true]
		]
		false
	]
	parse-line: function [stack [block!] src [string!]][
		append stack src
		append stack index? src
		while [src: find/tail src #"^/"][
			append stack index? src
		]
	]
	line-pos?: function [stack [block!] line [integer!] column [integer!]][
		pos: pick stack line + 1
		skip at stack/1 pos column - 1
	]
	pos-line?: function [stack [block!] pos [string!]][
		pos: index? pos
		stack: next stack
		forall stack [
			if all [
				stack/1 <= pos
				any [
					none? stack/2
					stack/2 > pos
				]
			][
				column: pos - stack/1
				return reduce [1 + index? stack column + 1]
			]
		]
		none
	]
	pos-range?: function [stack [block!] s [string!] e [string!]][
		range: make block! 4
		append range pos-line? stack s
		append range pos-line? stack e
		range
	]
	form-range: function [range [block!] /keep][
		make map! reduce [
			'start make map! reduce [
				'line either keep [range/1][range/1 - 1]
				'character either keep [range/2][range/2 - 1]
			]
			'end make map! reduce [
				'line either keep [range/3][range/3 - 1]
				'character either keep [range/4][range/4 - 1]
			]
		]
	]

	make-hm: :system/lexer/make-hm

	make-msf: :system/lexer/make-msf

	make-hms: :system/lexer/make-hms

	make-hmsf: :system/lexer/make-hmsf

	make-time: :system/lexer/make-time

	make-binary: :system/lexer/make-binary

	make-tuple: :system/lexer/make-tuple

	make-number: :system/lexer/make-number

	make-float: :system/lexer/make-float

	make-hexa: :system/lexer/make-hexa

	make-char: :system/lexer/make-char

	push-path: :system/lexer/push-path

	set-path: :system/lexer/set-path

	make-word: :system/lexer/make-word

	to-word: :system/lexer/to-word

	pop: function [stack [block!] /only][
		value: last stack
		remove back tail stack
		unless only [append/only last stack :value]
	]

	store: function [stack [block!] value][
		append last stack value
	]

	new-line: :system/lexer/new-line

	transcode: function [
		src			[string!]
		return:		[block!]
		/local
			rs re epos ast-nested ast-block ast-upper
			new s e c pos value cnt type wtype process path
			digit hexa-upper hexa-lower hexa hexa-char not-word-char not-word-1st
			not-file-char not-str-char not-mstr-char caret-char
			non-printable-char integer-end ws-ASCII ws-U+2k control-char
			four half non-zero path-end base base64-char slash-end not-url-char
			email-end pair-end file-end err date-sep time-sep not-tag-1st
	][
		cs:		[- - - - - - - - - - - - - - - - - - - - - - - - - - - - -] ;-- memoized bitsets
		stack:	clear []
		append/only stack make block! 20
		append/only stack make block! 20

		ast-stack: clear []
		ast-error: make block! 4
		rs-stack: make block! 3000
		type-stack: make block! 200
		line-stack: make block! 3000
		append/only ast-stack make block! 1
		append/only ast-stack make block! 100
		append line-stack src
		append line-stack index? src
		append/only rs-stack rs: [1 1]
		store-ast: [
			either 1 = length? ast-stack [
				ast-upper: none
			][
				ast-upper: tail pick tail ast-stack -2
			]
			ast-block: reduce [
				'expr reduce [value]
				'range append copy rs re
			]
			unless empty? ast-error [
				repend ast-block ['error ast-error]
				ast-error: make block! 4
			]
			if ast-upper [repend ast-block ['upper ast-upper]]
			unless empty? ast-nested [repend ast-block ['nested ast-nested]]
			append/only last ast-stack ast-block
			ast-nested: none
		]
		pop-ast: [
			rs: last rs-stack remove back tail rs-stack
			ast-nested: last ast-stack remove back tail ast-stack
			do store-ast
		]
		push-error: function [type [datatype!] message [string!] level [word!] pos [string!]][
			rpos: line-pos? line-stack rs/1 rs/2
			offset: offset? rpos pos
			repend/only ast-error ['type type 'msg message 'level level 'off offset]
		]
		push-invalid: function [type [datatype!] pos [string!]][
			rpos: line-pos? line-stack rs/1 rs/2
			offset: offset? rpos pos
			repend/only ast-error ['type type 'msg "invalid" 'level 'Error 'off offset]
		]
		push-miss: function [type [datatype!] miss pos [string!]][
			rpos: line-pos? line-stack rs/1 rs/2
			offset: offset? rpos pos
			repend/only ast-error ['type type 'msg 
				rejoin ["missing: " mold miss] 'level 'Error 'off offset]
		]
		have-error?: function [][
			errors: ast-error
			if empty? errors [return no]
			forall errors [
				if errors/1/level = 'Error [return yes]
			]
			no
		]
		now-line?: function [npos [string!]][
			line: (length? line-stack) - 1
			s: last line-stack
			reduce [line (index? npos) - s + 1]
		]
		remove-lines: function [line [integer!]][
			if line = last-line: ((length? line-stack) - 1) [exit]
			loop last-line - line [
				remove back tail line-stack
			]
		]
		make-string: [
			new: make type len: (index? e) - index? s
			parse/case/part s [
				any [
					escaped-char (append new value)
					| #"^^"	epos: (push-error type "'single caret' will be ignored" 'Warning epos)	;-- trash single caret chars
					| set c skip (append new c)
				]
			] len
			new
		]

		make-file: [
			new: make type len: (index? e) - index? s
			either parse/part s [
				any [
					#"%" [
						2 hexa
						| epos: (push-error type "invalid hex" 'Error epos) reject
					]
					| skip
				]
			] len
			[
				buffer: copy/part s e
				append new dehex buffer
				if type = file! [parse new [any [s: #"\" change s #"/" | skip]]]
				new
			][type]
		]

		month-rule: [(m: none)]							;-- dynamically filled
		mon-rule:   [(m: none)]							;-- dynamically filled

		if cs/1 = '- [
			do [
				cs/1:  charset "0123465798"					;-- digit
				cs/2:  charset "ABCDEF"						;-- hexa-upper
				cs/3:  charset "abcdef"						;-- hexa-lower
				cs/4:  union cs/1 cs/2						;-- hexa
				cs/5:  union cs/4 cs/3						;-- hexa-char
				cs/6:  charset {/\^^,[](){}"#%$@:;}			;-- not-word-char
				cs/7:  union union cs/6 cs/1 charset {'}	;-- not-word-1st
				cs/8:  charset {[](){}"@:;}					;-- not-file-char
				cs/9:  #"^""								;-- not-str-char
				cs/10: #"}"									;-- not-mstr-char
				cs/11: charset [#"^(40)" - #"^(5F)"]		;-- caret-char
				cs/12: charset [							;-- non-printable-char
					#"^(00)" - #"^(08)"						;-- (exclude TAB)
					#"^(0A)" - #"^(1F)"
				]
				cs/13: charset {^{"[]();:xX}				;-- integer-end
				cs/14: charset " ^-^M"						;-- ws-ASCII, ASCII common whitespaces
				cs/15: charset [#"^(2000)" - #"^(200A)"]	;-- ws-U+2k, Unicode spaces in the U+2000-U+200A range
				cs/16: charset [ 							;-- Control characters
					#"^(00)" - #"^(1F)"						;-- C0 control codes
					#"^(80)" - #"^(9F)"						;-- C1 control codes
				]
				cs/17: charset "01234"						;-- four
				cs/18: charset "012345"						;-- half
				cs/19: charset "123456789"					;-- non-zero
				cs/20: charset {^{"[]();}					;-- path-end
				cs/21: union cs/1 charset [					;-- base64-char
					#"A" - #"Z" #"a" - #"z" #"+" #"/" #"="
				]
				cs/22: charset {[](){}":;}					;-- slash-end
				cs/23: charset {[](){}";}					;-- not-url-char
				cs/24: union cs/8 union cs/14 charset "<^/" ;-- email-end
				cs/25: charset {^{"[]();:}					;-- pair-end
				cs/26: charset {^{[]();:}					;-- file-end
				cs/27: charset "/-"							;-- date-sep
				cs/28: charset "/T"							;-- time-sep
				cs/29: charset "=><[](){};^""				;-- not-tag-1st

				list: system/locale/months
				while [not tail? list][
					append month-rule list/1
					append/only month-rule p: copy quote (m: ?)
					unless tail? next list [append month-rule '|]
					p/2: index? list
					append mon-rule copy/part list/1 3
					append/only mon-rule p
					unless tail? next list [append mon-rule '|]
					list: next list
				]
			]
		]
		set [
			digit hexa-upper hexa-lower hexa hexa-char not-word-char not-word-1st
			not-file-char not-str-char not-mstr-char caret-char
			non-printable-char integer-end ws-ASCII ws-U+2k control-char
			four half non-zero path-end base64-char slash-end not-url-char email-end
			pair-end file-end date-sep time-sep not-tag-1st
		] cs

		byte: [
			"25" half
			| "2" four digit
			| "1" digit digit
			| opt #"0" non-zero digit
			| 0 2 #"0" digit
			| 1 2 #"0"
		]

		;-- Whitespaces list from: http://en.wikipedia.org/wiki/Whitespace_character
		ws: [
			#"^/" epos: (append line-stack index? epos)
			| ws-ASCII									;-- only the common whitespaces are matched
			;| #"^(0085)"								;-- U+0085 (Newline)
			| #"^(00A0)"								;-- U+00A0 (No-break space)
			;| #"^(1680)"								;-- U+1680 (Ogham space mark)
			;| #"^(180E)"								;-- U+180E (Mongolian vowel separator)
			;| ws-U+2k									;-- U+2000-U+200A range
			;| #"^(2028)"								;-- U+2028 (Line separator)
			;| #"^(2029)"								;-- U+2029 (Paragraph separator)
			;| #"^(202F)"								;-- U+202F (Narrow no-break space)
			;| #"^(205F)"								;-- U+205F (Medium mathematical space)
			;| #"^(3000)"								;-- U+3000 (Ideographic space)
		]

		ws-no-count: [
			#"^/"
			| ws-ASCII									;-- only the common whitespaces are matched
			;| #"^(0085)"								;-- U+0085 (Newline)
			| #"^(00A0)"								;-- U+00A0 (No-break space)
			;| #"^(1680)"								;-- U+1680 (Ogham space mark)
			;| #"^(180E)"								;-- U+180E (Mongolian vowel separator)
			;| ws-U+2k									;-- U+2000-U+200A range
			;| #"^(2028)"								;-- U+2028 (Line separator)
			;| #"^(2029)"								;-- U+2029 (Paragraph separator)
			;| #"^(202F)"								;-- U+202F (Narrow no-break space)
			;| #"^(205F)"								;-- U+205F (Medium mathematical space)
			;| #"^(3000)"								;-- U+3000 (Ideographic space)
		]

		newline-char: [
			#"^/"
			| #"^(0085)"								;-- U+0085 (Newline)
			| #"^(2028)"								;-- U+2028 (Line separator)
			| #"^(2029)"								;-- U+2029 (Paragraph separator)
		]

		counted-newline: [pos: #"^/" (append line-stack index? next pos)]

		escaped-char: [
			"^^(" [
				[										;-- special case first
					"null" 	 (value: #"^(00)")
					| "back" (value: #"^(08)")
					| "tab"  (value: #"^(09)")
					| "line" (value: #"^(0A)")
					| "page" (value: #"^(0C)")
					| "esc"  (value: #"^(1B)")
					| "del"	 (value: #"^~")
				]
				| pos: [2 6 hexa-char] e: (				;-- Unicode values allowed up to 10FFFFh
					value: make-char pos e
				)
			] #")"
			| #"^^" [
				[
					#"/" 	(value: #"^/")
					| #"-"	(value: #"^-")
					| #"~" 	(value: #"^(del)")
					| #"^^" (value: #"^^")				;-- caret escaping case
					| #"{"	(value: #"{")
					| #"}"	(value: #"}")
					| #"^""	(value: #"^"")
				]
				| pos: caret-char (value: pos/1 - 64)
			]
		]

		char-rule: [
			(type: char!)
			{#"} s: [
				 escaped-char
				| ahead [non-printable-char | not-str-char]
				  epos: (push-invalid type back epos)
				| skip (value: s/1)
			][
				e: #"^""
				| [some [[ahead #"^"" | end] break | ws | skip] epos: [#"^"" (push-invalid type epos) | (push-miss type #"^"" epos)]]
			]
		]

		line-string: [
			#"^"" s: any [
				{^^"}
				| ahead [#"^"" | newline-char] break
				| escaped-char
				| skip
			]
			[
				e: #"^""
				| [some [[ahead #"^"" | end] break | ws | skip] epos: [#"^"" (push-invalid type epos) | (push-miss type #"^"" epos)]]
			]
		]

		nested-curly-braces: [
			(cnt: 1)
			any [
				counted-newline
				| "^^{"
				| "^^}"
				| #"{" (cnt: cnt + 1)
				| e: #"}" if (zero? cnt: cnt - 1) break
				| escaped-char
				| skip
			]
		]

		multiline-string: [
			#"{" s: nested-curly-braces epos: (unless zero? cnt [push-miss type "}" epos])
		]

		string-rule: [(type: string!) line-string | multiline-string]

		tag-rule: [
			#"<" not [not-tag-1st | ws] (type: tag!)
			 s: some [
				ahead [#"^"" thru #"^""] #"^"" some [[#"^"" break | counted-newline | skip]]
				| ahead [#"'" thru #"'"] #"'" some [[#"'" break | counted-newline | skip]]
				| counted-newline
				| e: #">" break
				| skip
			]
			(if e/1 <> #">" [push-miss type ">" e])
		]

		email-rule: [
			s: some [ahead email-end break | skip] #"@"
			any [ahead email-end break | skip] e:
			(type: email!)
		]

		base-2-rule: [
			"2#{" (type: binary!) [
				s: any [counted-newline | 8 [#"0" | #"1" ] | ws | comment-rule | break]
				[
					e: #"}"
					| some [[ahead #"}" | end] break | ws | skip]
					epos: [
						#"}" (push-error type "invalid base 2" 'Error epos)
						| (push-miss type "}" epos)
					]
				]
			] (base: 2)
		]

		base-16-rule: [
			opt "16" "#{" (type: binary!) [
				s: any [counted-newline | 2 hexa-char | ws | comment-rule | break]
				[
					e: #"}"
					| some [[ahead #"}" | end] break | ws | skip]
					epos: [
						#"}" (push-error type "invalid base 16" 'Error epos)
						| (push-miss type "}" epos)
					]
				]
			] (base: 16)
		]

		base-64-rule: [
			"64#{" (type: binary! cnt: 0) [
				s: any [counted-newline | base64-char | ws (cnt: cnt + 1) | comment-rule | break]
				[
					e: #"}"
					| some [[ahead #"}" | end] break | ws | skip]
					epos: [
						#"}" (push-error type "invalid base 64" 'Error epos)
						| (push-miss type "}" epos)
					]
				]
			](
				cnt: (offset? s e) - cnt
				if all [0 < cnt cnt < 4][push-error type "invalid base 64" 'Error e]
				base: 64
			)
		]

		binary-rule: [base-16-rule | base-64-rule | base-2-rule]

		file-rule: [
			s: #"%" [
				epos: #"{" any [#"}" break | ws | skip] (push-invalid file! epos)
				| line-string (process: make-string type: file!)
				| s: any [ahead [not-file-char | ws-no-count] break | skip] e:
				  (process: make-file type: file!)
			]
		]

		url-rule: [
			#":" not [not-url-char | ws-no-count | end]
			any [#"@" | #":" | ahead [not-file-char | ws-no-count] break | skip] e:
			(type: url! store stack do make-file)
		]

		symbol-rule: [
			(ot: none) some [
				ahead [not-word-char | ws-no-count | control-char] break
				| #"<" ot: [ahead #"/" (ot: back ot) :ot break | none]	;-- a</b>
				| #">" if (ot) [(ot: back ot) :ot break]				;-- a<b>
				| skip
			] e:
		]

		begin-symbol-rule: [							;-- 1st char in symbols is restricted
			[not ahead [not-word-1st | ws-no-count | control-char]]
			symbol-rule
		]

		path-rule: [
			ahead #"/" (								;-- path detection barrier
				push-path stack type					;-- create empty path
				to-word stack copy/part s e word!		;-- push 1st path element
				type: path!
			)
			some [
				#"/"
				s: [
					integer-number-rule			(store stack make-number s e type)
					| begin-symbol-rule			(to-word stack copy/part s e word!)
					| #":" s: begin-symbol-rule	(to-word stack copy/part s e get-word!)
					| (push-invalid type s)
				]
			]
			opt [
				#":"
				[
					if (wtype = word!) (type: set-path! set-path back tail stack)
					| epos: (push-invalid type epos)
				]
			]
			[ahead [path-end | ws-no-count | end] | epos: (push-miss type "separator" epos)]
			(pop stack)
		]

		special-words: [
			#"%" [ws | ahead file-end | end] (value: "%")	;-- special case for remainder op!
			| #"/" ahead [slash-end | #"/" | ws-no-count | control-char | end][
				#"/"
				ahead [slash-end | ws-no-count | control-char | end] (value: "//")
				| (value: "/")
			]
			| "<>" (value: "<>")
		]

		word-rule: 	[
			(type: wtype: word!) special-words	opt [#":" (type: set-word!)]
			(to-word stack value type)				;-- special case for / and // as words
			| path: s: begin-symbol-rule (type: word!) [
				url-rule
				| path-rule							;-- path matched
				| opt [#":" (type: set-word!)]
				  (if type [to-word stack copy/part s e type])	;-- word or set-word matched
			]
		]

		get-word-rule: [
			#":" (type: wtype: get-word!) [
				special-words (to-word stack value type)
				| s: begin-symbol-rule [
					path-rule (type: get-path!)
					| (to-word stack copy/part s e type)	;-- get-word matched
				]
				| epos: (
					to-word stack "" type
					push-invalid type epos
				)
			]
		]

		lit-word-rule: [
			#"'" (type: wtype: lit-word!) [
				special-words (to-word stack value type)
				| [
					s: begin-symbol-rule [
						path-rule (type: lit-path!)			 ;-- path matched
						| (to-word stack copy/part s e type) ;-- lit-word matched
					]
				]
				| epos: (
					to-word stack "" type
					push-invalid type epos
				)
			]
			epos: opt [#":" (push-invalid type epos)]
		]

		issue-rule: [
			#"#" (type: issue!) s: symbol-rule (
				either (index? s) = index? e [
					to-word stack "" type
					push-invalid type e
				][
					to-word stack copy/part s e type
				]
			)
		]

		refinement-rule: [
			#"/" [
				some #"/" (type: word!) e:				;--  ///... case
				| ahead [not-word-char | ws-no-count | control-char] (type: word!) e: ;-- / case
				| symbol-rule (type: refinement! s: next s)
			]
			(to-word stack copy/part s e type)
		]

		sticky-word-rule: [								;-- protect from sticky words typos
			ahead [integer-end | ws-no-count | end] | epos: (push-invalid type epos) any [ahead [integer-end | ws-no-count | end] break | skip]
		]
		hexa-rule: [2 8 hexa e: #"h" ahead [integer-end | ws-no-count | end]]

		tuple-value-rule: [byte 2 11 [#"." byte] e: (type: tuple!)]

		tuple-rule: [tuple-value-rule sticky-word-rule]

		time-rule: [
			s: positive-integer-rule [
				float-number-rule (value: make-time pos none value make-number s e type neg?) ;-- mm:ss.dd
				| (value2: make-number s e type) [
					#":" s: positive-integer-rule opt float-number-rule
					  (value: make-time pos value value2 make-number s e type neg?)		;-- hh:mm:ss[.dd]
					| (value: make-time pos value value2 none neg?)						;-- hh:mm
				]
			] (type: time!)
		]

		day-year-rule: [
			s: opt #"-" 3 4 digit e: (year: make-number s e integer!)
			| 1 2 digit e: (
				value: make-number s e integer!
				either day [year: value + pick [2000 1900] 50 > value][day: value]
			)
		]

		date-rule: [
			ahead [opt #"-" 1 4 digit date-sep | 8 digit #"T"][ ;-- quick lookhead
				s: 8 digit ee: #"T" (							;-- yyyymmddT
					year:  make-number s e: skip s 4 integer!
					month: make-number e e: skip e 2 integer!
					day:   make-number e e: skip e 2 integer!
					date:  make date! [day month year]
				) :ee
				| day-year-rule sep: date-sep (sep: sep/1) [
					s: 1 2 digit e: (month: make-number s e integer!)
					| case off month-rule (month: m)
					| case off mon-rule   (month: m)
				]
				sep day-year-rule [if (not all [day month year]) fail | none] (
					date: make date! [day month year]
				)
				| s: 4 digit #"-" (
					year: make-number s skip s 4 integer!
					date: make date! [1 1 year]
				)[
					"W" s: 2 digit (ee: none) opt [#"-" ee: non-zero] (	;-- yyyy-Www
						date/isoweek: make-number s skip s 2 integer!
						if ee [date/weekday: to integer! ee/1 - #"0"]	;-- yyyy-Www-d
					)
					| s: 3 digit (date/yearday: make-number s skip s 3 integer!) ;-- yyyy-ddd
				] (month: -1)
			](
				type: date!
				if all [
					month <> -1 any [date/year <> year date/month <> month date/day <> day]
				][push-invalid type s]
				day: month: year: none
			) opt [
				time-sep (ee: no) [
					s: 6 digit opt [#"." 1 9 digit ee:] (		;-- Thhmmss[.sss]
						hour: make-number s e: skip s 2 integer!
						mn:	  make-number e e: skip e 2 integer!
						date/time: either ee [
							sec: make-number e ee float!
							make-hmsf hour mn sec
						][
							sec: make-number e e: skip e 2 integer!
							make-hms hour mn sec
						]
					)
					| 4 digit (									;-- Thhmm
						hour: make-number s e: skip s 2 integer!
						mn:	  make-number e e: skip e 2 integer!
						date/time: make-hms hour mn 0
					)
					| s: positive-integer-rule (value: make-number s e integer!)
					#":" [(neg?: no) time-rule (date/time: value) | (push-invalid type s)]
				]
				opt [
					#"Z" | [#"-" (neg?: yes) | #"+" (neg?: no)][
						s: 4 digit (							;-- +/-hhmm
							hour: make-number s e: skip s 2 integer!
							mn:   make-number e e: skip e 2 integer!
						)
						| 1 2 digit e: (hour: make-number s e integer! mn: none) ;-- +/-h, +/-hh
						opt [#":" s: 2 digit e: (mn: make-number s e integer!)]
					]
					(zone: make-hm hour any [mn 0] date/zone: either neg? [negate zone][zone])
				]
			] sticky-word-rule (value: date)
		]

		positive-integer-rule: [digit any digit e: (type: integer!)]

		integer-number-rule: [
			opt [#"-" (neg?: yes) | #"+" (neg?: no)] digit any [digit | #"'" digit] e:
			(type: integer!)
		]

		integer-rule: [
			float-special		;-- escape path for NaN, INFs
			| (neg?: no) integer-number-rule
			  opt [float-number-rule | float-exp-rule e: (type: float!)]
			  opt [#"%" (type: percent!)]
			  opt [[#"." | #"e"] epos: (type: float! push-invalid type epos)]
			  sticky-word-rule
			  (value: make-number s e type)
			  opt [
				[#"x" | #"X"] [
					s: integer-number-rule ahead [pair-end | ws-no-count | end] (value: as-pair value make-number s e type type: pair!)
					| epos: (type: pair! push-invalid type epos) any [ahead [integer-end | ws-no-count | end] break | skip]
				]
			  ]
			  opt [
				#":" [
					if (type <> pair!) time-rule
					| epos: (push-invalid type epos) any [ahead [integer-end | ws-no-count | end] break | skip]
				]
			  ]
		]

		float-special: [
			s: opt #"-" "1.#" [
				[
					[[#"N" | #"n"] [#"a" | #"A"] [#"N" | #"n"]]
					| [[#"I" | #"i"] [#"N" | #"n"] [#"F" | #"f"]]
				] e: (type: float! value: make-number s e type)
				| e: (type: float! push-invalid type e) any [ahead [integer-end | ws-no-count | end] break | skip]
			]
		]

		float-exp-rule: [[#"e" | #"E"] opt [#"-" | #"+"] 1 3 digit]

		float-number-rule: [
			[#"." | #","] digit any [digit | #"'" digit]
			opt float-exp-rule e: (type: float!)
		]

		float-rule: [
			opt [#"-" | #"+"] float-number-rule
			opt [#"%" (type: percent!)]
			opt [[#"x" | #"X"] epos: (type: float! push-invalid type epos)]
			sticky-word-rule
		]

		map-rule: [
			"#(" (
				append/only stack make block! 20
				append/only ast-stack make block! 100
				append/only rs-stack rs
				append type-stack map!
			)
			nested-paren
			(value: last type-stack)
			epos: [#")" | end (push-miss value ")" epos)] epos: (
				re: now-line? epos
				remove back tail type-stack
				remove back tail stack
				do pop-ast
			)
		]

		block-rule: [
			#"[" (
				append/only stack make block! 20
				append/only ast-stack make block! 100
				append/only rs-stack rs
				append type-stack block!
			)
			nested-block
			(value: last type-stack)
			epos: [#"]" | end (push-miss value "]" epos)] epos: (
				re: now-line? epos
				remove back tail type-stack
				remove back tail stack
				do pop-ast
			)
		]

		paren-rule: [
			#"(" (
				append/only stack make paren! 8
				append/only ast-stack make block! 8
				append/only rs-stack rs
				append type-stack paren!
			)
			nested-paren
			(value: last type-stack)
			epos: [#")" | end (push-miss value ")" epos)] epos: (
				re: now-line? epos
				remove back tail type-stack
				remove back tail stack
				do pop-ast
			)
		]

		escaped-rule: [
			"#[" pos: any ws [
				  "true"  			(value: true)
				| "false" 			(value: false)
				| [
					"none!"			(value: none!)
					| "logic!"		(value: logic!)
					| "block!"		(value: block!)
					| "integer!"	(value: integer!)
					| "word!"		(value: word!)
					| "set-word!"	(value: set-word!)
					| "get-word!"	(value: get-word!)
					| "lit-word!"	(value: lit-word!)
					| "refinement!"	(value: refinement!)
					;| "binary!"	(value: binary!)
					| "string!"		(value: string!)
					| "char!"		(value: char!)
					| "bitset!"		(value: bitset!)
					| "path!"		(value: path!)
					| "set-path!"	(value: set-path!)
					| "lit-path!"	(value: lit-path!)
					| "get-path!"	(value: get-path!)
					| "native!"		(value: native!)
					| "action!"		(value: action!)
					| "op!"			(value: op!)
					| "issue!"		(value: issue!)
					| "paren!"		(value: paren!)
					| "function!"	(value: function!)
					| "routine!"	(value: routine!)
				]
				| "none" 			(value: none)
				| any ws ahead #"]" (value: type: error! push-invalid type pos) break
				| (value: error!) break
			][
				pos: any ws "]"
				| some [[ahead #"]" | end] break | ws | skip]
				epos: [
					#"]" (type: error! push-invalid type epos)
					| (type: error! push-miss either datatype? value [value][type] "]" epos)
				]
			]
		]

		comment-rule: [#";" [to #"^/" | to end]]

		invalid-rule: [
			epos:
			ahead #"]" if (block! <> last type-stack) skip (type: error! push-invalid type epos)
			| ahead #")" if (all [map! <> last type-stack paren! <> last type-stack]) skip (type: error! push-invalid type epos)
			| skip (type: error! push-invalid type epos)
		]

		literal-value: [
			pos: (e: none rs: now-line? pos) s: [
									  string-rule epos: (re: now-line? epos)		(either have-error? [value: type][value: do make-string] do store-ast)
				| (remove-lines rs/1) block-rule ;epos: (re: now-line? epos)
				| (remove-lines rs/1) comment-rule ;epos: (re: now-line? epos)
				| (remove-lines rs/1) tuple-rule epos: (re: now-line? epos)			(either have-error? [value: type][value: make-tuple s e] do store-ast)
				| (remove-lines rs/1) hexa-rule epos: (re: now-line? epos)			(value: make-hexa s e do store-ast)
				| (remove-lines rs/1) binary-rule epos: (re: now-line? epos)		(either have-error? [value: type][unless value: make-binary s e base [value: binary!]] do store-ast)
				| (remove-lines rs/1) email-rule epos: (re: now-line? epos)			(value: do make-file do store-ast)
				| (remove-lines rs/1) date-rule epos: (re: now-line? epos)			(if have-error? [value: type] do store-ast)
				| (remove-lines rs/1) integer-rule epos: (re: now-line? epos)		(if have-error? [value: type] do store-ast)
				| (remove-lines rs/1) float-rule epos: (re: now-line? epos)			(either have-error? [value: type][unless value: make-float s e type [value: type]] do store-ast)
				| (remove-lines rs/1) tag-rule epos: (re: now-line? epos)			(either have-error? [value: type][value: do make-string] do store-ast)
				| (remove-lines rs/1) word-rule epos: (re: now-line? epos)			(either have-error? [value: type][value: last last stack] remove back tail last stack do store-ast)
				| (remove-lines rs/1) lit-word-rule epos: (re: now-line? epos)		(either have-error? [value: type][value: last last stack] remove back tail last stack do store-ast)
				| (remove-lines rs/1) get-word-rule epos: (re: now-line? epos)		(either have-error? [value: type][value: last last stack] remove back tail last stack do store-ast)
				| (remove-lines rs/1) refinement-rule epos: (re: now-line? epos)	(either have-error? [value: type][value: last last stack] remove back tail last stack do store-ast)
				| (remove-lines rs/1) file-rule epos: (re: now-line? epos)			(either have-error? [value: type][value: do process] do store-ast)
				| (remove-lines rs/1) char-rule epos: (re: now-line? epos)			(either have-error? [value: type][if value > 10FFFFh [push-invalid type s value: type]] do store-ast)
				| (remove-lines rs/1) map-rule ;epos: (re: now-line? epos)
				| (remove-lines rs/1) paren-rule ;epos: (re: now-line? epos)
				| (remove-lines rs/1) escaped-rule epos: (re: now-line? epos)		(do store-ast)
				| (remove-lines rs/1) issue-rule epos: (re: now-line? epos)			(either have-error? [value: type][value: last last stack] remove back tail last stack do store-ast)
				| (remove-lines rs/1) invalid-rule epos: (re: now-line? epos)		(value: type do store-ast)
			]
		]

		nested-block: [pos: some [[ahead #"]" | end] break | some ws | literal-value]]
		nested-paren: [pos: some [[ahead #")" | end] break | some ws | literal-value]]
		some-value: [pos: some [some ws | literal-value]]
		red-rules: some-value

		unless parse/case src red-rules [return false]
		value: block!
		rs: [1 1]
		re: now-line? tail src
		do pop-ast
		repend ast-stack/1/1 ['source src 'lines line-stack]
		ast-stack/1
	]

	format: function [top [block!]][
		buffer: make string! 1000
		newline: function [cnt [integer!]] [
			append buffer lf
			append/dup buffer " " cnt
		]

		format*: function [pc [block!] depth [integer!]][
			pad: depth * 4
			newline pad
			append buffer "["
			forall pc [
				newline pad + 2
				append buffer "["
				newline pad + 4
				append buffer "expr: "
				append buffer mold/flat/part pc/1/expr/1 20
				if pc/1/range [
					newline pad + 4
					append buffer "range: "
					append buffer mold/flat pc/1/range
				]
				if pc/1/nested [
					newline pad + 4
					append buffer "nested: "
					format* pc/1/nested depth + 1
				]
				if pc/1/source [
					newline pad + 4
					append buffer "source: "
					append buffer mold/flat/part pc/1/source 10
				]
				if lines: pc/1/lines [
					newline pad + 4
					append buffer "lines: ["
					newline pad + 6
					append buffer mold/flat/part lines/1 10
					lines: next lines
					forall lines [
						newline pad + 6
						append buffer mold lines/1
					]
					newline pad + 4
					append buffer "]"
				]
				if upper: pc/1/upper [
					newline pad + 4
					append buffer "upper: "
					append buffer mold/flat upper/1/range
				]
				unless empty? errors: pc/1/error [
					newline pad + 4
					append buffer "error: ["
					forall errors [
						newline pad + 6
						append buffer mold/flat errors/1
					]
					newline pad + 4
					append buffer "]"
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
