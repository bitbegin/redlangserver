Red he: []

a: 'test
b: context [
	c: 4
	d: context [
		e: #{12}
		f: func [x [block!] y [integer!]][
			ff: function [][
				f1: "test"
				f2: x
				f3: f1
				f4: l
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
