local core = require("neomongo.core")
local dashboard = require("neomongo.dashboard")
local config_manager = require("neomongo.config")

local M = {}

M.config = {
    uri = "mongodb://localhost:27017",
    connection_name = nil,
    connections_file = config_manager.default_connections_file(),
    prompt_for_connection = true,
}

function M.setup(opts)
    M.config = vim.tbl_extend("force", M.config, opts or {})
    vim.api.nvim_create_user_command("NeomongoConnect", function()
        core.connect(M.config.uri)
    end, {})
    vim.api.nvim_create_user_command("NeomongoListDBs", function()
        core.list_dbs(M.config.uri)
    end, {})
    vim.api.nvim_create_user_command("NeomongoListCollections", function(opts)
        core.list_collections(M.config.uri, opts.args)
    end, { nargs = 1 })
    vim.api.nvim_create_user_command("NeomongoQuery", function(opts)
        core.query(M.config.uri, opts.args)
    end, { nargs = 1 })
    vim.api.nvim_create_user_command("NeomongoDashboard", function()
        config_manager.select_connection(M.config, function(connection)
            if not connection then
                return
            end
            dashboard.open(connection)
        end)
    end, {})
end

return M
