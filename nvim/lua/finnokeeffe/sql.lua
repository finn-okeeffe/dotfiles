local M = {}

local function configure_sql_buffer(bufnr)
    if vim.bo[bufnr].filetype ~= "sql" then
        return
    end

    local function map(mode, lhs, rhs, desc, remap)
        vim.keymap.set(mode, lhs, rhs, {
            buffer = bufnr,
            desc = desc,
            remap = remap,
            silent = true,
        })
    end

    map("n", "<leader>sf", "<cmd>DBUIFindBuffer<CR>", "SQL: choose or find connection")
    map({ "n", "x" }, "<leader>sr", "<Plug>(DBUI_ExecuteQuery)", "SQL: run query", true)
    map("n", "<leader>ss", "<Plug>(DBUI_SaveQuery)", "SQL: save query", true)
    map("n", "<leader>sp", "<Plug>(DBUI_EditBindParameters)", "SQL: edit bind parameters", true)
end

function M.setup()
    local group = vim.api.nvim_create_augroup("sql-workflow", { clear = true })

    vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = "sql",
        callback = function(args)
            configure_sql_buffer(args.buf)
        end,
    })

    configure_sql_buffer(vim.api.nvim_get_current_buf())
end

return M
