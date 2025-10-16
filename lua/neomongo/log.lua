-- Small synchronous logger that writes diagnostic information to `neomongo.log`.
local M = {}

local log_path

local function resolve_log_path()
    -- Lazily resolve the log file path relative to the project root.
    if log_path then
        return log_path
    end
    local source = debug.getinfo(1, "S").source
    if source:sub(1, 1) == "@" then
        source = source:sub(2)
    end
    local root = vim.fn.fnamemodify(source, ":p:h:h:h")
    log_path = root .. "/neomongo.log"
    return log_path
end

local function write_line(scope, message)
    -- Append a single formatted line to the log file with an optional scope.
    local path = resolve_log_path()
    local ok, file = pcall(io.open, path, "a")
    if not ok or not file then
        pcall(vim.notify, "Neomongo: unable to write log file", vim.log.levels.ERROR)
        return
    end
    local timestamp = os.date("[%Y-%m-%d %H:%M:%S] ")
    local prefix = scope and ("[" .. scope .. "] ") or ""
    file:write(timestamp .. prefix .. message .. "\n")
    file:flush()
    file:close()
end

function M.write(scope, message)
    -- Convenience wrapper supporting `write("message")` and `write("scope", "message")`.
    if not message then
        message = scope
        scope = nil
    end
    write_line(scope, tostring(message))
end

function M.scope(scope_name)
    -- Provide a dedicated logger function bound to a specific logical scope.
    return function(message)
        write_line(scope_name, tostring(message))
    end
end

return M
