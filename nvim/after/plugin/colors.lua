function ColorMyPencils(color)
	color = color or "gruvbox"
	vim.cmd.colorscheme(color)

	vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
	vim.api.nvim_set_hl(0, "NormalFloat", {
		fg = "#fbf1c7",
		bg = "#504945",
	})
	vim.api.nvim_set_hl(0, "FloatBorder", {
		fg = "#fabd2f",
		bg = "#504945",
	})
	vim.api.nvim_set_hl(0, "FloatTitle", {
		fg = "#fabd2f",
		bg = "#504945",
		bold = true,
	})
end

ColorMyPencils("gruvbox")
