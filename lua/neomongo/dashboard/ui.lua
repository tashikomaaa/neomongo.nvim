local logger = require("neomongo.log").scope("dashboard.ui")

local M = {}

local header_ns = vim.api.nvim_create_namespace("NeomongoDashboardHeader")

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
    pcall(vim.api.nvim_set_hl, 0, "NeomongoDashboardHeader", { link = "Title" })
    pcall(vim.api.nvim_set_hl, 0, "NeomongoDashboardHeaderInfo", { link = "NonText" })
end

local function header_lines_to_virt(lines)
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

function M.set_json_buffer_options(bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end
    pcall(vim.api.nvim_buf_set_option, bufnr, "filetype", "json")
    pcall(vim.treesitter.start, bufnr, "json")
    if vim.fn.exists("*nvim_treesitter#foldexpr") == 1 then
        pcall(vim.api.nvim_buf_set_option, bufnr, "foldmethod", "expr")
        pcall(vim.api.nvim_buf_set_option, bufnr, "foldexpr", "nvim_treesitter#foldexpr()")
    else
        pcall(vim.api.nvim_buf_set_option, bufnr, "foldmethod", "syntax")
    end
    pcall(vim.api.nvim_buf_set_option, bufnr, "foldenable", true)
    pcall(vim.api.nvim_buf_set_option, bufnr, "foldlevel", 99)
end

function M.pretty_json(obj)
    local ok, json = pcall(vim.fn.json_encode, obj)
    if not ok or not json then
        logger("pretty_json: unable to encode object")
        return "{}"
    end
    local formatted = vim.fn.system({ "python3", "-m", "json.tool" }, json)
    if vim.v.shell_error ~= 0 or not formatted or formatted == "" then
        return json
    end
    return formatted
end

function M.doc_summary(doc)
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
    local prefix = string.format("%3d │ ", index)
    local summary = M.doc_summary(doc)
    if doc and doc._id ~= nil then
        local id_str = M.format_id(doc._id)
        prefix = prefix .. string.format("[_id=%s] ", id_str)
    end
    return prefix .. summary
end

function M.id_signature(id)
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
