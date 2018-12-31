Red [
	Title:   "Red syntax for Red language server"
	Author:  "bitbegin"
	File: 	 %syntax.red
	Tabs:	 4
	Rights:  "Copyright (C) 2011-2019 Red Foundation. All rights reserved."
	License: "BSD-3 - https://github.com/red/red/blob/origin/BSD-3-License.txt"
]

#include %error.red

red-syntax: context [
	throw-error: register-error 'red-syntax
	pc: none
	ctx: none

	next-tail?: func [fn where][
		if tail? next where [
			throw-error fn "no more code!" where
		]
	]

	check-block?: func [fn where][
		unless block? where/1/1 [
			throw-error fn "need a block!" where
		]
	]

	mark-global: does [
		case [
			set-word? pc/1/1 [
				clear pc/1/4
				append pc/1/4 'global
				next-tail? 'mark-global pc
				pc: next pc
			]
			any [
				pc/1/1 = 'set
				all [
					path? pc/1/1
					find/match to string! pc/1/1 "set/"
				]
			][
				next-tail? 'mark-global pc
				pc: next pc
				clear pc/1/4
				append pc/1/4 'global
				next-tail? 'mark-global pc
				pc: next pc
			]
			any [
				pc/1/1 = 'func
				pc/1/1 = 'function
				pc/1/1 = 'has
			][
				next-tail? 'mark-global pc
				pc: next pc
				check-block? 'mark-global pc
				next-tail? 'mark-global pc
				pc: next pc
				check-block? 'mark-global pc
				pc: next pc
			]
			any [
				pc/1/1 = 'does
				pc/1/1 = 'context
			][
				next-tail? 'mark-global pc
				pc: next pc
				check-block? 'mark-global pc
				pc: next pc
			]
			pc/1/1 = 'make [
				next-tail? 'mark-global pc
				pc: next pc
				if pc/1/1 = 'object! [
					next-tail? 'mark-global pc
					pc: next pc
					check-block? 'mark-global pc
					pc: next pc
				]
			]
			true [pc: next pc]
		]
	]


	find-head: func [file [file!] words-table [block!] /local npc][
		npc: none
		forall words-table [
			if all [
				3 = length? words-table/1
				words-table/1/1 = file
			][npc: words-table/1/3 break]
		]
		unless npc [
			throw-error 'find-head "can't find file" file
		]

		unless npc/1/1 = 'Red [
			throw-error 'find-head "incorrect header" npc/1
		]
		npc: next npc
		unless block? npc/1/1 [
			throw-error 'find-head "incorrect header" npc/1
		]
		next npc
	]

	analysis: func [file [file!] words-table [block!]
		/local saved
	][
		pc: find-head file words-table

		saved: pc
		until [
			mark-global
			tail? pc
		]
		true
	]

	get-globals: func [file [file!] words-table [block!]
		/local blk
	][
		pc: find-head file words-table

		blk: make block! 100
		until [
			if pc/1/4/1 = 'global [
				append blk to word! pc/1/1
			]
			pc: next pc
			tail? pc
		]
		blk
	]
]
