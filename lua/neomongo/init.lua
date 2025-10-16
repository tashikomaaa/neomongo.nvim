-- Entry point responsible for wiring the high level Neomongo commands into Neovim.
local core = require("neomongo.core")
local dashboard = require("neomongo.dashboard")
local config_manager = require("neomongo.config")

local M = {}

-- Default runtime configuration for the plugin. Each value can be overridden
-- through `require("neomongo").setup({ ... })`.
M.config = {
    uri = "mongodb://localhost:27017",
    connection_name = nil,
    connections_file = config_manager.default_connections_file(),
    prompt_for_connection = true,
}

function M.setup(opts)
    -- Merge user defined options with the defaults while keeping existing keys.
    M.config = vim.tbl_extend("force", M.config, opts or {})

    -- Wire the lightweight CLI-style commands so users can interact quickly with MongoDB.
    vim.api.nvim_create_user_command("NeomongoConnect", function()
        core.connect(M.config.uri)
    end, {})

    vim.api.nvim_create_user_command("NeomongoListDBs", function()
        core.list_dbs(M.config.uri)
    end, {})

    vim.api.nvim_create_user_command("NeomongoListCollections", function(cmd_opts)
        core.list_collections(M.config.uri, cmd_opts.args)
    end, { nargs = 1 })

    vim.api.nvim_create_user_command("NeomongoQuery", function(cmd_opts)
        core.query(M.config.uri, cmd_opts.args)
    end, { nargs = 1 })

    -- The dashboard is interactive; it allows choosing a connection and browsing data.
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
