scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim

let s:TRUE = !0
let s:FALSE = 0
let s:DIRECTIONS = {
\     'RIGHT': 1,
\     'LEFT' : 2,
\ }

function! glowshi_ft#gs_f()
    call s:init(s:FALSE, s:DIRECTIONS.RIGHT, s:FALSE)
    call s:glowshi_ft()
endfunction

function! glowshi_ft#gs_fv()
    call s:init(s:FALSE, s:DIRECTIONS.RIGHT, s:TRUE)
    call s:glowshi_ft()
endfunction

function! glowshi_ft#gs_F()
    call s:init(s:FALSE, s:DIRECTIONS.LEFT, s:FALSE)
    call s:glowshi_ft()
endfunction

function! glowshi_ft#gs_Fv()
    call s:init(s:FALSE, s:DIRECTIONS.LEFT, s:TRUE)
    call s:glowshi_ft()
endfunction

function! glowshi_ft#gs_t()
    call s:init(s:TRUE, s:DIRECTIONS.RIGHT, s:FALSE)
    call s:glowshi_ft()
endfunction

function! glowshi_ft#gs_tv()
    call s:init(s:TRUE, s:DIRECTIONS.RIGHT, s:TRUE)
    call s:glowshi_ft()
endfunction

function! glowshi_ft#gs_T()
    call s:init(s:TRUE, s:DIRECTIONS.LEFT, s:FALSE)
    call s:glowshi_ft()
endfunction

function! glowshi_ft#gs_Tv()
    call s:init(s:TRUE, s:DIRECTIONS.LEFT, s:TRUE)
    call s:glowshi_ft()
endfunction

function s:init(till_before, direction, visualmode)
    let s:till_before = a:till_before
    let s:direction = a:direction
    let s:visualmode = a:visualmode
    let s:mode = mode(1)
    let s:current_pos = getpos('.')
    let s:feedkey = ''
    let s:orig_ignorecase = &ignorecase
    let &ignorecase = g:glowshi_ft_ignorecase
endfunction

function! s:glowshi_ft()
    try
        echo 'char: '
        let c = nr2char(getchar())
        echon c

        let poslist = s:get_poslist(c)

        if len(poslist) > 0
            let pos = s:choose_pos(poslist)
            if type(pos) == type([])
                call s:move(pos)
                if s:feedkey != ''
                    call feedkeys(s:feedkey)
                endif
            endif
        endif
    finally
        call s:clean()
    endtry
endfunction

function s:get_poslist(c)
    let poslist = []
    let flag = (s:direction == s:DIRECTIONS.LEFT) ? 'b' : ''
    while search("\\V" . a:c, flag, line('.'))
        call add(poslist, getpos('.'))
    endwhile
    call setpos('.', s:current_pos)
    return poslist
endfunction

function! s:choose_pos(poslist)
    if len(a:poslist) == 1
        return a:poslist[0]
    endif

    if s:direction == s:DIRECTIONS.RIGHT
        let selected = 0
    elseif s:direction == s:DIRECTIONS.LEFT
        call reverse(a:poslist)
        let selected = len(a:poslist) - 1
    endif

    let vcount = 0

    let orig_cursor = s:hide_cursor()

    try
        while s:TRUE
            let match_candidates = matchadd('GlowshiFtCandidates', s:regexp_candidates(a:poslist))
            let match_selected = matchadd('GlowshiFtSelected', s:regexp(a:poslist[selected]))

            redraw
            if g:glowshi_ft_timeoutlen > 0
                let c = nr2char(s:getchar_with_timeout())
            else
                let c = nr2char(getchar())
            endif

            call matchdelete(match_selected)
            call matchdelete(match_candidates)

            if c == 'h'
                let selected = (selected - ((vcount > 0) ? vcount : 1) + len(a:poslist)) % len(a:poslist)
                let vcount = 0
            elseif c == 'l'
                let selected = (selected + ((vcount > 0) ? vcount : 1)) % len(a:poslist)
                let vcount = 0
            elseif c == '^'
                let selected = 0
            elseif c == '$'
                let selected = len(a:poslist) - 1
            elseif c =~ '^[0-9]$'
                if vcount == 0
                    if c != '0'
                        let vcount = c
                    else
                        let selected = 0
                    endif
                else
                    let vcount .= c
                endif
            elseif c =~ g:glowshi_ft_fix_key
                break
            elseif c =~ g:glowshi_ft_cancel_key
                return
            else
                if c != ''
                    let s:feedkey = ((vcount > 1) ? vcount : '') . c
                endif
                break
            endif
        endwhile

        return a:poslist[selected]
    finally
        call s:show_cursor(orig_cursor)
    endtry
endfunction

function s:regexp(pos)
    return printf('\%%%dl\%%%dc', a:pos[1], a:pos[2])
endfunction

function s:regexp_candidates(poslist)
    let pattern = []
    for pos in a:poslist
        call add(pattern, s:regexp(pos))
    endfor
    return join(pattern, '\|')
endfunction

function! s:getchar_with_timeout()
    let start = reltime()
    let key = ''
    while s:TRUE
        let duration_sec = str2float(reltimestr(reltime(start)))
        if duration_sec * 1000 > g:glowshi_ft_timeoutlen
            break
        endif
        let key = getchar(0)
        if type(key) != 0 || key != 0
            break
        endif
        sleep 50m
    endwhile
    return key
endfunction

function! s:move(pos)
    let pos = a:pos[:]
    if s:till_before == s:TRUE
        if s:direction == s:DIRECTIONS.LEFT
            let pos[2] +=1
        elseif s:direction == s:DIRECTIONS.RIGHT
            let pos[2] -=1
        endif
    endif

    if s:mode == 'no'
        if s:direction == s:DIRECTIONS.RIGHT
            let pos[2] += 1
        endif
    elseif s:visualmode == s:TRUE
        normal! gv
    endif

    call setpos('.', pos)
endfunction

function s:clean()
    if getpos('.') == s:current_pos && s:visualmode == s:TRUE
        normal! gv
    endif
    let &ignorecase = s:orig_ignorecase
    redraw!
endfunction

function! s:hide_cursor()
    if has('gui_running')
        let hlid = hlID('Cursor')
        let hlid_trans = synIDtrans(hlid)
        if hlid != hlid_trans
            let orig_cursor = synIDattr(hlid_trans, 'name')
            highlight link Cursor NONE
        else
            redir => hl
            silent highlight Cursor
            redir END
            let orig_cursor = matchstr(substitute(hl, '[\r\n]', '', 'g'), 'xxx \zs.*')
            highlight Cursor NONE
        endif
    else
        let orig_cursor = &t_ve
        let &t_ve = ''
    endif
    return orig_cursor
endfunction

function! s:show_cursor(orig_cursor)
    if has('gui_running')
        if hlexists(a:orig_cursor)
            execute 'highlight link Cursor ' . a:orig_cursor
        else
            execute 'highlight Cursor ' . a:orig_cursor
        endif
    else
        let &t_ve = a:orig_cursor
    endif
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
