vim.g.mapleader = " "
vim.keymap.set("n", "<leader>pv", vim.cmd.Ex, { desc = "Open file explorer" })

-- Keep cursor in middle when doing half page jumps and searching
vim.keymap.set("n", "<C-d>", "<C-d>zz", { desc = "Scroll down half a page and centre cursor" })
vim.keymap.set("n", "<C-u>", "<C-u>zz", { desc = "Scroll up half a page and centre cursor" })
vim.keymap.set("n", "n", "nzzzv", { desc = "Next search result and centre cursor" })
vim.keymap.set("n", "N", "Nzzzv", { desc = "Previous search result and centre cursor" })

-- remap help
vim.keymap.set("n", "<C-<F1>>", "<F1>", { desc = "Open Neovim help" })
vim.keymap.set("n", "<F1>", "<Nop>", { desc = "Disable F1 help" })
