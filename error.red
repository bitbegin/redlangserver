Red [
	Title:   "register new user error"
	Author:  "bitbegin"
	File: 	 %error.red
	Tabs:	 4
	Rights:  "Copyright (C) 2011-2019 Red Foundation. All rights reserved."
	License: "BSD-3 - https://github.com/red/red/blob/origin/BSD-3-License.txt"
]

#macro ['register-error lit-word!] func [s e][
	system/catalog/errors/user: 
		make system/catalog/errors/user
			reduce [
				to set-word! s/2
				compose [
					(rejoin [s/2 " ["])
					:arg1 ": (" :arg2 " " :arg3 ")]"
				]
			]
	 compose/deep [
		func [name [word!] arg2 arg3][
			cause-error 'user (s/2) [name arg2 arg3]
		]
	]
]
