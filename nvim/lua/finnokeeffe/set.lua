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

-- Render concealed Markdown syntax, including Obsidian checkbox and link icons.
vim.opt.conceallevel = 1

-- Keep a larger margin above and below the cursor for LSP popups.
vim.opt.scrolloff = 12

 -- fast update time
 vim.opt.updatetime = 50

 -- use system clipboard instead of vim clipboard system
 vim.opt.clipboard = "unnamedplus"

-- GNOME has no Wayland data-control protocol, so wl-copy opens a hidden window to take
-- keyboard focus, which can leave the terminal unfocused. xsel goes through XWayland,
-- which syncs to the Wayland clipboard without taking focus.
if vim.env.WAYLAND_DISPLAY and (vim.env.XDG_CURRENT_DESKTOP or ""):find("GNOME") and vim.fn.executable("xsel") == 1 then
  vim.g.clipboard = {
    name = "xsel",
    copy = { ["+"] = { "xsel", "--nodetach", "-i", "-b" }, ["*"] = { "xsel", "--nodetach", "-i", "-p" } },
    paste = { ["+"] = { "xsel", "-o", "-b" }, ["*"] = { "xsel", "-o", "-p" } },
    cache_enabled = 1,
  }
end

-- highlighted line where cusor is
vim.opt.cursorline = true
vim.opt.cursorlineopt = "both"

-- wrap text
vim.opt.wrap = true
vim.opt.linebreak = true
