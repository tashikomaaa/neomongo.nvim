local logger = require("neomongo.log").scope("core")

local M = {}

function M.connect(uri)
    logger("ENTER connect(uri): " .. tostring(uri))
    logger("Connecting to MongoDB at " .. tostring(uri))
    vim.notify("Connected to MongoDB at " .. uri)
    logger("EXIT connect(uri)")
end

function M.list_dbs(uri)
    logger("ENTER list_dbs(uri): " .. tostring(uri))
    local cmd = string.format('mongosh %s --quiet --eval "db.adminCommand( { listDatabases: 1 } )"', uri)
    logger("List DBs CMD: " .. cmd)
    local result = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
        logger("ERROR list_dbs: shell_error=" .. tostring(vim.v.shell_error) .. " | result: " .. tostring(result))
        vim.api.nvim_echo({{"MongoDB error: " .. tostring(result)}}, false, {})
    else
        logger("List DBs Result: " .. result)
        vim.api.nvim_echo({{result}}, false, {})
    end
    logger("EXIT list_dbs(uri)")
end

function M.list_collections(uri, db)
    logger("ENTER list_collections(uri, db): " .. tostring(uri) .. ", " .. tostring(db))
    local cmd = string.format('mongosh %s/%s --quiet --eval "db.getCollectionNames()"', uri, db)
    logger("List Collections CMD: " .. cmd)
    local result = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
        logger("ERROR list_collections: shell_error=" .. tostring(vim.v.shell_error) .. " | result: " .. tostring(result))
        vim.api.nvim_echo({{"MongoDB error: " .. tostring(result)}}, false, {})
    else
        logger("List Collections Result: " .. result)
        vim.api.nvim_echo({{result}}, false, {})
    end
    logger("EXIT list_collections(uri, db)")
end

function M.query(uri, args)
    logger("ENTER query(uri, args): " .. tostring(uri) .. ", " .. tostring(args))
    local cmd = string.format('mongosh %s --quiet --eval "%s"', uri, args)
    logger("Query CMD: " .. cmd)
    local result = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
        logger("ERROR query: shell_error=" .. tostring(vim.v.shell_error) .. " | result: " .. tostring(result))
        vim.api.nvim_echo({{"MongoDB error: " .. tostring(result)}}, false, {})
    else
        logger("Query Result: " .. result)
        vim.api.nvim_echo({{result}}, false, {})
    end
    logger("EXIT query(uri, args)")
end

return M
