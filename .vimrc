set encoding=utf-8

if exists('+pythonthreedll') && &pythonthreedll =~# 'libpython3\.9' &&
      \ filereadable('/usr/lib64/libpython3.12.so.1.0')
  set pythonthreedll=libpython3.12.so.1.0
endif

syntax enable
filetype plugin indent on

let g:ycm_language_server = []

if executable('vscode-json-language-server')
  let g:ycm_language_server += [{
        \ 'name': 'json',
        \ 'cmdline': ['vscode-json-language-server', '--stdio'],
        \ 'filetypes': ['json'],
        \ 'project_root_files': ['package.json', '.git'],
        \ }]
endif

if executable('yaml-language-server')
  let g:ycm_language_server += [{
        \ 'name': 'yaml',
        \ 'cmdline': ['yaml-language-server', '--stdio'],
        \ 'filetypes': ['yaml'],
        \ 'project_root_files': ['.git'],
        \ }]
endif

if executable('terraform-ls')
  let g:ycm_language_server += [{
        \ 'name': 'terraform',
        \ 'cmdline': ['terraform-ls', 'serve'],
        \ 'filetypes': ['terraform'],
        \ 'project_root_files': ['*.tf', '*.tfvars'],
        \ }]
endif
