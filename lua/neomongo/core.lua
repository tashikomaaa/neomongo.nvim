local M = {}

local log_path = "/home/corvus/Work/neomongo/neomongo.log"

local function log(msg)
    local ok, f = pcall(io.open, log_path, "a")
    if ok and f then
        f:write(os.date("[%Y-%m-%d %H:%M:%S] ") .. msg .. "\n")
        f:flush()
        f:close()
    else
        vim.notify("Neomongo: unable to write log", vim.log.levels.ERROR)
    end
end

function M.connect(uri)
    log("ENTER connect(uri): " .. tostring(uri))
    log("Connecting to MongoDB at " .. tostring(uri))
    vim.notify("Connected to MongoDB at " .. uri)
    log("EXIT connect(uri)")
end

function M.list_dbs(uri)
    log("ENTER list_dbs(uri): " .. tostring(uri))
    local cmd = string.format('mongosh %s --quiet --eval "db.adminCommand( { listDatabases: 1 } )"', uri)
    log("List DBs CMD: " .. cmd)
    local result = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
        log("ERROR list_dbs: shell_error=" .. tostring(vim.v.shell_error) .. " | result: " .. tostring(result))
        vim.api.nvim_echo({{"MongoDB error: " .. tostring(result)}}, false, {})
    else
        log("List DBs Result: " .. result)
        vim.api.nvim_echo({{result}}, false, {})
    end
    log("EXIT list_dbs(uri)")
end

function M.list_collections(uri, db)
    log("ENTER list_collections(uri, db): " .. tostring(uri) .. ", " .. tostring(db))
    local cmd = string.format('mongosh %s/%s --quiet --eval "db.getCollectionNames()"', uri, db)
    log("List Collections CMD: " .. cmd)
    local result = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
        log("ERROR list_collections: shell_error=" .. tostring(vim.v.shell_error) .. " | result: " .. tostring(result))
        vim.api.nvim_echo({{"MongoDB error: " .. tostring(result)}}, false, {})
    else
        log("List Collections Result: " .. result)
        vim.api.nvim_echo({{result}}, false, {})
    end
    log("EXIT list_collections(uri, db)")
end

function M.query(uri, args)
    log("ENTER query(uri, args): " .. tostring(uri) .. ", " .. tostring(args))
    local cmd = string.format('mongosh %s --quiet --eval "%s"', uri, args)
    log("Query CMD: " .. cmd)
    local result = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
        log("ERROR query: shell_error=" .. tostring(vim.v.shell_error) .. " | result: " .. tostring(result))
        vim.api.nvim_echo({{"MongoDB error: " .. tostring(result)}}, false, {})
    else
        log("Query Result: " .. result)
        vim.api.nvim_echo({{result}}, false, {})
    end
    log("EXIT query(uri, args)")
end

return M
