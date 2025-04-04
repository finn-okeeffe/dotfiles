vim.g.mapleader = " "
vim.keymap.set("n", "<leader>pv", vim.cmd.Ex)

-- Keep cursor in middle when doing half page jumps and searching
vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "<C-u>", "<C-u>zz")
vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")

-- remap help
vim.keymap.set("n", "<C-<F1>>", "<F1>")
vim.keymap.set("n", "<F1>", "<Nop>")
