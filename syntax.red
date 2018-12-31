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

	analysis: func [file [file!] words-table [block!]
		/local iset ifunc ifunction ihas idoes icontext
	][
		pc: none
		find?: false
		forall words-table [
			if all [
				3 = length? words-table/1
				words-table/1/1 = file
			][pc: words-table/1/3 break]
		]
		unless pc [
			throw-error 'syntax-analysis "can't find file" file
		]

		unless pc/1/1 = 'Red [
			return pc/1
		]
		pc: next pc
		unless block? pc/1/1 [
			return pc/1
		]
		iset: 0 ifunc: 0 ifunction: 0 ihas: 0 idoes: 0 icontext: 0

		until [
			pc: next pc
			probe pc/1
			tail? pc
		]
		true
	]
]
