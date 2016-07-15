function! IkiWikiPreviewHandler(channel, msg)

endfunction

function! s:send_by_channel(msg) abort
	let handle = ch_open('localhost:' . g:ikiwiki_preview_vim_port,
		\ {
		\ 'callback': 'IkiWikiPreviewHandler',
		\ 'mode': 'json',
		\ 'waittime': 3000,
		\ 'timeout': 0 })
	call ch_sendexpr(handle, a:msg)
	call ch_close(handle)
endfunction

function! ikiwiki#preview#update()
	" TODO
	let msg = {}
	let msg.text = getline(0, '$')
	let msg.ext = &filetype
	let msg.event = 'update'
	call s:send_by_channel( msg )
endfunction

function! ikiwiki#preview#move_cursor()
	let msg = {}
	let msg.line = line('w0')
	let msg.cursor_position = getcurpos()
	let msg.event = 'move'
	call s:send_by_channel(msg)
endfunction


function! s:start_server()
	call system(g:ikiwiki_preview_bin)
endfunction

function! s:stop_server()
" TODO
endfunction

function! ikiwiki#preview#enable() abort
	augroup ikiwiki_preview
		autocmd!
		autocmd TextChanged,TextChangedI * call ikiwiki#preview#update()
		autocmd BufEnter * call ikiwiki#preview#update()
		autocmd CursorMoved,CursorMovedI * call ikiwiki#preview#move_cursor()
		autocmd VimLeave * call s:stop_server()
	augroup END
	call s:start_server()
endfunction

function! ikiwiki#preview#disable() abort
	augroup ikiwiki_preview
		autocmd!
	augroup END
	call s:stop_server()
endfunction
