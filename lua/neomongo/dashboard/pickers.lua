local mongo = require("neomongo.dashboard.mongo")
local save = require("neomongo.dashboard.save")
local ui = require("neomongo.dashboard.ui")
local logger = require("neomongo.log").scope("dashboard.pickers")

local M = {}

local function get_collection_preview_lines(uri, db, coll, display_name)
    local entry = mongo.fetch_collection(uri, db, coll)
    local header = ui.make_header_lines(display_name, db, coll, uri)
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
            table.insert(lines, string.format("%3d │ %s", index, ui.doc_summary(doc)))
        end
    end
    return lines, "text"
end

local function open_collection_editor(uri, display_name, db, coll, root_opts)
    logger("open_collection_editor: " .. db .. "." .. coll)
    local entry = mongo.fetch_collection(uri, db, coll)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")

    if entry.error then
        ui.set_buf_content(buf, {
            string.format("Impossible de charger %s.%s", db, coll),
            "",
            entry.message or "Erreur inconnue.",
        }, "text")
        vim.api.nvim_buf_set_option(buf, "modifiable", false)
        ui.apply_header_virtual(buf, display_name, db, coll, uri)
    else
        save.ensure_autocmd()
        local json = ui.pretty_json(entry.docs)
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
            mode = "collection",
            root_opts = root_opts,
        })
        vim.api.nvim_buf_set_name(buf, string.format("neomongo://%s/%s", db, coll))
        vim.api.nvim_buf_set_option(buf, "modified", false)
        ui.set_json_buffer_options(buf)
        ui.apply_header_virtual(buf, display_name, db, coll, uri)
    end

    local width = math.floor(vim.o.columns * 0.7)
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

local function open_document_detail(uri, display_name, db, coll, doc_entry, root_opts)
    save.ensure_autocmd()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
    vim.api.nvim_buf_set_option(buf, "buftype", "acwrite")
    vim.api.nvim_buf_set_option(buf, "swapfile", false)
    vim.api.nvim_buf_set_option(buf, "modifiable", true)
    local json = ui.pretty_json(doc_entry.doc or {})
    local lines = vim.split(json, "\n", { plain = true })
    ui.set_buf_content(buf, lines, "json")
    ui.set_json_buffer_options(buf)
    vim.api.nvim_buf_set_option(buf, "modifiable", true)
    vim.api.nvim_buf_set_option(buf, "modified", false)
    vim.api.nvim_buf_set_name(buf, string.format("neomongo://%s/%s#%d", db, coll, doc_entry.index))
    ui.apply_header_virtual(buf, display_name, db, coll, uri, {
        index = doc_entry.index,
        id = ui.format_id(doc_entry.doc and doc_entry.doc._id),
        label = string.format("Document #%d", doc_entry.index),
    })
    vim.api.nvim_buf_set_var(buf, "neomongo_meta", {
        uri = uri,
        display_name = display_name,
        db = db,
        coll = coll,
        mode = "document",
        index = doc_entry.index,
        doc_id = doc_entry.doc and doc_entry.doc._id,
        doc_signature = ui.id_signature(doc_entry.doc and doc_entry.doc._id),
        root_opts = root_opts,
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

local function open_document_picker(uri, display_name, db, coll, root_opts)
    local entry = mongo.fetch_collection(uri, db, coll)
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
            display = ui.document_label(idx, doc),
            index = idx,
            doc = doc,
        })
    end

    local previewer = previewers.new_buffer_previewer({
        title = string.format("%s.%s", db, coll),
        define_preview = function(self, entry)
            if not entry or not entry.doc then
                ui.set_buf_content(self.state.bufnr, { "Sélectionne un document." }, "text")
                return
            end
            local lines = ui.document_preview_lines(display_name, uri, db, coll, entry)
            ui.set_buf_content(self.state.bufnr, lines, "json")
            ui.set_json_buffer_options(self.state.bufnr)
        end,
    })

    pickers.new({}, {
        prompt_title = string.format("%s.%s — Documents", db, coll),
        finder = finders.new_table({
            results = results,
            entry_maker = function(item)
                return {
                    value = item.doc,
                    display = item.display,
                    ordinal = item.display,
                    doc = item.doc,
                    index = item.index,
                }
            end,
        }),
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
                open_collection_editor(uri, display_name, db, coll, root_opts)
            end)
            map("n", "<C-e>", function()
                actions.close(prompt_bufnr)
                open_collection_editor(uri, display_name, db, coll, root_opts)
            end)

            actions.select_default:replace(function()
                local doc_entry = action_state.get_selected_entry()
                actions.close(prompt_bufnr)
                if doc_entry then
                    open_document_detail(uri, display_name, db, coll, doc_entry, root_opts)
                end
            end)
            return true
        end,
    }):find()
end

local function build_results(uri, dbs)
    local results = {}
    for _, db in ipairs(dbs) do
        table.insert(results, { display = "🗄️ " .. db.name, value = db.name, type = "db" })
        local collections = mongo.list_collections(uri, db.name)
        for _, coll in ipairs(collections) do
            table.insert(results, {
                display = "    📁 " .. coll,
                value = db.name .. "/" .. coll,
                type = "collection",
                db = db.name,
                coll = coll,
            })
        end
    end
    return results
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
    local root_opts
    if type(opts) == "table" then
        uri = opts.uri or opts[1]
        display_name = opts.display_name or opts.connection_name or opts.name or opts.label or opts.title or uri
        root_opts = vim.deepcopy(opts)
    end

    if not uri or uri == "" then
        vim.notify("Neomongo: URI manquante pour le dashboard.", vim.log.levels.ERROR)
        return
    end

    display_name = display_name or uri
    if not root_opts then
        root_opts = {}
    end
    root_opts.uri = uri
    root_opts.connection_name = root_opts.connection_name or display_name
    root_opts.display_name = root_opts.display_name or display_name

    local dbs = mongo.list_databases(uri)
    local results = build_results(uri, dbs)

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
                ui.set_buf_content(self.state.bufnr, { "Sélection vide." }, "text")
                return
            end

            if entry.type ~= "collection" then
                local lines = ui.make_header_lines(display_name, entry.value, entry.coll, uri)
                table.insert(lines, "Sélectionne une collection pour afficher son contenu.")
                ui.set_buf_content(self.state.bufnr, lines, "text")
                return
            end

            local lines, filetype = get_collection_preview_lines(uri, entry.db, entry.coll, display_name)
            ui.set_buf_content(self.state.bufnr, lines, filetype)
        end,
    })

    pickers.new({}, {
        prompt_title = "MongoDB Databases & Collections",
        finder = finders.new_table({
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
            end,
        }),
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
                    open_collection_editor(uri, display_name, entry.db, entry.coll, root_opts)
                end
            end
            map("i", "<C-e>", open_editor)
            map("n", "<C-e>", open_editor)
            actions.select_default:replace(function()
                actions.close(prompt_bufnr)
                local entry = action_state.get_selected_entry()
                if entry and entry.type == "collection" then
                    open_document_picker(uri, display_name, entry.db, entry.coll, root_opts)
                end
            end)
            return true
        end,
    }):find()
end

return M
