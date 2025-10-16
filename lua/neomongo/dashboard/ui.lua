-- UI primitives responsible for formatting buffers, virtual lines and JSON snippets.
local logger = require("neomongo.log").scope("dashboard.ui")

local M = {}

-- Namespace used for managing virtual header lines.
local header_ns = vim.api.nvim_create_namespace("NeomongoDashboardHeader")

-- ASCII art banner rendered above every dashboard buffer.
local HEADER_ART = {
    "███▄▄▄▄      ▄████████  ▄██████▄    ▄▄▄▄███▄▄▄▄    ▄██████▄  ███▄▄▄▄      ▄██████▄   ▄██████▄  ",
    "███▀▀▀██▄   ███    ███ ███    ███ ▄██▀▀▀███▀▀▀██▄ ███    ███ ███▀▀▀██▄   ███    ███ ███    ███ ",
    "███   ███   ███    █▀  ███    ███ ███   ███   ███ ███    ███ ███   ███   ███    █▀  ███    ███ ",
    "███   ███  ▄███▄▄▄     ███    ███ ███   ███   ███ ███    ███ ███   ███  ▄███        ███    ███ ",
    "███   ███ ▀▀███▀▀▀     ███    ███ ███   ███   ███ ███    ███ ███   ███ ▀▀███ ████▄  ███    ███ ",
    "███   ███   ███    █▄  ███    ███ ███   ███   ███ ███    ███ ███   ███   ███    ███ ███    ███ ",
    "███   ███   ███    ███ ███    ███ ███   ███   ███ ███    ███ ███   ███   ███    ███ ███    ███ ",
    " ▀█   █▀    ██████████  ▀██████▀   ▀█   ███   █▀   ▀██████▀   ▀█   █▀    ████████▀   ▀██████▀  ",
    "                                                                                                ",
}

local function starts_with(str, prefix)
    return str:sub(1, #prefix) == prefix
end

local function ensure_header_highlight()
    -- Theme the header lines while tolerating missing highlight groups.
    pcall(vim.api.nvim_set_hl, 0, "NeomongoDashboardHeader", { link = "Title" })
    pcall(vim.api.nvim_set_hl, 0, "NeomongoDashboardHeaderInfo", { link = "NonText" })
end

local function header_lines_to_virt(lines)
    -- Convert plain Lua tables into the format expected by `virt_lines`.
    local virt = {}
    for _, line in ipairs(lines) do
        local hl = "NeomongoDashboardHeader"
        if line == "" then
            hl = "NeomongoDashboardHeaderInfo"
        elseif starts_with(line, "►") then
            hl = "NeomongoDashboardHeaderInfo"
        end
        table.insert(virt, { { line, hl } })
    end
    return virt
end

function M.make_header_lines(display_name, db, coll, uri, doc_info)
    -- Build the contextual header shown above dashboards and document buffers.
    db = db or "?"
    coll = coll or "*"
    local lines = vim.deepcopy(HEADER_ART)
    local connection_line = string.format("► Connexion: %s", display_name or uri or "MongoDB")
    table.insert(lines, connection_line)
    if uri and display_name and display_name ~= uri then
        table.insert(lines, string.format("► URI: %s", uri))
    end
    table.insert(lines, string.format("► Collection: %s.%s", db, coll))
    if doc_info then
        local label = doc_info.label
        if not label then
            if doc_info.index then
                label = string.format("Document #%d", doc_info.index)
            else
                label = "Document"
            end
        end
        table.insert(lines, string.format("► %s", label))
        if doc_info.id then
            table.insert(lines, string.format("► _id: %s", tostring(doc_info.id)))
        end
    end
    table.insert(lines, "")
    return lines
end

function M.apply_header_virtual(buf, display_name, db, coll, uri, doc_info)
    -- Apply the header as virtual lines so it can float above existing buffer content.
    ensure_header_highlight()
    vim.api.nvim_buf_clear_namespace(buf, header_ns, 0, -1)
    local lines = M.make_header_lines(display_name, db, coll, uri, doc_info)
    local virt = header_lines_to_virt(lines)
    vim.api.nvim_buf_set_extmark(buf, header_ns, 0, 0, {
        virt_lines = virt,
        virt_lines_above = true,
    })
end

function M.set_buf_content(bufnr, lines, filetype)
    -- Replace buffer content atomically while respecting modifiability flags.
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end
    if type(lines) ~= "table" or vim.tbl_isempty(lines) then
        lines = { "Aucune donnée disponible." }
    end
    vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
    if filetype then
        vim.api.nvim_buf_set_option(bufnr, "filetype", filetype)
    end
end

local function should_enable_json_syntax(bufnr)
    -- Avoid enabling expensive syntax highlight when dealing with very large documents.
    local max_pattern = vim.o.maxmempattern or 2000
    local limit = math.max(max_pattern - 100, 1000)
    local ok, lines = pcall(vim.api.nvim_buf_get_lines, bufnr, 0, -1, false)
    if not ok then
        return false
    end
    for _, line in ipairs(lines) do
        if #line > limit then
            return false
        end
    end
    return true
end

function M.set_json_buffer_options(bufnr)
    -- Apply JSON specific options such as folds and Tree-sitter highlighting.
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end
    pcall(vim.api.nvim_buf_set_option, bufnr, "filetype", "json")
    local enable_highlight = should_enable_json_syntax(bufnr)
    if enable_highlight and vim.treesitter and type(vim.treesitter.start) == "function" then
        pcall(vim.treesitter.start, bufnr, "json")
    end
    if vim.fn.exists("*nvim_treesitter#foldexpr") == 1 then
        pcall(vim.api.nvim_buf_set_option, bufnr, "foldmethod", "expr")
        pcall(vim.api.nvim_buf_set_option, bufnr, "foldexpr", "nvim_treesitter#foldexpr()")
    else
        pcall(vim.api.nvim_buf_set_option, bufnr, "foldmethod", "syntax")
    end
    pcall(vim.api.nvim_buf_set_option, bufnr, "foldenable", true)
    pcall(vim.api.nvim_buf_set_option, bufnr, "foldlevel", 99)
    if enable_highlight then
        pcall(vim.api.nvim_buf_set_option, bufnr, "syntax", "json")
    else
        vim.api.nvim_buf_set_var(bufnr, "neomongo_json_syntax_disabled", true)
    end
end

local function manual_pretty(json)
    -- Fallback formatter used when no external tooling is available. Keeps indentation compact.
    local indent = 0
    -- Store characters gradually to reduce string concatenation overhead.
    local result = {}
    local in_string = false
    local escaping = false

    for i = 1, #json do
        local char = json:sub(i, i)

        if escaping then
            escaping = false
            table.insert(result, char)
        elseif char == "\\" then
            escaping = true
            table.insert(result, char)
        elseif char == '"' then
            in_string = not in_string
            table.insert(result, char)
        elseif not in_string then
            if char == "{" or char == "[" then
                table.insert(result, char)
                indent = indent + 1
                table.insert(result, "\n" .. string.rep("  ", indent))
            elseif char == "}" or char == "]" then
                local previous_indent = indent
                indent = math.max(indent - 1, 0)
                local expected = "\n" .. string.rep("  ", previous_indent)
                if result[#result] == expected then
                    result[#result] = nil
                end
                table.insert(result, "\n" .. string.rep("  ", indent) .. char)
            elseif char == "," then
                table.insert(result, char)
                table.insert(result, "\n" .. string.rep("  ", indent))
            elseif char == ":" then
                table.insert(result, ": ")
            elseif not char:match("%s") then
                table.insert(result, char)
            end
        else
            table.insert(result, char)
        end
    end

    return table.concat(result)
end

function M.pretty_json(obj)
    -- Format Lua tables as JSON trying several strategies, gracefully degrading when needed.
    -- Try native JSON encoder with indentation when available (Neovim ≥ 0.10)
    if vim.json and type(vim.json.encode) == "function" then
        local ok, formatted = pcall(vim.json.encode, obj, { indent = "  ", sort_keys = false })
        if ok and formatted and formatted ~= "" and formatted:find("\n") then
            return formatted
        end
    end

    local ok, json = pcall(vim.fn.json_encode, obj)
    if not ok or not json then
        logger("pretty_json: unable to encode object")
        return "{}"
    end

    if vim.fn.executable("python3") == 1 then
        local formatted = vim.fn.system({ "python3", "-m", "json.tool" }, json)
        if vim.v.shell_error == 0 and formatted and formatted ~= "" then
            return formatted
        end
    end

    return manual_pretty(json)
end

function M.doc_summary(doc)
    -- Produce a compact description for candidate documents inside the Telescope picker.
    if type(doc) ~= "table" then
        return tostring(doc)
    end
    local ok, json = pcall(vim.fn.json_encode, doc)
    if not ok or not json then
        return "<document>"
    end
    json = json:gsub("%s+", " ")
    if #json > 120 then
        json = json:sub(1, 117) .. "..."
    end
    return json
end

function M.format_id(id)
    -- Provide a printable version of a MongoDB `_id`, supporting BSON style tables.
    if id == nil then
        return nil
    end
    local t = type(id)
    if t == "string" or t == "number" or t == "boolean" then
        return tostring(id)
    end
    local ok, json = pcall(vim.fn.json_encode, id)
    if ok and json then
        return json
    end
    return tostring(id)
end

function M.document_label(index, doc)
    -- Provide a label that combines the index, optional identifier and JSON preview.
    local prefix = string.format("%3d │ ", index)
    local summary = M.doc_summary(doc)
    if doc and doc._id ~= nil then
        local id_str = M.format_id(doc._id)
        prefix = prefix .. string.format("[_id=%s] ", id_str)
    end
    return prefix .. summary
end

function M.id_signature(id)
    -- Serialize identifiers so we can detect edits and prevent accidental replacements.
    if id == nil then
        return nil
    end
    local ok, json = pcall(vim.fn.json_encode, id)
    if ok and json then
        return json
    end
    return tostring(id)
end

function M.document_preview_lines(display_name, uri, db, coll, doc_entry)
    -- Compose the lines shown in the preview window when highlighting a document.
    local doc = doc_entry.doc or {}
    local header = M.make_header_lines(display_name, db, coll, uri, {
        index = doc_entry.index,
        id = M.format_id(doc._id),
        label = string.format("Document #%d", doc_entry.index),
    })
    local lines = vim.deepcopy(header)
    local json = M.pretty_json(doc)
    local json_lines = vim.split(json, "\n", { plain = true })
    vim.list_extend(lines, json_lines)
    return lines
end

return M
