-- Let Neovim discover the uv-installed pynvim tool instead of pinning Fedora's system Python.
vim.g.python3_host_prog = nil

-- line numbers
vim.opt.nu = true
vim.opt.relativenumber = true

-- 4 space indents
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

-- Auto indenting
vim.opt.autoindent = true -- copy previous line
vim.opt.smartindent = true -- change indenting based on syntax

-- Search options
vim.opt.hlsearch = false
vim.opt.incsearch = true

-- xterm colours thing
vim.opt.termguicolors = true
vim.opt.winborder = "rounded"

-- Keep a larger margin above and below the cursor for LSP popups.
vim.opt.scrolloff = 12

 -- fast update time
 vim.opt.updatetime = 50

 -- use system clipboard instead of vim clipboard system
 vim.opt.clipboard = "unnamedplus"

-- highlighted line where cusor is
vim.opt.cursorline = true
vim.opt.cursorlineopt = "both"

-- wrap text
vim.opt.wrap = true
vim.opt.linebreak = true
