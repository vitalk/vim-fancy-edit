" Internal variables and functions {{{

let s:id = 0
let s:fancy_objects = []


fun! s:error(message)
  echohl ErrorMsg | echomsg a:message | echohl NONE
  let v:errmsg = a:message
endf

fun! s:function(name) abort
  return function(a:name)
endf

fun! s:add_methods(namespace, method_names) abort
  for name in a:method_names
    let s:{a:namespace}_prototype[name] = s:function('s:'.a:namespace.'_'.name)
  endfor
endf

fun! s:get_id()
  let s:id += 1
  return s:id
endf

" }}}
" Buffer prototype {{{

let s:buffer_prototype = {}

fun! s:buffer(...) abort
  let buffer = {
        \ '#': bufnr(a:0 ? a:1 : '%'),
        \ 'id': (a:0 > 1 && a:2) ? a:2 : 0,
        \ 'pos': getpos('.')
        \ }
  call extend(buffer, s:buffer_prototype, 'keep')
  return buffer
endf

fun! s:buffer_getvar(var) dict abort
  return getbufvar(self['#'], a:var)
endf

fun! s:buffer_setvar(var, value) dict abort
  return setbufvar(self['#'], a:var, a:value)
endf

fun! s:buffer_spec() dict abort
  let full = bufname(self['#'])
  if full =~# '^fancy://.*//\d\+'
    let path = substitute(full, '^fancy://\(.*\)//\d\+', '\1', '')
  elseif full != ''
    let path = fnamemodify(full, ':p')
  else
    let path = ''
  endif

  let id = (full =~# '^fancy://.*//\d\+')
        \ ? substitute(full, '^fancy://.*//\(\d\+\)', '\1', '')
        \ : self.id
  return 'fancy://'.path.'//'.id
endf

fun! s:buffer_name() dict abort
  return self.path()
endf

fun! s:buffer_path() dict abort
  return substitute(self.spec(), '^fancy://\(.*\)//\d\+', '\1', '')
endf

fun! s:buffer_fancy_id() dict abort
  return substitute(self.spec(), '^fancy://.*//\(\d\+\)', '\1', '')
endf

fun! s:buffer_exists() dict abort
  return bufexists(self.spec()) && (bufwinnr(self.spec()) != -1)
endf

fun! s:buffer_delete() dict abort
  call delete(self.name())

  if fnamemodify(bufname('$'), ':p') ==# self.name()
    sil exe 'bwipeout '.bufnr('$')
  endif
endf

fun! s:buffer_read(...) dict abort
  return getbufline(self.name(),
        \ a:0 ? a:1 : 1,
        \ (a:0 == 2) ? a:2 : '$')
endf

fun! s:buffer_write(...) dict abort
  if empty(a:0)
    return
  elseif a:0 == 1
    let [lnum, text] = [1, a:1]
  else
    let [lnum, text] = [a:1, a:2]
  endif
  return setline(lnum, text)
endf

" Returns the buffer content with or without indentation.
"
" The arguments are:
" - the indentation level (dedent buffer when value is negative and indent otherwise)
" - the line number to start (read from the beginning if not set)
" - the line number to end (process until the end if not set)
fun! s:buffer_indent(indent, ...) dict abort
  let start_at = a:0 ? a:1 : 1
  let end_at   = (a:0 > 1) ? a:2 : '$'
  return a:indent < 0
        \ ? map(self.read(start_at, end_at), 'fancy#util#dedent_line(v:val, a:indent)')
        \ : map(self.read(start_at, end_at), 'fancy#util#indent_line(v:val, a:indent)')
endf

call s:add_methods('buffer', [
      \ 'getvar', 'setvar', 'name', 'delete', 'read', 'write',
      \ 'exists', 'spec', 'path', 'fancy_id', 'indent'
      \ ])

" }}}
" Matcher prototype {{{

let s:matcher_prototype = {}

fun! s:matcher(...) abort
  let matcher = {
        \ 'start_at': 0,
        \ 'end_at': 0
        \ }
  call extend(matcher, s:matcher_prototype, 'keep')
  return matcher
endf

" Returns the number of the first line of the region.
fun! s:matcher_start_line(...) dict abort
endf

" Returns the number of the last line of the region.
"
" - the indentation level of the first region line is optional.
fun! s:matcher_end_line(...) dict abort
endf

" Returns the filetype of the found region.
"
" - the fancy object (can be used to read and extract data from
"   original buffer).
fun! s:matcher_filetype(...) dict abort
endf

" Find fenced region and save it position if any. Return false if
" no region has been found and true otherwise.
fun! s:matcher_find_region(...) dict abort
  let self.start_at = self.start_line()
  let self.end_at   = self.end_line(indent(self.start_at))
  return (self.start_at != 0 && self.end_at != 0) ? 1 : 0
endf

fun! s:matcher_search_forward(pattern) dict abort
  return search(a:pattern, 'cnW')
endf

fun! s:matcher_search_backward(pattern) dict abort
  return search(a:pattern, 'bcnW')
endf

call s:add_methods('matcher', [
      \ 'filetype', 'start_line', 'end_line', 'find_region',
      \ 'search_forward', 'search_backward'
      \ ])

" }}}
" Loader prototype {{{

let s:loader_prototype = {}

fun! s:loader() abort
  let loader = {
        \ 'filetypes': {}
        \ }
  call extend(loader, s:loader_prototype, 'keep')
  return loader
endf

fun! s:loader_load(ft) dict abort
  return self.filetypes[a:ft]
endf

fun! s:loader_save(ft, list) dict abort
  let self.filetypes[a:ft] = a:list
endf

fun! s:loader_is_cached(ft) dict abort
  return has_key(self.filetypes, a:ft)
endf

fun! s:loader_is_defined(ft) dict abort
  let func = 'autoload/fancy/ft/'.a:ft.'.vim'
  return !empty(globpath(&rtp, func))
endf

fun! s:loader_load_by_filetype(ft) dict abort
  if self.is_cached(a:ft)
    return self.load(a:ft)

  elseif self.is_defined(a:ft)
    let matchers = fancy#ft#{a:ft}#matchers()
    call self.save(a:ft, matchers)
    return matchers
  endif
endf

call s:add_methods('loader', [
      \ 'load', 'save', 'is_cached', 'is_defined', 'load_by_filetype'
      \ ])

" }}}
" Fancy prototype {{{

let s:fancy_prototype = {}

fun! s:fancy() abort
  let matchers = s:loader().load_by_filetype(&filetype)
  if empty(matchers)
    call s:error(printf('%s: no available matcher', &filetype))
    return
  endif

  let found = 0
  for matcher in matchers
    if matcher.find_region()
      let found = 1
      break
    endif
  endfor

  if !found
    call s:error('No fenced block found! Aborting!')
    return
  endif

  let fancy = {
        \ 'id': s:get_id(),
        \ 'matcher': matcher,
        \ 'buffer': s:buffer(),
        \ 'indent_level': indent(matcher.start_at)
        \ }
  call extend(fancy, s:fancy_prototype, 'keep')

  call add(s:fancy_objects, fancy)
  return fancy
endf

fun! s:fancy_sync() dict abort
  return s:sync()
endf

fun! s:fancy_filetype() dict abort
  let filetype = self.matcher.filetype(self)
  return empty(filetype)
        \ ? self.buffer.getvar('&filetype')
        \ : filetype
endf

fun! s:fancy_text() dict abort
  return self.buffer.indent(
        \ -self.indent_level,
        \ self.matcher.start_at + 1,
        \ self.matcher.end_at - 1)
endf

fun! s:fancy_destroy() dict abort
  call remove(s:fancy_objects, index(s:fancy_objects, self))
endf

call s:add_methods('fancy', ['sync', 'filetype', 'text', 'destroy'])


fun! s:lookup_fancy(id)
  let found = filter(copy(s:fancy_objects), 'v:val["id"] == a:id')
  if empty(found)
    call s:error('Original buffer does no longer exist! Aborting!')
    return
  endif
  return found[0]
endf

fun! s:matchers_by_filetype(ft)
  if has_key(g:fancy_filetypes, a:ft)
    return g:fancy_filetypes[a:ft]
  endif
  return []
endf

fun! s:edit()
  let fancy = fancy#fancy()
  if (type(fancy) != type({}))
    return
  endif

  let name = tempname()
  exe 'split '.name
  let buffer = s:buffer(name, fancy.id)

  call buffer.setvar('&ft', fancy.filetype())
  call buffer.setvar('&bufhidden', 'wipe')
  call buffer.write(fancy.text())

  sil exe 'file '.buffer.spec()
  setl nomodified
endf

fun! s:destroy(...)
  let bufnr = a:0 ? a:1[0] : '%'
  let buffer = s:buffer(bufnr)
  let fancy = s:lookup_fancy(buffer.fancy_id())
  call fancy.destroy()
endf

fun! s:sync(...)
  let bufnr = a:0 ? a:1[0] : '%'
  let buffer = s:buffer(bufnr)
  let fancy = s:lookup_fancy(buffer.fancy_id())

  " Go to original buffer.
  let winnr = bufwinnr(fancy.buffer.name())
  if (winnr != winnr())
    exe 'noa' winnr 'wincmd w'
  endif

  " Sync any changes.
  if (fancy.matcher.end_at - fancy.matcher.start_at > 1)
    exe printf('%s,%s delete _', fancy.matcher.start_at + 1, fancy.matcher.end_at - 1)
  endif
  call append(fancy.matcher.start_at, buffer.indent(fancy.indent_level))

  " Restore the original cursor position.
  call setpos('.', fancy.buffer.pos)

  " Update start/end block position.
  call fancy.matcher.find_region()
endf

fun! s:write(...)
  let bufnr = a:0 ? a:1[0] : '%'
  sil exe 'write! '.s:buffer(bufnr).path()
  setl nomodified
endf

" }}}
" Funcy public interface {{{

fun! fancy#matcher() abort
  return s:matcher()
endf

fun! fancy#fancy() abort
  return s:fancy()
endf

fun! fancy#edit() abort
  return s:edit()
endf

fun! fancy#sync(...) abort
  return s:sync(a:000)
endf

fun! fancy#write(...) abort
  return s:write(a:000)
endf

fun! fancy#destroy(...) abort
  return s:destroy(a:000)
endf

" }}}
