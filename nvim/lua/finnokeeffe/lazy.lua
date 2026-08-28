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
				  opts = {
					  layouts = {
						  {
							  elements = {
								  { id = "scopes", size = 0.25 },
								  { id = "breakpoints", size = 0.25 },
								  { id = "stacks", size = 0.25 },
								  { id = "watches", size = 0.25 },
							  },
							  size = 40,
							  position = "left",
						  },
						  {
							  elements = { "console" },
							  size = 10,
							  position = "bottom",
						  },
					  },
				  },
			  },
		  },
		  config = function()
			  local dap = require("dap")
			  local dapui = require("dapui")
			  local debug_editor_win
			  local exception_float
			  local exception_lines
			  local exception_request_id = 0

			  local function remember_editor()
				  local winid = vim.api.nvim_get_current_win()
				  local buf = vim.api.nvim_win_get_buf(winid)
				  if vim.bo[buf].buftype == "" then
					  debug_editor_win = winid
				  end
			  end

			  local function jump_to_repl()
				  remember_editor()
				  local _, repl_win = dap.repl.open()
				  vim.api.nvim_set_current_win(repl_win)
			  end

			  local function jump_to_editor()
				  if debug_editor_win and vim.api.nvim_win_is_valid(debug_editor_win) then
					  vim.api.nvim_set_current_win(debug_editor_win)
				  else
					  vim.notify("No debug editor window has been recorded", vim.log.levels.WARN)
				  end
			  end

			  local function toggle_dap_ui()
				  dap.repl.close({ mode = "toggle" })
				  dapui.toggle()
			  end

			  local function execute_visual_selection()
				  local start_pos = vim.fn.getpos("v")
				  local end_pos = vim.fn.getpos(".")
				  local selection_mode = vim.fn.mode()
				  if selection_mode == "\22" then
					  vim.notify("Visual Block selections cannot be executed in the debug REPL", vim.log.levels.WARN)
					  return
				  end
				  if start_pos[2] > end_pos[2] or (start_pos[2] == end_pos[2] and start_pos[3] > end_pos[3]) then
					  start_pos, end_pos = end_pos, start_pos
				  end
				  local bufnr = vim.api.nvim_get_current_buf()
				  local lines
				  if selection_mode == "V" then
					  lines = vim.api.nvim_buf_get_lines(bufnr, start_pos[2] - 1, end_pos[2], false)
				  else
					  lines = vim.api.nvim_buf_get_text(
						  bufnr,
						  start_pos[2] - 1,
						  start_pos[3] - 1,
						  end_pos[2] - 1,
						  end_pos[3],
						  {}
					  )
				  end
				  if #lines == 0 then
					  return
				  end

				  jump_to_repl()
				  dap.repl.execute(table.concat(lines, "\n"))
			  end

			  local function close_exception_float()
				  exception_request_id = exception_request_id + 1
				  if exception_float and vim.api.nvim_win_is_valid(exception_float) then
					  vim.api.nvim_win_close(exception_float, true)
				  end
				  exception_float = nil
			  end

			  local function open_exception_float()
				  if not exception_lines then
					  return false
				  end

				  local _, winid = vim.lsp.util.open_floating_preview(exception_lines, "plaintext", {
					  border = "rounded",
					  close_events = {},
					  focus = false,
					  max_height = math.floor(vim.o.lines * 0.5),
					  max_width = math.floor(vim.o.columns * 0.7),
					  title = "Exception",
					  title_pos = "center",
					  wrap = true,
				  })
				  exception_float = winid
				  return true
			  end

			  local function toggle_exception_float()
				  if exception_float and vim.api.nvim_win_is_valid(exception_float) then
					  close_exception_float()
				  elseif not open_exception_float() then
					  vim.notify("No exception details are available", vim.log.levels.WARN)
				  end
			  end

			  local function show_exception_float(session, stopped)
				  close_exception_float()
				  exception_lines = nil
				  if stopped.reason ~= "exception" or not stopped.threadId then
					  return
				  end

				  if not session.capabilities.supportsExceptionInfoRequest then
					  return
				  end
				  vim.diagnostic.config({ virtual_text = false }, session.ns)

				  local request_id = exception_request_id
				  session:request("exceptionInfo", { threadId = stopped.threadId }, function(err, response)
					  if err or not response or request_id ~= exception_request_id then
						  return
					  end

					  local details = response.details or {}
					  local lines = { details.typeName or "Exception" }
					  local description = response.description or details.message
					  if description then
						  vim.list_extend(lines, vim.split(description, "\n", { plain = true }))
					  end
					  if details.stackTrace then
						  table.insert(lines, "")
						  table.insert(lines, "Stack trace:")
						  vim.list_extend(lines, vim.split(details.stackTrace, "\n", { plain = true }))
					  end

					  exception_lines = lines
					  open_exception_float()
				  end)
			  end
			  local function project_python()
				  local root = vim.fs.root(0, { "pyproject.toml", ".git" })
				  local python = root and root .. "/.venv/bin/python"

				  if python and vim.uv.fs_stat(python) then
					  return python
				  end

				  local python_on_path = vim.fn.exepath("python")
				  return python_on_path ~= "" and python_on_path or "python"
			  end

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
					  local workspace_python = "${workspaceRoot}/.venv/bin/python"
					  local project_python_path = root .. "/.venv/bin/python"
					  if config.python == workspace_python then
						  config.python = project_python_path
					  elseif type(config.python) == "table" and config.python[1] == workspace_python then
						  config.python[1] = project_python_path
					  end
				  end
				  return configs
			  end

			  dap.adapters.python = function(callback)
				  callback({
					  type = "executable",
					  command = project_python(),
					  args = { "-m", "debugpy.adapter" },
				  })
			  end

			  dap.defaults.python.external_terminal = {
				  command = "zellij",
				  args = { "action", "new-pane", "--close-on-exit", "--" },
			  }

			  dap.configurations.python = {
				  {
					  type = "python",
					  request = "launch",
					  name = "Launch current file (project environment)",
					  program = "${file}",
					  cwd = "${workspaceFolder}",
					  python = project_python,
					  console = "externalTerminal",
					  justMyCode = true,
				  },
				  {
					  type = "python",
					  request = "launch",
					  name = "Launch module (project environment)",
					  module = function()
						  return vim.fn.input("Python module: ")
					  end,
					  cwd = "${workspaceFolder}",
					  python = project_python,
					  console = "externalTerminal",
					  justMyCode = true,
				  },
			  }

			  vim.keymap.set("n", "<leader>db", dap.toggle_breakpoint, { desc = "Debug: toggle breakpoint" })
			  vim.keymap.set("n", "<leader>dc", function()
				  remember_editor()
				  dap.continue()
			  end, { desc = "Debug: start or continue" })
			  vim.keymap.set("n", "<leader>dn", dap.step_over, { desc = "Debug: step over" })
			  vim.keymap.set("n", "<leader>di", dap.step_into, { desc = "Debug: step into" })
			  vim.keymap.set("n", "<leader>do", dap.step_out, { desc = "Debug: step out" })
			  vim.keymap.set("n", "<leader>dr", jump_to_repl, { desc = "Debug: jump to REPL" })
			  vim.keymap.set("n", "<leader>de", jump_to_editor, { desc = "Debug: jump to editor" })
			  vim.keymap.set("x", "<leader>de", execute_visual_selection, { desc = "Debug: execute selection" })
			  vim.keymap.set("n", "<leader>dt", dap.terminate, { desc = "Debug: stop" })
			  vim.keymap.set("n", "<leader>du", toggle_dap_ui, { desc = "Debug: toggle UI" })
			  vim.keymap.set("n", "<leader>dx", toggle_exception_float, { desc = "Debug: toggle exception" })

			  dap.listeners.after.event_initialized.dapui = function()
				  dapui.open()
			  end
			  dap.listeners.after.event_stopped.exception_float = show_exception_float
			  dap.listeners.after.event_continued.exception_float = function(session)
				  close_exception_float()
				  exception_lines = nil
				  vim.diagnostic.reset(session.ns)
			  end
			  dap.listeners.after.event_terminated.exception_float = function()
				  close_exception_float()
				  exception_lines = nil
			  end
			  dap.listeners.after.disconnect.exception_float = function()
				  close_exception_float()
				  exception_lines = nil
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
