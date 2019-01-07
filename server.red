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

code-symbols: clear []

find-source: function [uri [string!]][
	forall code-symbols [
		if code-symbols/1/1 = uri [
			return code-symbols
		]
	]
	false
]

to-range: function [start [block!] end [block!]][
	make map! reduce [
		'start make map! reduce [
			'line start/1 - 1 'character start/2 - 1
		]
		'end make map! reduce [
			'line end/1 - 1 'character end/2 - 1
		]
	]
]

add-source: function [uri [string!] code [string!]][
	if map? res: try [red-lexer/analysis code][
		range: to-range res/pos res/pos
		return reduce [
			make map! reduce [
				'range range
				'severity 1
				'code 1
				'source "lexer"
				'message form res/err
			]
		]
	]
	if error? res: try [red-syntax/analysis res][
		pc: res/arg3
		write-log mold res
		range: to-range pc/2 pc/2
		return reduce [
			make map! reduce [
				'range range
				'severity 1
				'code 1
				'source "syntax"
				'message res/arg2
			]
		]
	]

	if item: find-source uri [
		item/1/2: code
		item/1/3: res
		return []
	]
	append/only code-symbols reduce [uri code res]
	[]
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
	write-stdout to string! length? response
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
		"initialize"					[on-initialize params]
		"textDocument/didOpen"			[on-textDocument-didOpen params]
		"textDocument/didClose"			[on-textDocument-didClose params]
		"textDocument/didChange"		[on-textDocument-didChange params]
		"textDocument/completion"		[on-textDocument-completion params]
		"textDocument/documentSymbol"	[on-textDocument-symbol params]
		"textDocument/hover"			[on-textDocument-hover params]
		"completionItem/resolve"		[on-completionItem-resolve params]
	]
]

TextDocumentSyncKind: [
	None		0
	Full		1
	Incremental	2
]


on-initialize: function [params [map!]][
	trigger-chars: [
		"/" "%"
		"a" "b" "c" "d" "e" "f" "g" "h" "i" "j" "k" "l" "m" "n" "o" "p" "q" "r" "s" "t" "u" "v" "w" "x" "y" "z"
		"A" "B" "C" "D" "E" "F" "G" "H" "I" "J" "K" "L" "M" "N" "O" "P" "Q" "R" "S" "T" "U" "V" "W" "X" "Y" "Z"
	]

	json-body/result: make map! reduce [
		'capabilities make map! reduce [
			'textDocumentSync TextDocumentSyncKind/Full
			;'textDocumentSync make map! reduce [
			;	'openClose			true
			;	'change				0
			;	'willSave			false
			;	'willSaveWaitUntil	false
			;	'save				make map! reduce ['includeText true]
			;]

			;'documentFormattingProvider true
			;'documentRangeFormattingProvider true
			;'documentOnTypeFormattingProvider make map! reduce ['firstTriggerCharacter "{" 'moreTriggerCharacter ""]
			;'codeActionProvider true
			'completionProvider make map! reduce ['resolveProvider true 'triggerCharacters trigger-chars]
			;'signatureHelpProvider make map! reduce ['triggerCharacters ["."]]
			;'definitionProvider true
			;'documentHighlightProvider true
			'hoverProvider true
			;'renameProvider true
			;'documentSymbolProvider true
			;'workspaceSymbolProvider true
			;'referencesProvider true
			;'executeCommandProvider make map! reduce ['commands "Red.applyFix"]
		]
	]
	response
]

on-textDocument-didOpen: function [params [map!]][
	source: params/textDocument/text
	uri: params/textDocument/uri
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
	if item: find-source uri [
		write-log rejoin ["[INFO]: remove " uri]
		remove item
	]
]

on-textDocument-didChange: function [params [map!]][
	source: params/contentChanges/1/text
	uri: params/textDocument/uri
	diagnostics: add-source uri source
	json-body/method: "textDocument/publishDiagnostics"
	json-body/params: make map! reduce [
		'uri uri
		'diagnostics diagnostics
	]
	response
]

parse-completion-string: function [source line column][
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
	ptr
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

system-completion: [
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
						'label find/tail completions/1 "/"
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

context-completion: [
	completions: red-syntax/get-completions syntax completion-string
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
				]
			]
		]
	]
]

on-textDocument-completion: function [params [map!]][
	uri: params/textDocument/uri
	line: params/position/line
	column: params/position/character
	source: none
	syntax: none
	completion-string: none
	if item: find-source uri [
		source: item/1/2
		syntax: item/1/3
		completion-string: parse-completion-string source line column
	]

	comps: clear []
	completions: none
	completions-type: none
	kind: none

	unless any [
		none? completion-string
		empty? completion-string
	][
		do bind system-completion 'completion-string
		do bind context-completion 'completion-string
	]

	either empty? comps [
		json-body/result: make map! reduce [
			'isIncomplete true
			'items []
		]
	][
		json-body/result: make map! reduce [
			'items comps
		]
	]

	response
]

get-selected-text: function [source line column][
	n: -1
	until [
		str: source
		if source: find/tail source #"^/" [n: n + 1]
		any [none? source n = line]
	]
	delimiters: charset " ^-[](){}':;"
	while [not find delimiters str/(column + 1)][column: column + 1]
	line-str: copy/part str column
	unless ptr: find/last/tail line-str delimiters [
		ptr: line-str
	]
	if slash: find ptr #"/" [
		ptr: copy/part ptr slash
	]
	ptr
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
			range: to-range blk/1/2 blk/1/3
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
	line: params/position/line
	column: params/position/character
	result: either item: find-source uri [
		source: item/1/2
		word: to word! get-selected-text source line column
		either hstr: system-words/get-word-info word [
			make map! reduce [
				'contents rejoin ["```^/" hstr "^/```"]
			]
		][""]
	][""]
	json-body/result: result
	response
]

on-completionItem-resolve: function [params [map!]][
	text: params/label
	kind: CompletionItemKind/Text
	hstr: either empty? text [""][
		word: to word! text
		either find system-words/system-words word [
			kind: system-completion-kind word
			either datatype? get word [
				rejoin [text " is a base datatype!"]
			][
				system-words/get-word-info word
			]
		][
			""
		]
	]

	json-body/result: make map! reduce [
		'label text
		'kind kind
		'documentation hstr
	]
	response
]

init-logger %logger.txt
write-log mold system/options/args

red-version-error: [
	json-body/method: "$/cancelRequest"
	json-body/params: make map! reduce [
		'id 0
	]
	response

	json-body/method: "window/showMessage"
	json-body/params: make map! reduce [
		'type 1
		'message "can't work with this 'Red' version, please update to a latest(daily) version!"
	]
	response
	exit
]
unless value? 'input-stdin [
	write-log "console not support `input-stdin`"
	;do red-version-error
	exit
]
unless value? 'read-stdin [
	write-log "console not support `read-stdin`"
	;do red-version-error
	exit
]

if all [
	system/options/args
	system/options/args/1 <> "debug-on"
][
	init-logger none
]

watch: does [
	while [true][
		attempt [process lsp-read]
	]
]

watch
