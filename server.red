Red [
	Title:   "Red server for Visual Studio Code"
	Author:  "bitbegin"
	File: 	 %server.red
	Tabs:	 4
	Rights:  "Copyright (C) 2011-2019 Red Foundation. All rights reserved."
	License: "BSD-3 - https://github.com/red/red/blob/origin/BSD-3-License.txt"
]

#include %error.red
#include %lsp-const.red
#include %json.red
#include %system-words.red
#include %lexer.red
#include %syntax.red

logger: none
auto-complete?: false
open-logger?: false
debug-on?: false

code-symbols: clear []
last-uri: none
last-completion: none
client-caps: none
shutdown?: no

find-source: function [uri [string!]][
	forall code-symbols [
		if code-symbols/1/1 = uri [
			return code-symbols
		]
	]
	false
]

add-source-to-table: function [uri [string!] code [string!] blk [block!]][
	either item: find-source uri [
		item/1/2: code
		item/1/3: blk
	][
		append/only code-symbols reduce [uri code blk]
	]
]

add-source: function [uri [string!] code [string!]][
	if map? res: red-lexer/analysis code tail code [
		add-source-to-table uri code res/stack
		range: red-lexer/to-range res/pos res/pos
		line-cs: charset [#"^M" #"^/"]
		info: res/error/arg2
		if part: find info line-cs [info: copy/part info part]
		message: rejoin [res/error/id " ^"" res/error/arg1 "^" at: ^"" info "^""]
		return reduce [
			make map! reduce [
				'range range
				'severity 1
				'code 1
				'source "lexer"
				'message message
			]
		]
	]
	add-source-to-table uri code res
	if error? err: try [red-syntax/analysis res][
		pc: err/arg3
		range: red-lexer/to-range pc/2 pc/2
		return reduce [
			make map! reduce [
				'range range
				'severity 1
				'code 1
				'source "syntax"
				'message err/arg2
			]
		]
	]
	red-syntax/collect-errors res
]

init-logger: func [_logger [file! none!]][
	logger: _logger
	if logger [write logger "^/"]
]

write-newline: does [
	#either config/OS = 'Windows [
		write-stdout "^/"
	][
		write-stdout "^M^/"
	]
]

write-response: function [response][
	write-stdout "Content-Length: "
	write-stdout to string! length? to binary! response
	write-newline
	write-stdout {Content-Type: application/vscode-jsonrpc; charset=utf-8}
	write-newline write-newline
	write-stdout response
]

write-log: function [str [string!]][
	if logger [
		unless empty? str [write/append logger str]
		write/append logger "^/"
	]
]

json-body: #(
	jsonrpc: "2.0"
	id: 0
	result: none
	method: none
	error: none
)

process: function [data [string!]][
	script: first json/decode data
	json-body/id: script/id
	json-body/result: none
	json-body/method: none
	json-body/params: none
	json-body/error: none
	dispatch-method script/method script/params
	true
]

response: function [][
	resp: json/encode json-body
	write-response resp
	write-log rejoin ["[OUTPUT] Content-Length: " length? resp]
	write-log resp write-log ""
]

lsp-read: function [][
	len: 0
	until [
		header: trim input-stdin
		if find header "Content-Length: " [
			len: to integer! trim/all find/tail header "Content-Length: "
			write-log rejoin ["[INPUT] Content-Length: " len]
		]
		empty? header
	]
	n: 0
	bin: make binary! len
	until [
		read-stdin skip bin n len - n
		n: length? bin
		n = len
	]

	also str: to string! bin do [write-log str write-log ""]
]

dispatch-method: function [method [string!] params][
	switch method [
		"initialize"						[on-initialize params]
		"initialized"						[on-initialized params]
		"workspace/didChangeConfiguration"	[on-didChangeConfiguration params]
		"shutdown"							[on-shutdown params]
		"textDocument/didOpen"				[on-textDocument-didOpen params]
		"textDocument/didClose"				[on-textDocument-didClose params]
		"textDocument/didChange"			[on-textDocument-didChange params]
		"textDocument/completion"			[on-textDocument-completion params]
		"completionItem/resolve"			[on-completionItem-resolve params]
		"textDocument/documentSymbol"		[on-textDocument-symbol params]
		"textDocument/hover"				[on-textDocument-hover params]
	]
]

TextDocumentSyncKind: [
	None		0
	Full		1
	Incremental	2
]


trigger-string: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/%.+-_=?*"
trigger-chars: []
forall trigger-string [
	append trigger-chars to string! trigger-string/1
]
on-initialize: function [params [map!]][
	set 'client-caps params
	set 'auto-complete? params/initializationOptions/autoComplete
	caps: copy #()
	put caps 'textDocumentSync TextDocumentSyncKind/Full
	put caps 'hoverProvider true
	put caps 'completionProvider
		make map! reduce [
			'resolveProvider true
			'triggerCharacters trigger-chars
		]

	json-body/result: make map! reduce [
		'capabilities caps
	]

	;json-body/result: make map! reduce [
	;	'capabilities make map! reduce [
	;		'textDocumentSync TextDocumentSyncKind/Full
	;		;'textDocumentSync make map! reduce [
	;		;	'openClose			true
	;		;	'change				0
	;		;	'willSave			false
	;		;	'willSaveWaitUntil	false
	;		;	'save				make map! reduce ['includeText true]
	;		;]

	;		;'documentFormattingProvider true
	;		;'documentRangeFormattingProvider true
	;		;'documentOnTypeFormattingProvider make map! reduce ['firstTriggerCharacter "{" 'moreTriggerCharacter ""]
	;		;'codeActionProvider true
	;		'completionProvider make map! reduce ['resolveProvider true 'triggerCharacters trigger-chars]
	;		;'signatureHelpProvider make map! reduce ['triggerCharacters ["."]]
	;		;'definitionProvider true
	;		;'documentHighlightProvider true
	;		'hoverProvider true
	;		;'renameProvider true
	;		;'documentSymbolProvider true
	;		;'workspaceSymbolProvider true
	;		;'referencesProvider true
	;		;'executeCommandProvider make map! reduce ['commands "Red.applyFix"]
	;	]
	;]

	response
]

on-initialized: function [params [map! none!]][
	;json-body/method: "workspace/configuration"
	;items: clear []
	;append items make map! reduce [
	;	'scopeUri "red"
	;]
	;json-body/params: items
]

on-didChangeConfiguration: function [params [map! none!]][
	set 'auto-complete? params/settings/red/autoComplete
	if open-logger? <> params/settings/red/rls-debug [
		open-logger?: params/settings/red/rls-debug
		unless debug-on? [
			either open-logger? [
				init-logger %logger.txt
			][
				init-logger none
			]
		]
	]
]

on-shutdown: function [params [map! none!]][
	set 'shutdown? yes
]

on-textDocument-didOpen: function [params [map!]][
	source: params/textDocument/text
	uri: params/textDocument/uri
	set 'last-uri uri
	diagnostics: add-source uri source
	json-body/method: "textDocument/publishDiagnostics"
	json-body/params: make map! reduce [
		'uri uri
		'diagnostics diagnostics
	]
	response
]

on-textDocument-didClose: function [params [map!]][
	uri: params/textDocument/uri
	set 'last-uri none
	if item: find-source uri [
		write-log rejoin ["[INFO]: remove " uri]
		remove item
	]
]

on-textDocument-didChange: function [params [map!]][
	source: params/contentChanges/1/text
	uri: params/textDocument/uri
	set 'last-uri uri
	diagnostics: add-source uri source
	json-body/method: "textDocument/publishDiagnostics"
	json-body/params: make map! reduce [
		'uri uri
		'diagnostics diagnostics
	]
	response
]

parse-completion-string: function [source line column][
	start: 1
	end: column
	n: -1
	until [
		str: source
		if source: find/tail source #"^/" [n: n + 1]
		any [none? source n = line]
	]
	delimiters: charset " ^-[](){}':;"
	line-str: copy/part str column
	unless ptr: find/last/tail line-str delimiters [
		ptr: line-str
	]
	start: index? ptr
	end: start + column
	reduce [ptr start end]
]

system-completion-kind: function [word [word!]][
	type: type? get word
	kind: case [
		datatype? get word [
			CompletionItemKind/Keyword
		]
		typeset? get word [
			CompletionItemKind/Keyword
		]
		op! = type [
			CompletionItemKind/Operator
		]
		find reduce [action! native! function! routine!] type [
			CompletionItemKind/Function
		]
		object! = type [
			CompletionItemKind/Class
		]
		true [
			CompletionItemKind/Variable
		]
	]
]

complete-system: [
	completions: system-words/get-completions completion-string
	unless any [
		none? completions
		1 >= length? completions
		all [
			2 = length? completions
			"%" = completions/2
		]
	][
		completions-type: completions/1
		completions: next completions
		case [
			completions-type = 'file [
				forall completions [
					append comps make map! reduce [
						'label to string! completions/1
						'kind CompletionItemKind/File
					]
				]
			]
			completions-type = 'path [
				forall completions [
					append comps make map! reduce [
						'label completions/1
						'kind CompletionItemKind/Field
					]
				]
			]
			true [
				forall completions [
					kind: system-completion-kind to word! completions/1
					append comps make map! reduce [
						'label completions/1
						'kind kind
					]
				]
			]
		]
	]
]

complete-context: [
	completions: red-syntax/get-completions syntax completion-string line column
	unless any [
		none? completions
		1 >= length? completions
	][
		completions-type: completions/1
		completions: next completions
		if completions-type = 'word [
			forall completions [
				insert comps make map! reduce [
					'label completions/1/1
					'kind completions/1/2
					'preselect true
				]
			]
		]
	]
]

complete-snippet: [
	if find/match "red.title.snippet" completion-string [
		insert comps make map! reduce [
			'label "red.title.snippet"
			'kind CompletionItemKind/Keyword
			'insertTextFormat 2
			'textEdit make map! reduce [
				'range range
				'newText "Red [^/^-Title: ^"${2:title}^"^/]^/"
			]
		]
	]
	if find/match "red.view.snippet" completion-string [
		insert comps make map! reduce [
			'label "red.view.snippet"
			'kind CompletionItemKind/Keyword
			'insertTextFormat 2
			'textEdit make map! reduce [
				'range range
				'newText "Red [^/^-Title: ^"${2:title}^"^/^-Needs: 'View^/]^/"
			]
		]
	]
	if find/match "either.snippet" completion-string [
		insert comps make map! reduce [
			'label "either.snippet"
			'kind CompletionItemKind/Keyword
			'insertTextFormat 2
			'textEdit make map! reduce [
				'range range
				'newText "either ${1:condition} [^/^-${2:exp}^/][^/^-${3:exp}^/]^/"
			]
		]
	]
	if find/match "func.snippet" completion-string [
		insert comps make map! reduce [
			'label "func.snippet"
			'kind CompletionItemKind/Keyword
			'insertTextFormat 2
			'textEdit make map! reduce [
				'range range
				'newText "func [${1:arg}][^/^-${2:exp}^/]^/"
			]
		]
	]
	if find/match "function.snippet" completion-string [
		insert comps make map! reduce [
			'label "function.snippet"
			'kind CompletionItemKind/Keyword
			'insertTextFormat 2
			'textEdit make map! reduce [
				'range range
				'newText "function [${1:arg}][^/^-${2:exp}^/]^/"
			]
		]
	]
	if find/match "while.snippet" completion-string [
		insert comps make map! reduce [
			'label "while.snippet"
			'kind CompletionItemKind/Keyword
			'insertTextFormat 2
			'textEdit make map! reduce [
				'range range
				'newText "while [${1:condition}][^/^-${2:exp}^/]^/"
			]
		]
	]
	if find/match "forall.snippet" completion-string [
		insert comps make map! reduce [
			'label "forall.snippet"
			'kind CompletionItemKind/Keyword
			'insertTextFormat 2
			'textEdit make map! reduce [
				'range range
				'newText "forall ${1:series} [^/^-${2:exp}^/]^/"
			]
		]
	]
	if find/match "foreach.snippet" completion-string [
		insert comps make map! reduce [
			'label "foreach.snippet"
			'kind CompletionItemKind/Keyword
			'insertTextFormat 2
			'textEdit make map! reduce [
				'range range
				'newText "foreach ${1:iteration} ${2:series} [^/^-${3:exp}^/]^/"
			]
		]
	]
]

on-textDocument-completion: function [params [map!]][
	unless auto-complete? [
		json-body/result: ""
		response
		exit
	]
	uri: params/textDocument/uri
	set 'last-uri uri
	line: params/position/line
	column: params/position/character
	source: none
	syntax: none
	completion-string: none
	if item: find-source uri [
		source: item/1/2
		syntax: item/1/3
		blk: parse-completion-string source line column
		completion-string: blk/1
		write-log mold blk
		range: red-lexer/to-range reduce [line + 1 blk/2] reduce [line + 1 blk/3]
	]
	set 'last-completion completion-string
	write-log mold last-completion

	comps: clear []
	completions: none
	completions-type: none
	kind: none

	unless any [
		none? completion-string
		empty? completion-string
	][
		do bind complete-snippet 'completion-string
		do bind complete-system 'completion-string
		do bind complete-context 'completion-string
	]

	either empty? comps [
		json-body/result: make map! reduce [
			'isIncomplete true
			'items []
		]
	][
		json-body/result: make map! reduce [
			'isIncomplete false
			'items comps
		]
	]

	response
]

resolve-snippet: function [text [string!]][
	switch text [
		"red.title.snippet" [return "Red [ Title ]"]
		"red.view.snippet" [return "Red [ Title NeedsView ]"]
		"either.snippet" [return "either condition [ ][ ]"]
		"func.snippet" [return "func [args][ ]"]
		"function.snippet" [return "function [args][ ]"]
		"while.snippet" [return "while [ condition ] [ ]"]
		"forall.snippet" [return "forall series [ ]"]
		"foreach.snippet" [return "foreach iteration series [ ]"]
	]
	none
]

on-completionItem-resolve: function [params [map!]][
	text: params/label
	hstr: either empty? text [""][
		either last-completion/1 = #"%" [""][
			either snip: resolve-snippet text [snip][
				word: to word! text
				either find system-words/system-words word [
					either datatype? get word [
						rejoin [text " is a base datatype!"]
					][
						system-words/get-word-info word
					]
				][
					either item: find-source last-uri [
						;red-syntax/resolve-completion item/1/3 text
						none
					][none]
				]
			]
		]
	]

	put params 'documentation either hstr [hstr][""]

	json-body/result: params
	response
]

get-selected-text: function [source line column][
	start: 1
	end: column
	n: -1
	until [
		str: source
		if source: find/tail source #"^/" [n: n + 1]
		any [none? source n = line]
	]
	delimiters: charset " ^M^/^-[](){}':;"
	while [
		all [
			column < length? str
			not find delimiters str/(column + 1)
		]
	][column: column + 1]
	line-str: copy/part str column
	unless ptr: find/last/tail line-str delimiters [
		ptr: line-str
	]
	start: index? ptr
	if ptr/1 <> #"%" [
		if slash: find ptr #"/" [
			ptr: copy/part ptr slash
		]
	]
	end: start + length? ptr
	reduce [ptr start end]
]

on-textDocument-symbol: function [params [map!]][
	uri: params/textDocument/uri
	unless item: find-source uri [
		json-body/result: ""
		response
		exit
	]

	blk: item/1/3
	symbols: clear []
	symbol: none
	forall blk [
		if blk/1/1 = none [continue]
		;if set-word? blk/1/1 [
		unless block? blk/1/1 [
			range: red-lexer/to-range blk/1/2 blk/1/3
			symbol: make map! reduce [
				'name		mold blk/1/1
				'kind		blk/1/4/3
				'range		range
				'selectionRange range
			]
			;write-log mold symbol
			append symbols symbol
		]
	]
	json-body/result: symbols
	response
]

on-textDocument-hover: function [params [map!]][
	uri: params/textDocument/uri
	set 'last-uri uri
	line: params/position/line
	column: params/position/character
	range: none
	result: either item: find-source uri [
		blk: get-selected-text item/1/2 line column
		text: blk/1
		range: red-lexer/to-range reduce [line + 1 blk/2] reduce [line + 1 blk/3]
		either empty? text [none][
			hstr: "";red-syntax/resolve-completion item/1/3 text
			either empty? hstr [
				either error? word: try [to word! text][none][
					either find system-words/system-words word [
						either datatype? get word [
							rejoin [text " is a base datatype!"]
						][
							system-words/get-word-info word
						]
					][none]
				]
			][hstr]
		]
	][none]
	json-body/result: make map! reduce [
		'contents either result [rejoin ["```^/" result "^/```"]][""]
		'range range
	]
	response
]

init-logger %logger.txt
write-log mold system/options/args

red-version-error: [
	json-body/id: 0
	json-body/result: none
	json-body/method: none
	json-body/params: none
	json-body/error: make map! reduce [
		'code -32002
		'message "Can't work with this 'Red' version^/Please make sure that your Red toolchain newer than red-09jan19-acf34929.exe!"
	]
	response
	exit
]
unless value? 'input-stdin [
	write-log "console not support `input-stdin`"
	do red-version-error
	exit
]
unless value? 'read-stdin [
	write-log "console not support `read-stdin`"
	do red-version-error
	exit
]

either all [
	system/options/args
	system/options/args/1 <> "debug-on"
][
	init-logger none
	open-logger?: false
	debug-on?: false
][
	open-logger?: true
	debug-on?: true
]

watch: has [res] [
	while [not shutdown?][
		if error? res: try [process lsp-read][
			write-log mold res
		]
	]
	write-log "[shutdown]"
]

watch
