#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------
# setup_k8s_vim.sh
# Automate Kubernetes-focused Vim setup
# ---------------------------------------------------

# 1. Detect OS and install Vim if needed
echo "🔍 Checking for vim..."
if ! command -v vim >/dev/null; then
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "→ Installing vim via apt"
    sudo apt update
    sudo apt install -y vim
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "→ Installing vim via Homebrew"
    brew install vim
  else
    echo "⛔️ Unsupported OS; please install Vim manually"
    exit 1
  fi
else
  echo "✔ vim already installed"
fi

# 2. Verify +python3 support
if ! vim --version | grep -q '+python3'; then
  echo "⛔️ Your vim lacks +python3 support. Please install a Python-enabled build."
  exit 1
fi

# 3. Install Node.js & npm for CoC
echo "🔍 Checking for node..."
if ! command -v node >/dev/null; then
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "→ Installing Node.js via apt"
    sudo apt install -y nodejs npm
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "→ Installing Node.js via Homebrew"
    brew install node
  else
    echo "⛔️ Unsupported OS; please install Node.js manually"
    exit 1
  fi
else
  echo "✔ node already installed"
fi

# 4. Install vim-plug
echo "→ Installing vim-plug..."
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
     https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

# 5. Write out the Kubernetes-focused .vimrc
echo "→ Writing ~/.vimrc..."
cat > ~/.vimrc << 'EOF'
" =====================================================================
" *kubernetes-vimrc*    Kubernetes-Friendly .vimrc with YAML support
" =====================================================================

" Plugin manager: vim-plug
call plug#begin('~/.vim/plugged')

" YAML syntax support
Plug 'stephpy/vim-yaml'

" Kubernetes YAML enhancements
Plug 'cben/yaml-path'

" File explorer
Plug 'preservim/nerdtree'

" Status line
Plug 'itchyny/lightline.vim'

" Git integration
Plug 'tpope/vim-fugitive'

" Commenting
Plug 'tpope/vim-commentary'

" Completion engine with LSP support
Plug 'neoclide/coc.nvim', {'branch': 'release'}

call plug#end()

" -------------------------------------
" General settings
" -------------------------------------
set encoding=utf-8
set number
set relativenumber
set cursorline
syntax on
set termguicolors
set mouse=a
set showmatch
set list
set listchars=tab:▸\ ,trail:·
set laststatus=2

" -------------------------------------
" Indentation for YAML
" -------------------------------------
set expandtab
set shiftwidth=2
set softtabstop=2
set autoindent
set smartindent

" -------------------------------------
" Search
" -------------------------------------
set hlsearch
set incsearch
set ignorecase
set smartcase

" -------------------------------------
" Key Mappings
" -------------------------------------
let mapleader=","   " Leader = ','
nmap <Leader>n :NERDTreeToggle<CR>
nmap <Leader>w :w<CR>
nmap <Leader>h :bp<CR>
nmap <Leader>l :bn<CR>

" -------------------------------------
" CoC for YAML LSP
" -------------------------------------
inoremap <silent><expr> <TAB> coc#pum#visible() ? coc#pum#next(1) : '<TAB>'
inoremap <silent><expr> <S-TAB> coc#pum#visible() ? coc#pum#prev(1) : '<C-h>'
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gr <Plug>(coc-references)

" -------------------------------------
" Auto Commands
" -------------------------------------
augroup TrimWhitespace
  autocmd!
  autocmd BufWritePre * %s/\s\+$//e
augroup END

augroup YankHighlight
  autocmd!
  autocmd TextYankPost * silent! lua vim.highlight.on_yank{timeout=200}
augroup END

" -------------------------------------
" CoC Extensions for Kubernetes/YAML
" -------------------------------------
" Use :CocInstall coc-yaml
" Configure schemas in ~/.vim/coc-settings.json

" =====================================================================
" End of Kubernetes Vim Configuration
" =====================================================================
EOF

# 6. Create coc-settings.json for Kubernetes schemas
echo "→ Writing ~/.vim/coc-settings.json..."
mkdir -p ~/.vim
cat > ~/.vim/coc-settings.json << 'EOF'
{
  "yaml.schemas": {
    "https://json.schemastore.org/kubernetes": "/*.yaml"
  }
}
EOF

# 7. Install all plugins
echo "→ Installing Vim plugins (this may take a minute)..."
vim +PlugInstall +qa

# 8. Install coc-yaml extension
echo "→ Installing CoC YAML extension..."
vim +'CocInstall -sync coc-yaml' +qa

echo "✅ All done!  Open a .yaml file in Vim to verify Kubernetes completions."
