Red [
	Title:   "Red system-words for Red language server"
	Author:  "bitbegin"
	File: 	 %system-words.red
	Tabs:	 4
	Rights:  "Copyright (C) 2011-2019 Red Foundation. All rights reserved."
	License: "BSD-3 - https://github.com/red/red/blob/origin/BSD-3-License.txt"
]

system-words: context [
	get-red-words: has [sys words] [
		sys: words-of system/words
		words: make block! length? sys
		forall sys [
			if value? sys/1 [
				append words sys/1
			]
		]
		words
	]
	red-words: get-red-words
	reds-words: [?? as assert size? if either case switch until while loop any all exit return break continue catch declare use null context with comment true false func function alias]
	get-words: func [system? [logic!]][
		either system? [reds-words][red-words]
	]
	keyword?: func [system? [logic!] word [word!]][
		to logic! find either system? [reds-words][red-words] word
	]

	get-word-info: func [system? [logic!] word [word!]][
		if system? [return none]
		either find red-words word [
			help-string :word
		][none]
	]

	get-path-info: func [system? [logic!] path [path!]][
		if system? [return none]
		either find red-words path/1 [
			n: copy path
			while [
				all [
					not tail? n
					error? ret: try [
						either 1 = length? n [
							n2: to word! n/1
							help-string :n2
						][
							help-string :n
						]
					]
				]
			][
				remove back tail n
			]
			if error? ret [return none]
			ret
		][
			none
		]
	]

	func-spec-ctx: context [
		func-spec: context [
			desc: none				; string!							desc
			attr: none				; block!							[attr ...]
			params: copy []			; [word! opt block! opt string!]	[name type desc]
			refinements: copy []	; [word! opt string! [params]]		[name desc [[name type desc] ...]]
			locals: copy []			; [some word!]						[name ...]
			returns: copy []		; [opt [word! string!]]				[type desc]
		]

		param-frame-proto: reduce ['name none 'type none 'desc none]
		refinement-frame-proto: reduce ['name none 'desc none 'params copy []]

		;!! These cause problems if local in parse-func-spec
			stack: copy []
			push: func [val][append/only stack val]
			pop:  does [also  take back tail stack  cur-frame: last stack]
			push-param-frame: does [
				push cur-frame: copy param-frame-proto
			]
			push-refinement-frame: does [
				push cur-frame: copy/deep refinement-frame-proto
			]
			emit: function [key val][
				pos: find/only/skip cur-frame key 2
				head change/only next pos val
			]
		;!!
		
		parse-func-spec: function [
			"Parses a function spec and returns an object model of it."
			spec [block! any-function!]
			/local =val		; set with parse, so function won't collect it
		][
			clear stack
			; The = sigils are just to make parse-related vars more obvious
			func-desc=:  [set =val string! (res/desc: =val)]
			attr-val=:   ['catch | 'throw]
			func-attr=:  [into [copy =val some attr-val= (res/attr: =val)]]
			
			param-name=: [
				set =val [word! | get-word! | lit-word!]
				(push-param-frame  emit 'name =val)
			]
			;!! This isn't complete. Under R2 we could parse for datatype! in 
			;	the param type spec, but they are just words in Red func specs.
			param-type=: [set =val block! (emit 'type =val)]
			param-desc=: [set =val string! (emit 'desc =val)]
			param-attr=: [opt param-type= opt param-desc=]
			param=:      [param-name= param-attr= (append/only res/params new-line/all pop off)]
			
			ref-name=:   [set =val refinement! (push-refinement-frame  emit 'name =val)]
			ref-desc=:   :param-desc=
			ref-param=:  [param-name= param-attr= (tmp: pop  append/only cur-frame/params tmp)]
			refinement=: [ref-name= opt ref-desc= any ref-param= (append/only res/refinements pop)]
			local-name=: [set =val word! (push-param-frame  emit 'name =val)]
			local-param=: [local-name= param-attr= (append/only res/locals new-line/all pop off)]
			locals=:     [/local any local-param=]
			returns=: [
				quote return: (push-param-frame  emit 'name 'return)
				param-type= opt param-desc=
				(res/returns: pop)
			]
			spec=: [
				opt func-desc=
				opt func-attr=
				any param=
				any [locals= to end | refinement= | returns=]
			]

			if any-function? :spec [spec: spec-of :spec]
			res: make func-spec []
			either parse spec spec= [res] [none]
		]
	]

	;-- for speed up
	func-spec: func-spec-ctx/parse-func-spec get 'func
	has-spec: func-spec-ctx/parse-func-spec get 'has
	does-spec: func-spec-ctx/parse-func-spec get 'does
	function-spec: func-spec-ctx/parse-func-spec get 'function
	context-spec: func-spec-ctx/parse-func-spec get 'context
	do-spec: func-spec-ctx/parse-func-spec get 'do
	bind-spec: func-spec-ctx/parse-func-spec get 'bind
	all-spec: func-spec-ctx/parse-func-spec get 'all
	any-spec: func-spec-ctx/parse-func-spec get 'any

	get-spec: function [word [word!]][
		if find [func has does function context do bind all any] word [
			spec: to word! append to string! word "-spec"
			return do bind spec system/words/system-words
		]
		either find [native! action! op! function! routine!] type?/word get word [
			func-spec-ctx/parse-func-spec get word
		][none]
	]

]
