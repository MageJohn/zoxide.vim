function! s:build_cmd(cmd, query) abort
    return join([get(g:, 'zoxide_executable', 'zoxide')] + a:cmd + map(copy(a:query), 'shellescape(v:val)'), ' ')
endfunction

function! zoxide#exec(cmd, query) abort
    let result = systemlist(s:build_cmd(a:cmd, a:query))
    if v:shell_error
        echohl ErrorMsg | echo join(result, "\n") | echohl None
    endif
    return result
endfunction

function! s:change_directory(cd_command, directory) abort
    try
        exe a:cd_command a:directory
    catch
        echohl ErrorMsg | echomsg v:exception | echohl None
        return
    endtry

    pwd

    if get(g:, 'zoxide_update_score', 1) && get(g:, 'zoxide_hook', 'none') !=# 'pwd'
        call zoxide#exec(['add'], [getcwd()])
    endif
endfunction

function! zoxide#z(cd_command, ...) abort
    let query = empty(a:000) ? [$HOME] : a:000

    if len(query) == 1 && (query[0] ==# '-' || isdirectory(query[0]))
        call s:change_directory(a:cd_command, query[0])
        return
    endif
    let result = zoxide#exec(['query', '--exclude', shellescape(getcwd())], query)[0]
    if !v:shell_error | call s:change_directory(a:cd_command, result) | endif
endfunction

function! zoxide#handle_select_result(cd_command, result) abort
    let directory = substitute(a:result, '^\s*\d*\s*', '', '')
    call s:change_directory(a:cd_command, directory)
endfunction

if has('nvim') && get(g:, 'zoxide_use_select', 0)
    function! zoxide#zi(cd_command, bang, ...) abort
        call luaeval('require("zoxide-vim").select(_A[1], _A[2])', [
                    \ zoxide#exec(['query', '--list', '--score'], a:000),
                    \ a:cd_command,
                    \ ])
    endfunction
else
    function! zoxide#zi(cd_command, bang, ...) abort
        if !exists('g:loaded_fzf') | echoerr 'The fzf.vim plugin must be installed' | return | endif

        call fzf#run(fzf#wrap('zoxide', {
                    \ 'source': s:build_cmd(['query', '--list', '--score'], a:000),
                    \ 'sink': funcref('zoxide#handle_select_result', [a:cd_command]),
                    \ 'options': '--prompt="Zoxide> "',
                    \ }, a:bang))
    endfunction
endif
