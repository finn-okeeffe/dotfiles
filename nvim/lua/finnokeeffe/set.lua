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
vim.opt.hlsearch = true
vim.opt.incsearch = true

-- xterm colours thing
vim.opt.termguicolors = true

-- scrolling, keep a number of columns at the top/bottom
vim.opt.scrolloff = 8

 -- fast update time
 vim.opt.updatetime = 50

 -- use system clipboard instead of vim clipboard system
 vim.opt.clipboard = "unnamedplus"
