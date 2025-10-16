-- Configuration helpers that keep track of saved connections and user preferences.
local M = {}

-- Template used to bootstrap a user managed connections file.
local default_template = [[return {
    { name = "Local", uri = "mongodb://localhost:27017" },
    -- Ajoute ici d'autres connexions, par exemple :
    -- { name = "Prod", uri = "mongodb://example.com:27017" },
}
]]

local function notify(msg, level)
    -- Uniform notification helper that prefixes every message for clarity.
    pcall(vim.notify, "Neomongo: " .. msg, level or vim.log.levels.INFO)
end

function M.default_connections_file()
    -- Prefer the user's Neovim config directory so the file lives outside the plugin directory.
    return vim.fn.stdpath("config") .. "/neomongo_connections.lua"
end

local function ensure_dir(path)
    -- Create missing parent directories before trying to materialize the file itself.
    local dir = vim.fn.fnamemodify(path, ":h")
    if dir and dir ~= "" then
        vim.fn.mkdir(dir, "p")
    end
end

function M.ensure_connections_file(path)
    -- Lazily create the connections file if it does not exist yet.
    if vim.loop.fs_stat(path) then
        return
    end
    ensure_dir(path)
    local ok, file = pcall(io.open, path, "w")
    if not ok or not file then
        notify("impossible de créer " .. path, vim.log.levels.ERROR)
        return
    end
    file:write(default_template)
    file:close()
    notify("fichier de connexions créé: " .. path)
end

function M.load_connections(path)
    -- Load the Lua table of connections while gracefully handling syntax errors.
    local ok, data = pcall(dofile, path)
    if not ok then
        notify(
            "erreur de lecture du fichier de connexions: " .. tostring(data),
            vim.log.levels.ERROR
        )
        return {}
    end
    if type(data) ~= "table" then
        notify("le fichier de connexions doit retourner une table Lua.", vim.log.levels.ERROR)
        return {}
    end
    return data
end

local function normalize_connection(conn)
    -- Convert user supplied connection structures into a consistent internal shape.
    if type(conn) ~= "table" then
        return nil
    end
    if not conn.uri or conn.uri == "" then
        return nil
    end
    local name = conn.connection_name or conn.name or conn.label or conn.title or conn.uri
    return {
        uri = conn.uri,
        connection_name = conn.connection_name or conn.name,
        name = name,
        raw = conn,
    }
end

local function format_choice(choice)
    -- Present a human readable summary when showing connection candidates in the UI.
    if not choice then
        return "?"
    end
    local label = choice.name or choice.uri
    if choice.uri and choice.uri ~= label then
        return string.format("%s (%s)", label, choice.uri)
    end
    return label
end

function M.select_connection(opts, callback)
    opts = opts or {}
    -- Without a callback there is nothing useful to do; fail silently.
    if type(callback) ~= "function" then
        return
    end

    local prompt = opts.prompt_for_connection

    if opts.uri and not prompt then
        callback({
            uri = opts.uri,
            connection_name = opts.connection_name,
            name = opts.connection_name or opts.name,
        })
        return
    end

    local path = opts.connections_file or M.default_connections_file()
    M.ensure_connections_file(path)
    local connections = M.load_connections(path)
    if vim.tbl_isempty(connections) then
        notify("aucune connexion définie dans " .. path, vim.log.levels.WARN)
        return
    end

    local choices = {}
    for _, conn in ipairs(connections) do
        local normalized = normalize_connection(conn)
        if normalized then
            table.insert(choices, normalized)
        end
    end

    if vim.tbl_isempty(choices) then
        notify("aucune connexion valide dans " .. path, vim.log.levels.WARN)
        return
    end

    if #choices == 1 and not prompt then
        callback(choices[1])
        return
    end

    vim.ui.select(choices, {
        prompt = "Sélectionne une connexion MongoDB",
        format_item = format_choice,
    }, function(choice)
        -- Always extend the raw entry so we respect additional user-defined metadata.
        if not choice then
            return
        end
        local result = vim.tbl_extend("force", {}, choice.raw or {}, {
            uri = choice.uri,
            connection_name = choice.connection_name or choice.name,
            name = choice.name,
        })
        callback(result)
    end)
end

return M
