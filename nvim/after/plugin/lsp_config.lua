require("mason").setup()
require("mason-lspconfig").setup({
    ensure_installed = {
        "pyright",
        "lua_ls",
        "clangd",
        "postgres_lsp"
    }
})

local hover_opts = {
    anchor_bias = "above",
    border = "rounded",
    max_height = 10,
    title = " Hover ",
    title_pos = "center",
}

local signature_opts = {
    bind = true,
    floating_window = true,
    floating_window_above_cur_line = true,
    max_height = 10,
    hint_enable = false,
    handler_opts = {
        border = "rounded",
    },
}

local on_attach = function(_, bufnr)
    local function map(mode, lhs, rhs, desc)
        vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
    end

    require("lsp_signature").on_attach(signature_opts, bufnr)

    map('n', '<leader>rn', vim.lsp.buf.rename, 'Rename symbol')
    map('n', '<leader>ca', vim.lsp.buf.code_action, 'Show code actions')

    map('n', 'gd', vim.lsp.buf.definition, 'Go to definition')
    map('n', 'gi', vim.lsp.buf.implementation, 'Go to implementation')
    map('n', 'gr', require('telescope.builtin').lsp_references, 'Find references')
    map('n', 'K', function()
        vim.lsp.buf.hover(vim.deepcopy(hover_opts))
    end, 'Show hover information')
    map('i', '<C-k>', function()
        vim.lsp.buf.signature_help({ anchor_bias = "above", border = "rounded", max_height = 10 })
    end, 'Show signature help')
end




-- Set up nvim-cmp.
local cmp = require'cmp'

cmp.setup({
view = {
  entries = {
    vertical_positioning = 'below',
  },
},
snippet = {
  expand = function(args)
    vim.fn["vsnip#anonymous"](args.body) -- For `vsnip` users.
  end,
},
window = {
    completion = cmp.config.window.bordered({ max_height = 10 }),
    documentation = cmp.config.window.bordered(),
},
mapping = cmp.mapping.preset.insert({
  ['<C-b>'] = cmp.mapping.scroll_docs(-4),
  ['<C-f>'] = cmp.mapping.scroll_docs(4),
  ['<C-Space>'] = cmp.mapping.complete(),
  ['<C-e>'] = cmp.mapping.abort(),
  ['<Tab>'] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
  -- ['<CR>'] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
}),
sources = cmp.config.sources({
  { name = 'nvim_lsp' },
  { name = 'vsnip' }, -- For vsnip users.
}, {
  { name = 'buffer' },
})
})

-- Use buffer source for `/` and `?` (if you enabled `native_menu`, this won't work anymore).
cmp.setup.cmdline({ '/', '?' }, {
mapping = cmp.mapping.preset.cmdline(),
sources = {
  { name = 'buffer' }
}
})

-- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
cmp.setup.cmdline(':', {
mapping = cmp.mapping.preset.cmdline(),
sources = cmp.config.sources({
  { name = 'path' }
}, {
  { name = 'cmdline' }
}),
matching = { disallow_symbol_nonprefix_matching = false }
})

-- Set up lspconfig.
local capabilities = require('cmp_nvim_lsp').default_capabilities()
vim.lsp.config('lua_ls',{
    on_attach = on_attach,
    capabilities = capabilities
})
vim.lsp.config('pyright',{
    on_attach = on_attach,
    capabilities = capabilities,
    on_new_config = function(config, root_dir)
        local python = root_dir .. "/.venv/bin/python"

        if vim.uv.fs_stat(python) then
            config.settings = vim.tbl_deep_extend("force", config.settings or {}, {
                python = { pythonPath = python },
            })
        end
    end,
})
vim.lsp.config('clangd',{
    on_attach = on_attach,
    capabilities = capabilities
})
vim.lsp.config('postgres_lsp',{
    on_attach = on_attach,
    capabilities = capabilities
})

-- configure how diagnostics are shown
vim.diagnostic.config({
    virtual_text = true,
})
