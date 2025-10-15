local M = {}

local log = function(msg)
    local log_path = "/home/corvus/Work/neomongo/neomongo.log"
    local ok, f = pcall(io.open, log_path, "a")
    if ok and f then
        f:write(os.date("[%Y-%m-%d %H:%M:%S] ") .. "[dashboard] " .. msg .. "\n")
        f:flush()
        f:close()
    end
end

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

local function make_header_lines(display_name, db, coll, uri, doc_info)
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

local function apply_header_virtual(buf, display_name, db, coll, uri, doc_info)
    ensure_header_highlight()
    vim.api.nvim_buf_clear_namespace(buf, header_ns, 0, -1)
    local lines = make_header_lines(display_name, db, coll, uri, doc_info)
    local virt = header_lines_to_virt(lines)
    vim.api.nvim_buf_set_extmark(buf, header_ns, 0, 0, {
        virt_lines = virt,
        virt_lines_above = true,
    })
end

local function cache_key(uri, db, coll)
    return string.format("%s|%s/%s", uri, db, coll)
end

local function set_buf_content(bufnr, lines, filetype)
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

local function set_json_buffer_options(bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end
    pcall(vim.api.nvim_buf_set_option, bufnr, "filetype", "json")
    if vim.fn.exists("*nvim_treesitter#foldexpr") == 1 then
        pcall(vim.api.nvim_buf_set_option, bufnr, "foldmethod", "expr")
        pcall(vim.api.nvim_buf_set_option, bufnr, "foldexpr", "nvim_treesitter#foldexpr()")
    else
        pcall(vim.api.nvim_buf_set_option, bufnr, "foldmethod", "syntax")
    end
    pcall(vim.api.nvim_buf_set_option, bufnr, "foldenable", true)
    pcall(vim.api.nvim_buf_set_option, bufnr, "foldlevel", 99)
end

local function get_dbs(uri)
    log("ENTER get_dbs with uri: " .. tostring(uri))
    local cmd = string.format('mongosh %s --quiet --eval "JSON.stringify(db.adminCommand({ listDatabases: 1 }))"', uri)
    log("get_dbs CMD: " .. cmd)
    local result = vim.fn.system(cmd)
    log("get_dbs Result: " .. result)
    local ok, json = pcall(vim.fn.json_decode, result)
    if not ok or not json or not json.databases then
        log("get_dbs ERROR: failed to parse result")
        return {}
    end
    log("EXIT get_dbs")
    return json.databases
end

local function get_collections(uri, db)
    log("ENTER get_collections with uri: " .. tostring(uri) .. ", db: " .. tostring(db))
    local cmd = string.format('mongosh %s/%s --quiet --eval "JSON.stringify(db.getCollectionNames())"', uri, db)
    log("get_collections CMD: " .. cmd)
    local result = vim.fn.system(cmd)
    log("get_collections Result: " .. result)
    local ok, collections = pcall(vim.fn.json_decode, result)
    if not ok or not collections then
        log("get_collections ERROR: failed to parse result")
        return {}
    end
    log("EXIT get_collections")
    return collections
end

local collection_cache = {}

local function pretty_json(obj)
    local ok, json = pcall(vim.fn.json_encode, obj)
    if not ok or not json then return "{}" end
    local formatted = vim.fn.system({'python3', '-m', 'json.tool'}, json)
    if vim.v.shell_error ~= 0 or not formatted or formatted == "" then
        return json
    end
    return formatted
end

local function doc_summary(doc)
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

local function fetch_collection(uri, db, coll)
    local key = cache_key(uri, db, coll)
    if collection_cache[key] then
        return collection_cache[key]
    end

    log("fetch_collection: " .. key)
    local cmd = string.format(
        'mongosh %s/%s --quiet --eval "JSON.stringify(db.getCollection(\'%s\').find().limit(100).toArray())"',
        uri, db, coll
    )
    log("fetch_collection CMD: " .. cmd)
    local result = vim.fn.system(cmd)
    log("fetch_collection Result: " .. result)

    if vim.v.shell_error ~= 0 then
        local entry = { error = true, message = result, uri = uri, db = db, coll = coll }
        collection_cache[key] = entry
        return entry
    end

    local ok, docs = pcall(vim.fn.json_decode, result)
    if not ok or type(docs) ~= "table" then
        local entry = { error = true, message = result, uri = uri, db = db, coll = coll }
        collection_cache[key] = entry
        return entry
    end

    local entry = { error = false, docs = docs, uri = uri, db = db, coll = coll }
    collection_cache[key] = entry
    return entry
end

local function format_id(id)
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

local function document_label(index, doc)
    local prefix = string.format("%3d │ ", index)
    local summary = doc_summary(doc)
    if doc and doc._id ~= nil then
        local id_str = format_id(doc._id)
        prefix = prefix .. string.format("[_id=%s] ", id_str)
    end
    return prefix .. summary
end

local function js_string(str)
    return string.format("%q", str)
end

local function send_docs_to_db(meta, docs)
    local ok, payload = pcall(vim.fn.json_encode, docs)
    if not ok or not payload then
        return false, "Impossible d'encoder les documents modifiés."
    end

    local script = ([[
const docs = EJSON.parse(%s);
const database = db.getSiblingDB(%s);
const collection = database.getCollection(%s);
docs.forEach((doc) => {
  if (!doc._id) { throw new Error("Chaque document doit contenir un champ _id"); }
  const existing = collection.findOne({ _id: doc._id });
  if (!existing) {
    collection.insertOne(doc);
    return;
  }
  const toSet = Object.assign({}, doc);
  delete toSet._id;
  const toUnset = {};
  Object.keys(existing).forEach((field) => {
    if (field === "_id") { return; }
    if (!(field in toSet)) {
      toUnset[field] = "";
    }
  });
  const update = {};
  if (Object.keys(toSet).length) {
    update.$set = toSet;
  }
  if (Object.keys(toUnset).length) {
    update.$unset = toUnset;
  }
  if (Object.keys(update).length) {
    collection.updateOne({ _id: doc._id }, update);
  }
});
print("NEOMONGO_SAVE_OK");
]]):format(js_string(payload), js_string(meta.db), js_string(meta.coll))

    local cmd = string.format(
        "mongosh %s --quiet --eval %s",
        vim.fn.shellescape(meta.uri),
        vim.fn.shellescape(script)
    )

    log("send_docs_to_db CMD: " .. cmd)
    local result = vim.fn.system(cmd)
    log("send_docs_to_db Result: " .. tostring(result))

    if vim.v.shell_error ~= 0 then
        return false, result
    end

    if not result:find("NEOMONGO_SAVE_OK", 1, true) then
        return false, result
    end

    return true, "Sauvegarde réussie."
end

local function update_cache_after_save(meta, docs)
    local key = cache_key(meta.uri, meta.db, meta.coll)
    local entry = collection_cache[key]
    if not entry then
        entry = { uri = meta.uri, db = meta.db, coll = meta.coll }
        collection_cache[key] = entry
    end
    entry.error = false
    entry.docs = docs
    entry.message = nil
end

local function save_collection_buffer(bufnr, meta)
    apply_header_virtual(bufnr, meta.display_name, meta.db, meta.coll, meta.uri)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local content = table.concat(lines, "\n")
    local ok, decoded = pcall(vim.fn.json_decode, content)
    if not ok or type(decoded) ~= "table" then
        vim.notify("Neomongo: JSON invalide, impossible de sauvegarder.", vim.log.levels.ERROR)
        return
    end

    if not vim.tbl_islist(decoded) then
        vim.notify("Neomongo: le contenu doit être un tableau JSON de documents.", vim.log.levels.ERROR)
        return
    end

    for index, doc in ipairs(decoded) do
        if type(doc) ~= "table" then
            vim.notify(string.format("Neomongo: document #%d n'est pas un objet JSON.", index), vim.log.levels.ERROR)
            return
        end
        if doc._id == nil then
            vim.notify(string.format("Neomongo: document #%d sans champ _id.", index), vim.log.levels.ERROR)
            return
        end
    end

    local success, message = send_docs_to_db(meta, decoded)
    if not success then
        vim.notify("Neomongo: échec de la sauvegarde - " .. tostring(message), vim.log.levels.ERROR)
        return
    end

    update_cache_after_save(meta, decoded)
    vim.api.nvim_buf_set_option(bufnr, "modified", false)
    vim.notify(string.format("Neomongo: %s.%s sauvegardé.", meta.db, meta.coll), vim.log.levels.INFO)
    pcall(vim.api.nvim_exec_autocmds, "BufWritePost", { buffer = bufnr })
end

local function ensure_save_autocmd()
    if M._save_group then
        return
    end
    local group = vim.api.nvim_create_augroup("NeomongoSave", { clear = false })
    vim.api.nvim_create_autocmd("BufWriteCmd", {
        group = group,
        callback = function(args)
            local ok, meta = pcall(vim.api.nvim_buf_get_var, args.buf, "neomongo_meta")
            if not ok then
                return
            end
            save_collection_buffer(args.buf, meta)
        end,
    })
    M._save_group = group
end

local function get_collection_preview_lines(uri, db, coll, display_name)
    local entry = fetch_collection(uri, db, coll)
    local header = make_header_lines(display_name, db, coll, uri)
    if entry.error then
        local lines = vim.deepcopy(header)
        table.insert(lines, string.format("Impossible de lire %s.%s", db, coll))
        table.insert(lines, "")
        table.insert(lines, entry.message or "Erreur inconnue.")
        return lines, "text"
    end

    local lines = vim.deepcopy(header)
    if vim.tbl_isempty(entry.docs) then
        table.insert(lines, "Collection vide.")
    else
        for index, doc in ipairs(entry.docs) do
            table.insert(lines, string.format("%3d │ %s", index, doc_summary(doc)))
        end
    end
    return lines, "text"
end

local function open_collection_editor(uri, display_name, db, coll)
    log("open_collection_editor: " .. db .. "." .. coll)
    local entry = fetch_collection(uri, db, coll)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")

    if entry.error then
        set_buf_content(buf, {
            string.format("Impossible de charger %s.%s", db, coll),
            "",
            entry.message or "Erreur inconnue."
        }, "text")
        vim.api.nvim_buf_set_option(buf, "modifiable", false)
        apply_header_virtual(buf, display_name, db, coll, uri)
    else
        ensure_save_autocmd()
        local json = pretty_json(entry.docs)
        local lines = vim.split(json, "\n", { plain = true })
        vim.api.nvim_buf_set_option(buf, "modifiable", true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        vim.api.nvim_buf_set_option(buf, "buftype", "acwrite")
        vim.api.nvim_buf_set_option(buf, "swapfile", false)
        vim.api.nvim_buf_set_var(buf, "neomongo_meta", {
            uri = uri,
            display_name = display_name,
            db = db,
            coll = coll,
        })
        vim.api.nvim_buf_set_name(buf, string.format("neomongo://%s/%s", db, coll))
        vim.api.nvim_buf_set_option(buf, "modified", false)
        set_json_buffer_options(buf)
        apply_header_virtual(buf, display_name, db, coll, uri)
    end

    local width = math.floor(vim.o.columns * 0.7)
    local height = math.floor(vim.o.lines * 0.7)
    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        row = math.floor((vim.o.lines - height) / 2),
        col = math.floor((vim.o.columns - width) / 2),
        style = "minimal",
        border = "rounded",
    })
end

local function get_document_preview_lines(uri, display_name, db, coll, doc_entry)
    local doc = doc_entry.doc or {}
    local header = make_header_lines(display_name, db, coll, uri, {
        index = doc_entry.index,
        id = format_id(doc._id),
        label = string.format("Document #%d", doc_entry.index),
    })
    local lines = vim.deepcopy(header)
    local json = pretty_json(doc)
    local json_lines = vim.split(json, "\n", { plain = true })
    vim.list_extend(lines, json_lines)
    return lines
end

local function open_document_detail(uri, display_name, db, coll, doc_entry)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
    vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
    vim.api.nvim_buf_set_option(buf, "swapfile", false)
    vim.api.nvim_buf_set_option(buf, "modifiable", true)
    local json = pretty_json(doc_entry.doc or {})
    local lines = vim.split(json, "\n", { plain = true })
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    set_json_buffer_options(buf)
    vim.api.nvim_buf_set_option(buf, "modifiable", false)
    vim.api.nvim_buf_set_name(buf, string.format("neomongo://%s/%s#%d", db, coll, doc_entry.index))
    apply_header_virtual(buf, display_name, db, coll, uri, {
        index = doc_entry.index,
        id = format_id(doc_entry.doc and doc_entry.doc._id),
        label = string.format("Document #%d", doc_entry.index),
    })

    local width = math.floor(vim.o.columns * 0.6)
    local height = math.floor(vim.o.lines * 0.7)
    vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        row = math.floor((vim.o.lines - height) / 2),
        col = math.floor((vim.o.columns - width) / 2),
        style = "minimal",
        border = "rounded",
    })
end

local function open_document_picker(uri, display_name, db, coll)
    local entry = fetch_collection(uri, db, coll)
    if entry.error then
        vim.notify("Neomongo: impossible de charger la collection " .. db .. "." .. coll, vim.log.levels.ERROR)
        return
    end
    local docs = entry.docs or {}
    if vim.tbl_isempty(docs) then
        vim.notify("Neomongo: collection vide.", vim.log.levels.WARN)
        return
    end

    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config")
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")
    local previewers = require("telescope.previewers")

    local results = {}
    for idx, doc in ipairs(docs) do
        table.insert(results, {
            display = document_label(idx, doc),
            index = idx,
            doc = doc,
        })
    end

    local previewer = previewers.new_buffer_previewer({
        title = string.format("%s.%s", db, coll),
        define_preview = function(self, entry)
            if not entry or not entry.doc then
                set_buf_content(self.state.bufnr, {"Sélectionne un document."}, "text")
                return
            end
            local lines = get_document_preview_lines(uri, display_name, db, coll, entry)
            set_buf_content(self.state.bufnr, lines, "json")
            set_json_buffer_options(self.state.bufnr)
        end,
    })

    pickers.new({}, {
        prompt_title = string.format("%s.%s — Documents", db, coll),
        finder = finders.new_table {
            results = results,
            entry_maker = function(item)
                return {
                    value = item.doc,
                    display = item.display,
                    ordinal = item.display,
                    doc = item.doc,
                    index = item.index,
                }
            end
        },
        sorter = conf.values.generic_sorter({}),
        previewer = previewer,
        layout_strategy = "horizontal",
        layout_config = {
            width = 0.95,
            height = 0.85,
            preview_width = 0.6,
        },
        attach_mappings = function(prompt_bufnr, map)
            map("i", "<C-e>", function()
                actions.close(prompt_bufnr)
                open_collection_editor(uri, display_name, db, coll)
            end)
            map("n", "<C-e>", function()
                actions.close(prompt_bufnr)
                open_collection_editor(uri, display_name, db, coll)
            end)

            actions.select_default:replace(function()
                local doc_entry = action_state.get_selected_entry()
                actions.close(prompt_bufnr)
                if doc_entry then
                    open_document_detail(uri, display_name, db, coll, doc_entry)
                end
            end)
            return true
        end,
    }):find()
end

function M.open(opts)
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config")
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")
    local previewers = require("telescope.previewers")

    local uri = opts
    local display_name
    if type(opts) == "table" then
        uri = opts.uri or opts[1]
        display_name = opts.display_name or opts.connection_name or opts.name or opts.label or opts.title or uri
    end

    if not uri or uri == "" then
        vim.notify("Neomongo: URI manquante pour le dashboard.", vim.log.levels.ERROR)
        return
    end

    display_name = display_name or uri

    local dbs = get_dbs(uri)
    local results = {}
    for _, db in ipairs(dbs) do
        table.insert(results, {display="🗄️ " .. db.name, value=db.name, type="db"})
        local collections = get_collections(uri, db.name)
        for _, coll in ipairs(collections) do
            table.insert(results, {display="    📁 " .. coll, value=db.name .. "/" .. coll, type="collection", db=db.name, coll=coll})
        end
    end

    local previewer = previewers.new_buffer_previewer({
        title = "Contenu",
        dyn_title = function(_, entry)
            if not entry then
                return "MongoDB"
            end
            if entry.type == "collection" then
                return string.format("%s.%s", entry.db, entry.coll)
            end
            return entry.value or "MongoDB"
        end,
        define_preview = function(self, entry)
            if not entry then
                set_buf_content(self.state.bufnr, {"Sélection vide."}, "text")
                return
            end

            if entry.type ~= "collection" then
                local lines = make_header_lines(display_name, entry.value, entry.coll, uri)
                table.insert(lines, "Sélectionne une collection pour afficher son contenu.")
                set_buf_content(self.state.bufnr, lines, "text")
                return
            end

            local lines, filetype = get_collection_preview_lines(uri, entry.db, entry.coll, display_name)
            set_buf_content(self.state.bufnr, lines, filetype)
        end,
    })

    pickers.new({}, {
        prompt_title = "MongoDB Databases & Collections",
        finder = finders.new_table {
            results = results,
            entry_maker = function(entry)
                return {
                    value = entry.value,
                    display = entry.display,
                    ordinal = entry.display,
                    type = entry.type,
                    db = entry.db,
                    coll = entry.coll,
                }
            end
        },
        sorter = conf.values.generic_sorter({}),
        previewer = previewer,
        layout_strategy = "horizontal",
        layout_config = {
            width = 0.95,
            height = 0.85,
            preview_width = 0.55,
        },
        attach_mappings = function(prompt_bufnr, map)
            local function open_editor()
                local entry = action_state.get_selected_entry()
                actions.close(prompt_bufnr)
                if entry and entry.type == "collection" then
                    open_collection_editor(uri, display_name, entry.db, entry.coll)
                end
            end
            map("i", "<C-e>", function()
                open_editor()
            end)
            map("n", "<C-e>", function()
                open_editor()
            end)
            actions.select_default:replace(function()
                actions.close(prompt_bufnr)
                local entry = action_state.get_selected_entry()
                if entry.type == "collection" then
                    open_document_picker(uri, display_name, entry.db, entry.coll)
                end
            end)
            return true
        end,
    }):find()
end

return M
