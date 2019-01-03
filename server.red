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

source-code: ""
languageId: ""
code-symbols: clear []

find-source: function [uri [string!]][
	forall code-symbols [
		if code-symbols/1/1 = uri [
			return code-symbols/1
		]
	]
	false
]

parse-source: function [code [string!]][
	blk: red-lexer/analysis code
	red-syntax/analysis blk
	blk
]

add-source: function [uri [string!] code [string!]][
	blk: try [parse-source code]
	if item: find-source uri [
		item/2: code
		item/3: blk
		return
	]
	append/only code-symbols reduce [uri code blk]
	write-log mold code-symbols
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

write-response: func [response][
	write-stdout "Content-Length: "
	write-stdout to string! length? response
	write-newline
	write-stdout {Content-Type: application/vscode-jsonrpc; charset=utf-8}
	write-newline write-newline
	write-stdout response
]

write-log: func [str [string!]][
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

process: func [data [string!]
	/local script resp
][
	script: first json/decode data
	json-body/id: script/id
	json-body/result: none
	json-body/method: none
	json-body/params: none
	json-body/error: none
	dispatch-method script/method script/params
]

response: has [resp][
	resp: json/encode json-body
	write-response resp
	write-log rejoin ["[OUTPUT] Content-Length: " length? resp]
	write-log resp write-log ""
]

lsp-read: func [/local header len bin n str][
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

dispatch-method: func [method [string!] params][
	switch method [
		"initialize"					[on-initialize params]
		"textDocument/didOpen"			[on-textDocument-didOpen params]
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
			'documentSymbolProvider true
			;'workspaceSymbolProvider true
			;'referencesProvider true
			;'executeCommandProvider make map! reduce ['commands "Red.applyFix"]
		]
	]
	response
]

on-textDocument-didOpen: function [params [map!]][
	source-code: params/textDocument/text
	uri: params/textDocument/uri
	add-source uri source-code
	languageId: params/textDocument/languageId
	json-body/method: "textDocument/publishDiagnostics"
	json-body/params: make map! reduce [
		'uri uri
		'diagnostics reduce []
	]
	response
]

on-textDocument-didChange: function [params [map!]][
	source-code: params/contentChanges/1/text
	uri: params/textDocument/uri
	add-source uri source-code
	json-body/method: "textDocument/publishDiagnostics"
	json-body/params: make map! reduce [
		'uri uri
		'diagnostics []
	]
	response
]

;-- Use the completion function which is used by the red console
;-- TBD replace it with a sophisticated one
parse-completions: function [source line column][
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
	if any [none? ptr empty? ptr][return []]
	system-words/get-completions ptr
]

get-completion-kind: function [text [string!]][
	if empty? text [return CompletionItemKind/Text]
	type: system-words/get-type to word! text
	kind: case [
		#"!" = last text [
			CompletionItemKind/Keyword
		]
		op! = type [
			CompletionItemKind/Operator
		]
		any [
			type = action!
			type = native!
			type = function!
			type = routine!
		][
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

on-textDocument-completion: function [params [map!]][
	line: params/position/line
	column: params/position/character
	items: parse-completions source-code line column
	if any [
		1 >= length? items
		all [
			2 = length? items
			"%" = items/2
		]
	][
		json-body/result: make map! reduce [
			'isIncomplete true
			'items []
		]
		response
		exit
	]
	item-type: items/1
	items: next items
	comps: clear []
	case [
		item-type = 'file [
			forall items [
				append comps make map! reduce [
					'label skip items/1 1
					'kind CompletionItemKind/File
				]
			]
		]
		item-type = 'path [
			forall items [
				append comps make map! reduce [
					'label find/tail items/1 "/"
					'kind CompletionItemKind/Field
				]
			]
		]
		true [
			forall items [
				kind: get-completion-kind items/1
				append comps make map! reduce [
					'label items/1
					'kind kind
				]
			]
		]
	]

	json-body/result: make map! reduce [
		'items comps
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
	json-body/result: ""
	response
]

on-textDocument-hover: function [params [map!]][
	line: params/position/line
	column: params/position/character
	word: to word! get-selected-text source-code line column
	either hstr: system-words/get-word-info word [
		json-body/result: make map! reduce [
			'contents rejoin ["```^/" hstr "^/```"]
		]
	][
		json-body/result: ""
	]
	response
]

on-completionItem-resolve: function [params [map!]][
	text: params/label
	kind: get-completion-kind text
	hstr: either empty? text [""][
		word: to word! text
		either find system-words/base-types word [
			rejoin [text " is a base datatype!"]
		][
			system-words/get-word-info word
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
