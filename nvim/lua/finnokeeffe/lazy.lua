-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- Make sure to setup `mapleader` and `maplocalleader` before
-- loading lazy.nvim so that mappings are correct.
-- This is also a good place to setup other settings (vim.opt)
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Setup lazy.nvim
require("lazy").setup({
  spec = {
	  {'nvim-lua/plenary.nvim'},
	  {
		  'nvim-telescope/telescope.nvim', branch = 'master',
		  dependencies = {'nvim-lua/plenary.nvim'}
	  },
	  { "ellisonleao/gruvbox.nvim" },
	  {
		  'nvim-treesitter/nvim-treesitter',
		  branch = 'main',
		  lazy = false,
		  build = ':TSUpdate',
		  config = function()
			  local languages = {
				  "powershell",
				  "bash",
				  "python",
				  "c",
				  "lua",
				  "vim",
				  "vimdoc",
				  "query",
				  "markdown",
				  "markdown_inline",
			  }

			  require("nvim-treesitter").setup()
			  require("nvim-treesitter").install(languages)

			  local group = vim.api.nvim_create_augroup("nvim-treesitter-start", { clear = true })

			  local function start_highlight(bufnr)
				  bufnr = bufnr or vim.api.nvim_get_current_buf()
				  if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].filetype ~= "" then
					  pcall(vim.treesitter.start, bufnr)
				  end
			  end

			  vim.api.nvim_create_autocmd("FileType", {
				  group = group,
				  callback = function(args)
					  start_highlight(args.buf)
				  end,
			  })

			  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
				  start_highlight(bufnr)
			  end
		  end,
	  },
	  {'mbbill/undotree'},
	  {"williamboman/mason.nvim"},
	  {"williamboman/mason-lspconfig.nvim"},
	  {"neovim/nvim-lspconfig"},
	  {"hrsh7th/cmp-nvim-lsp"},
	  {"hrsh7th/cmp-buffer"},
	  {"hrsh7th/cmp-path"},
	  {"hrsh7th/cmp-cmdline"},
	  {"hrsh7th/nvim-cmp"},
	  {"hrsh7th/cmp-vsnip"},
	  {"hrsh7th/vim-vsnip"},
	  {"rhysd/conflict-marker.vim"},
	      {
		"quarto-dev/quarto-nvim",
		dependencies = {
		    "jmbuhr/otter.nvim",
		    "nvim-treesitter/nvim-treesitter",
		},
	      },
		{
		  "lervag/vimtex",
		  lazy = false,     -- we don't want to lazy load VimTeX
		  -- tag = "v2.15", -- uncomment to pin to a specific release
		  init = function()
		    -- VimTeX configuration goes here, e.g.
		    vim.g.vimtex_view_method = "zathura"
		  end
		}
  },
  -- Configure any other settings here. See the documentation for more details.
  -- colorscheme that will be used when installing plugins.
  install = { colorscheme = { "gruvbox" } },
  ui = {
    border = "rounded",
    title = " Lazy ",
    title_pos = "center",
  },
  -- automatically check for plugin updates
  checker = { enabled = true },
})
