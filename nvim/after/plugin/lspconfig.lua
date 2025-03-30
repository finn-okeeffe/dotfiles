local lspconfig = require('lspconfig')
lspconfig.ruff.setup({
    init_options = {
        settings = {
            -- Ruff language server settings go here
        }
    }
})
