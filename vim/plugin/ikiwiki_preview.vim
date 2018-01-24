let g:ikiwiki_preview_bin = expand('~/sw_projects/ikiwiki-tavi/ikiwiki-preview/ikiwiki-preview/bin/ikiwiki-preview.pl')
let g:ikiwiki_preview_vim_port = 20345

command! -nargs=0 IkiwikiPreviewEnable call ikiwiki#preview#enable()
command! -nargs=0 IkiwikiPreviewEnableLite call ikiwiki#preview#enable_lite()
command! -nargs=0 IkiwikiPreviewDisable call ikiwiki#preview#disable()
command! -nargs=0 IkiwikiPreviewUpdate call ikiwiki#preview#update()
command! -nargs=0 IkiwikiPreviewScroll call ikiwiki#preview#move_cursor()
