function! zoxide#exec(cmd) abort
    let result = systemlist(join(a:cmd))
    if v:shell_error
        echohl ErrorMsg | echo join(result, '\n') | echohl None
    endif
    return result
endfunction

function! s:change_directory(directory, cmd) abort
    if !isdirectory(a:directory) | echoerr 'Not a directory' | return | endif

    exe a:cmd a:directory
    pwd
    call zoxide#exec([get(g:, 'zoxide_executable', 'zoxide'), 'add'])
endfunction

function! zoxide#z(query, local) abort
    let directory = a:query ==# '' ? $HOME : a:query
    let cmd = a:local ? 'lcd' : 'cd'

    if isdirectory(directory)
        call s:change_directory(directory, cmd)
        return
    endif
    let result = zoxide#exec([get(g:, 'zoxide_executable', 'zoxide'), 'query', directory])[0]
    if !v:shell_error | call s:change_directory(result, cmd) | endif
endfunction

function! zoxide#zi(query, local, bang) abort
    if !exists('g:loaded_fzf') | echoerr 'The fzf.vim plugin must be installed' | return | endif

    function! s:handle_fzf_result(result) abort closure
        let cmd = a:local ? 'lcd' : 'cd'
        let directory = substitute(a:result, '^\s*\d*\s*', '', '')
        call s:change_directory(directory, cmd)
    endfunction

    call fzf#run(fzf#wrap('zoxide', {
                \ 'source': zoxide#exec([get(g:, 'zoxide_executable', 'zoxide'), 'query', '--list', '--score', a:query]),
                \ 'sink': funcref('s:handle_fzf_result'),
                \ 'options': '--prompt="Zoxide> "',
                \ }, a:bang))
endfunction
