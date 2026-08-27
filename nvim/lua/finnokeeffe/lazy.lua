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
	  {
		  "mfussenegger/nvim-dap",
		  lazy = false,
		  dependencies = {
			  {
				  "rcarriga/nvim-dap-ui",
				  dependencies = { "nvim-neotest/nvim-nio" },
				  opts = {},
			  },
		  },
		  config = function()
			  local dap = require("dap")
			  local dapui = require("dapui")

			  dap.providers.configs["project_dap"] = function(bufnr)
				  local filename = vim.api.nvim_buf_get_name(bufnr)
				  local root = vim.fs.root(filename, { "pyproject.toml", ".git" })

				  if not root then
					  return {}
				  end

				  local configs = require("dap.ext.vscode").getconfigs(root .. "/.nvim/dap.json")
				  for _, config in ipairs(configs) do
					  if config.cwd == "${workspaceRoot}" then
						  config.cwd = root
					  end
				  end
				  return configs
			  end

			  dap.adapters.python = {
				  type = "executable",
				  command = "uv",
				  args = { "run", "python", "-m", "debugpy.adapter" },
			  }

			  dap.configurations.python = {
				  {
					  type = "python",
					  request = "launch",
					  name = "Launch current file (uv)",
					  program = "${file}",
					  cwd = "${workspaceFolder}",
					  python = { "uv", "run", "python" },
					  console = "integratedTerminal",
					  justMyCode = true,
				  },
				  {
					  type = "python",
					  request = "launch",
					  name = "Launch module (uv)",
					  module = function()
						  return vim.fn.input("Python module: ")
					  end,
					  cwd = "${workspaceFolder}",
					  python = { "uv", "run", "python" },
					  console = "integratedTerminal",
					  justMyCode = true,
				  },
			  }

			  vim.keymap.set("n", "<leader>db", dap.toggle_breakpoint, { desc = "Debug: toggle breakpoint" })
			  vim.keymap.set("n", "<leader>dc", dap.continue, { desc = "Debug: start or continue" })
			  vim.keymap.set("n", "<leader>dn", dap.step_over, { desc = "Debug: step over" })
			  vim.keymap.set("n", "<leader>di", dap.step_into, { desc = "Debug: step into" })
			  vim.keymap.set("n", "<leader>do", dap.step_out, { desc = "Debug: step out" })
			  vim.keymap.set("n", "<leader>dr", dap.repl.open, { desc = "Debug: open REPL" })
			  vim.keymap.set("n", "<leader>dt", dap.terminate, { desc = "Debug: stop" })
			  vim.keymap.set("n", "<leader>du", dapui.toggle, { desc = "Debug: toggle UI" })

			  dap.listeners.after.event_initialized.dapui = function()
				  dapui.open()
			  end
		  end,
	  },
	  {"hrsh7th/cmp-nvim-lsp"},
	  {"hrsh7th/cmp-buffer"},
	  {"hrsh7th/cmp-path"},
	  {"hrsh7th/cmp-cmdline"},
	  {"hrsh7th/nvim-cmp"},
	  {"hrsh7th/cmp-vsnip"},
	  {"hrsh7th/vim-vsnip"},
	  {"ray-x/lsp_signature.nvim"},
	  {"rhysd/conflict-marker.vim"},
	  {
		  "3rd/image.nvim",
		  build = false,
		  opts = {
			  backend = "kitty",
			  processor = "magick_cli",
			  integrations = {},
			  max_width = 100,
			  max_height = 12,
			  max_width_window_percentage = math.huge,
			  max_height_window_percentage = math.huge,
			  -- Keep image.nvim from clearing and re-rendering images when Molten's
			  -- output floats overlap the source window.
			  window_overlap_clear_enabled = false,
		  },
	  },
	  {
		  "benlubas/molten-nvim",
		  version = "^1.0.0",
		  dependencies = { "3rd/image.nvim" },
		  build = ":UpdateRemotePlugins",
		  init = function()
			  vim.g.molten_image_provider = "image.nvim"
			  -- Keep normal output inline, but render plot images only in the output
			  -- float opened explicitly through MoltenEnterOutput.
			  vim.g.molten_auto_open_output = false
			  vim.g.molten_virt_text_output = true
			  vim.g.molten_virt_lines_off_by_1 = true
			  vim.g.molten_image_location = "float"
			  vim.g.molten_output_win_max_height = 20
		  end,
		  config = function()
			  local output_window = require("output_window")
			  local calculate_window_position = output_window.calculate_window_position

			  -- Keep the output below its cell when it fits; otherwise move it up to
			  -- reserve the configured maximum height and border. In shorter windows,
			  -- clamp to the minimum row and let Molten use the available height.
			  output_window.calculate_window_position = function(buf_line)
				  local requested_row = calculate_window_position(buf_line)
				  local max_row = math.max(1, vim.api.nvim_win_get_height(0) - vim.g.molten_output_win_max_height - 2)
				  if requested_row <= 0 then
					  return buf_line > vim.fn.line("w$") and max_row or requested_row
				  end
				  return math.min(requested_row, max_row)
			  end
		  end,
	  },
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
		},
        {
          "epwalsh/obsidian.nvim",
          version = "*",  -- recommended, use latest release instead of latest commit
          lazy = true,
          ft = "markdown",
          -- Replace the above line with this if you only want to load obsidian.nvim for markdown files in your vault:
          -- event = {
          --   -- If you want to use the home shortcut '~' here you need to call 'vim.fn.expand'.
          --   -- E.g. "BufReadPre " .. vim.fn.expand "~" .. "/my-vault/*.md"
          --   -- refer to `:h file-pattern` for more examples
          --   "BufReadPre path/to/my-vault/*.md",
          --   "BufNewFile path/to/my-vault/*.md",
          -- },
          dependencies = {
            -- Required.
            "nvim-lua/plenary.nvim",

            -- see below for full list of optional dependencies 👇
          },
          opts = {
            workspaces = {
              {
                name = "obsidian-vault",
                path = "~/obsidian-vault/",
              },
            },
            templates = {
                folder = "Templates",
            }
          },
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
