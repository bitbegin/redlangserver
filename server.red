Red [
	Title:   "Red server for Visual Studio Code"
	Author:  "bitbegin"
	File: 	 %server.red
	Tabs:	 4
	Rights:  "Copyright (C) 2011-2019 Red Foundation. All rights reserved."
	License: "BSD-3 - https://github.com/red/red/blob/origin/BSD-3-License.txt"
]

#include %lsp-const.red
#include %system-words.red
#include %lexer.red
#include %semantic.red

logger: none
open-logger?: false
debug-on?: false

client-caps: none
shutdown?: no

versions: []
workspace-folder: []
excluded-folder: ""

init-logger: func [_logger [file! none!]][
	logger: _logger
	if logger [
		if exists? _logger [
			txt: read _logger
			write %logger.bak txt
		]
		delete logger	;-- in case, the file not deleted
		write logger "^/"
	]
]

write-newline: does [
	#either config/OS = 'Windows [
		write-stdout "^/"
	][
		write-stdout "^M^/"
	]
]

write-response: function [resp][
	write-stdout "Content-Length: "
	write-stdout to string! length? nresp: to binary! resp
	write-newline
	write-stdout {Content-Type: application/vscode-jsonrpc; charset=utf-8}
	write-newline write-newline
	write-stdout nresp
]

write-log: function [str [string!]][
	if logger [
		unless empty? str [write/append logger str]
		write/append logger "^/"
	]
]

json-body: none

process: function [data [string!]][
	script: load-json data
	set 'json-body copy #()
	json-body/jsonrpc: "2.0"
	if script/id [
		json-body/id: script/id
	]
	if script/method [
		dispatch-method script/method script/params
	]
	true
]

response: function [][
	resp: to-json json-body
	write-response resp
	write-log rejoin ["[NOW] " mold now/precise]
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
		"initialize"							[on-initialize params]
		"initialized"							[on-initialized params]
		"workspace/didChangeConfiguration"		[on-didChangeConfiguration params]
		"workspace/didChangeWorkspaceFolders"	[on-didChangeWorkspaceFolders params]
		"workspace/didChangeWatchedFiles"		[on-didChangeWatchedFiles params]
		"shutdown"								[on-shutdown params]
		"textDocument/didOpen"					[on-textDocument-didOpen params]
		"textDocument/didClose"					[on-textDocument-didClose params]
		"textDocument/didChange"				[on-textDocument-didChange params]
		"textDocument/didSave"					[on-textDocument-didSave params]
		"textDocument/completion"				[on-textDocument-completion params]
		"completionItem/resolve"				[on-completionItem-resolve params]
		"textDocument/documentSymbol"			[on-textDocument-symbol params]
		"textDocument/hover"					[on-textDocument-hover params]
		"textDocument/definition"				[on-textDocument-definition params]
	]
]

TextDocumentSyncKind: [
	None		0
	Full		1
	Incremental	2
]


trigger-string: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/%.+-_=?*&~?`"
trigger-chars: []
forall trigger-string [
	append trigger-chars to string! trigger-string/1
]
on-initialize: function [params [map!]][
	set 'client-caps params
	if params/initializationOptions [
		set 'excluded-folder params/initializationOptions/excludedPath
	]
	if ws: params/workspaceFolders [
		forall ws [
			append workspace-folder ws/1/uri
		]
	]
	caps: copy #()
	put caps 'textDocumentSync TextDocumentSyncKind/Incremental
	put caps 'hoverProvider true
	put caps 'completionProvider
		make map! reduce [
			'resolveProvider true
			'triggerCharacters trigger-chars
		]
	put caps 'definitionProvider true
	put caps 'documentSymbolProvider true
	;-- slow for now
	;put caps 'workspace make map! reduce [
	;	'workspaceFolders make map! reduce [
	;		'supported true
	;		'changeNotifications true
	;	]
	;]

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

register-watched-files: function [][
	json-body/id: "didChangeWatchedFiles"
	json-body/result: none
	json-body/method: "client/registerCapability"
	json-body/params: make map! reduce [
		'registrations	reduce [
			make map! reduce [
				'id		"didChangeWatchedFiles"
				'method	"workspace/didChangeWatchedFiles"
				'registerOptions make map! reduce [
					'watchers reduce [
						make map! reduce [
							'globPattern	"**/*.{red,reds}"
							'kind 7
						]
					]
				]
			]
		]
	]
	response
]

on-initialized: function [params [map! none!]][
	exit			;-- slow for now
	diags: semantic/add-folder workspace-folder excluded-folder
	if empty? diags [
		exit
	]
	forall diags [
		json-body/method: "textDocument/publishDiagnostics"
		json-body/params: diags/1
		response
	]
]

on-didChangeConfiguration: function [params [map! none!]][
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
	;-- slow for now
	;register-watched-files
]

on-didChangeWorkspaceFolders: function [params [map! none!]][
	added: params/event/added
	removed: params/event/removed
	unless empty? added [
		added-folder: make block! 4
		forall added [
			append added-folder added/1/uri
		]
		diags: semantic/add-folder added-folder excluded-folder
		if empty? diags [
			exit
		]
		forall diags [
			json-body/method: "textDocument/publishDiagnostics"
			json-body/params: diags/1
			response
		]
	]
	unless empty? removed [
		removed-folder: make block! 4
		forall removed [
			append removed-folder removed/1/uri
		]
		diags: semantic/remove-folder removed-folder
		if empty? diags [
			exit
		]
		forall diags [
			json-body/method: "textDocument/publishDiagnostics"
			json-body/params: diags/1
			response
		]
	]
]

on-didChangeWatchedFiles: function [params [map! none!]][
	changes: params/changes
	forall changes [
		uri: changes/1/uri
		either changes/1/type = 3 [
			if vs: find-uri uri [
				remove vs
			]
			if item: semantic/find-source uri [
				write-log rejoin ["[INFO]: remove " uri]
				remove item
			]
			clear-diag uri
		][
			if exists? file: lexer/uri-to-file uri [
				source: read file
				diags: semantic/add-source uri source
				resp-diags diags uri
			]
		]
	]
]

on-shutdown: function [params [map! none!]][
	set 'shutdown? yes
]

clear-diag: function [uri [string!]][
	json-body/method: "textDocument/publishDiagnostics"
	json-body/params: make map! reduce [
		'uri	uri
		'diagnostics []
	]
	response
]

resp-diags: function [diags [block!] uri [string!]][
	if empty? diags [
		clear-diag uri
		exit
	]
	forall diags [
		json-body/method: "textDocument/publishDiagnostics"
		json-body/params: diags/1
		response
	]
]

find-uri: function [uri [string!]][
	vs: versions
	forall vs [
		if vs/1/uri = uri [
			return vs
		]
	]
	none
]

on-textDocument-didOpen: function [params [map!]][
	source: params/textDocument/text
	uri: params/textDocument/uri
	version: params/textDocument/version
	either vs: find-uri uri [
		vs/1/version: version
	][
		repend/only versions ['uri uri 'version version]
	]

	diags: semantic/add-source uri source
	resp-diags diags uri
]

on-textDocument-didClose: function [params [map!]][
	uri: params/textDocument/uri
	if vs: find-uri uri [
		remove vs
	]
	if all [
		not semantic/workspace-file? uri
		item: semantic/find-source uri
	][
		write-log rejoin ["[INFO]: remove " uri]
		remove item
	]
	clear-diag uri
]

on-textDocument-didChange: function [params [map!]][
	uri: params/textDocument/uri
	unless params/contentChanges/1/range [
		source: params/contentChanges/1/text
		diags: semantic/add-source uri source
		resp-diags diags uri
		exit
	]
	version: params/textDocument/version
	contentChanges: params/contentChanges
	if all [
		vs: find-uri uri
		(vs/1/version + 1) = version
	][
		unless diags: semantic/update-source uri contentChanges [
			json-body/error: make map! reduce [
				'code -32002
				'message "create ast error, please reopen this file!"
			]
			write-log "** unknown lexer bug **"
			response
			exit
		]
		resp-diags diags uri
		vs/1/version: version
		exit
	]
	write-log "** lost some text **"
	response
]

on-textDocument-didSave: function [params [map!]][
	uri: params/textDocument/uri
	unless exists? file: lexer/uri-to-file uri [
		write-log "** can't find file: **"
		write-log mold file
		exit
	]
	source: read file
	if top: semantic/find-top uri [
		;source: top/1/source
		either not empty? diags: semantic/add-source uri source [
			forall diags [
				json-body/method: "textDocument/publishDiagnostics"
				json-body/params: diags/1
				response
			]
		][
			clear-diag uri
		]
	]
]

on-textDocument-completion: function [params [map!]][
	uri: params/textDocument/uri
	line: params/position/line
	column: params/position/character
	comps: completion/complete uri line + 1 column + 1
	json-body/result: make map! reduce [
		;'isIncomplete true
		'items comps
	]
	response
]

on-completionItem-resolve: function [params [map!]][
	hstr: completion/resolve params
	put params 'documentation either hstr [hstr][""]
	json-body/result: params
	response
]

on-textDocument-hover: function [params [map!]][
	uri: params/textDocument/uri
	line: params/position/line
	column: params/position/character
	result: completion/hover uri line + 1 column + 1
	json-body/result: make map! reduce [
		'contents either result [rejoin ["```^/" result "^/```"]][""]
		'range none
	]
	response
]

on-textDocument-definition: function [params [map!]][
	uri: params/textDocument/uri
	line: params/position/line
	column: params/position/character
	unless result: completion/definition uri line + 1 column + 1 [result: []]
	json-body/result: result
	response
]

on-textDocument-symbol: function [params [map!]][
	uri: params/textDocument/uri
	unless result: completion/symbols uri [result: []]
	json-body/result: result
	response
]

init-logger %logger.txt
semantic/write-log: :write-log
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
