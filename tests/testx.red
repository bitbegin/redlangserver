Red he: []

a: 'test
b: context [
	a: a
	c: 4
	d: context [
		e: #{12}
		f: func [x [block!] y [integer!]][
			ff: function [a [integer!] b [binary!]][
				f1: "test"
				f2: x
				f3: f1
				f4: l
				f5: :f
				f6: f5
				f7: a + length? b
				f
			]
			x: 1
			y: 1
			e: x + y
			o: g
			t: h
			u: x
		]
		g: []
	]
	h: #(a: 3)
	i: x
	j: e
	k: t
]

l: (m: 3 n: a)
o: l

r: func [
	a [test]
	b [test!]
	/part length [integer! string!]
	return: [block!] ;--tests
	/local x y
][
	if part [length]
	x: 1 y: 1
	a + b + 1 + 1
]

s: function [uri [string!] code [string!] blk [block!]][
	either uri [
		return reduce [uri code blk]
	][
		return reduce [uri code blk]
	]
]

fff: 3

ft: func [a [block!] b [map! integer!] return: [integer!] c [integer!] /c a [integer!] /d /local x y z][
	reduce [a b c d]
	find/match "adb" "a"
]

fh1: has [/ref a b]
fh2: has [a b][]

z: z

blk: [a: 1]
ctx: context [
	a: none
]

do bind blk ctx

if all tt: [a = 1 integer? a][print 3]
