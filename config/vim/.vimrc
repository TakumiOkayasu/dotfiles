" ============================================
" 基本設定
" ============================================

" 文字コード (日本語環境では必須)
set encoding=utf-8
set fileencodings=utf-8,sjis,euc-jp,cp932

" バックアップファイルを作らない (gitで管理するため不要)
set nobackup
set noswapfile

" ファイル変更時に自動で再読み込み
set autoread

" クリップボード連携 (ヤンクでシステムクリップボードにコピー)
set clipboard=unnamedplus

" ============================================
" 表示設定
" ============================================

" 行番号を表示
set number

" カーソル行をハイライト (今どこにいるか分かりやすい)
set cursorline

" 対応する括弧をハイライト
set showmatch

" シンタックスハイライト有効
syntax enable

" ステータスラインを常に表示
set laststatus=2

" 入力中のコマンドを表示
set showcmd

" カラースキーム (好みで変更)
colorscheme desert
set background=dark

" ============================================
" 検索設定
" ============================================

" インクリメンタル検索 (入力中から検索開始)
set incsearch

" 検索結果をハイライト
set hlsearch

" 大文字小文字を区別しない
set ignorecase

" 大文字が含まれる場合は区別する
set smartcase

" ESC連打でハイライト消去
nnoremap <Esc><Esc> :nohlsearch<CR>

" ============================================
" インデント設定
" ============================================

" タブをスペースに展開
set expandtab

" インデント幅 (2か4、好みで)
set tabstop=4
set shiftwidth=4
set softtabstop=4

" 自動インデント
set autoindent
set smartindent

" ============================================
" 操作性向上
" ============================================

" Backspaceの挙動を普通にする
set backspace=indent,eol,start

" 行末を超えて移動できるようにする
set whichwrap=b,s,h,l,<,>,[,]

" ビープ音を消す
set belloff=all

" コマンド補完
set wildmenu
set wildmode=list:longest

" マウス有効 (不要なら削除)
set mouse=a

" ============================================
" 便利なキーマップ
" ============================================

" jjでノーマルモードに戻る (Escキー遠いので)
inoremap jj <Esc>

" Y を行末までヤンクに (Dと同じ挙動に統一)
nnoremap Y y$

" 表示行単位で移動 (折り返し行でも自然に動く)
nnoremap j gj
nnoremap k gk

" ウィンドウ間移動を簡単に
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" ============================================
" ファイルタイプ別設定
" ============================================

" ファイルタイプ検出を有効化
filetype plugin indent on

" Makefile はタブ必須
autocmd FileType make setlocal noexpandtab

" Python は4スペース
autocmd FileType python setlocal tabstop=4 shiftwidth=4 softtabstop=4

" ============================================
" 最後のカーソル位置を記憶
" ============================================

autocmd BufReadPost *
	\ if line("'\"") > 0 && line("'\"") <= line("$") |
	\   exe "normal! g`\"" |
	\ endif
