-- Saving helpers that synchronize modified buffers with MongoDB collections.
local mongo = require("neomongo.dashboard.mongo")
local state = require("neomongo.dashboard.state")
local ui = require("neomongo.dashboard.ui")
local logger = require("neomongo.log").scope("dashboard.save")

local M = {}

-- Optional callback used to reopen the parent dashboard after saving.
local reopen_callback

function M.setup(opts)
    -- Allow the dashboard to reopen itself once a document was saved.
    reopen_callback = opts and opts.reopen
end

local function decode_json_buffer(bufnr)
    -- Read the buffer verbatim and decode it as JSON for persistence.
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local content = table.concat(lines, "\n")
    return pcall(vim.fn.json_decode, content)
end

function M.save_collection_buffer(bufnr, meta)
    -- Persist an entire collection buffer containing an array of documents.
    ui.set_json_buffer_options(bufnr)
    ui.apply_header_virtual(bufnr, meta.display_name, meta.db, meta.coll, meta.uri)

    local ok, decoded = decode_json_buffer(bufnr)
    if not ok or type(decoded) ~= "table" then
        vim.notify("Neomongo: JSON invalide, impossible de sauvegarder.", vim.log.levels.ERROR)
        return
    end

    if not vim.tbl_islist(decoded) then
        vim.notify(
            "Neomongo: le contenu doit être un tableau JSON de documents.",
            vim.log.levels.ERROR
        )
        return
    end

    for index, doc in ipairs(decoded) do
        if type(doc) ~= "table" then
            vim.notify(
                string.format("Neomongo: document #%d n'est pas un objet JSON.", index),
                vim.log.levels.ERROR
            )
            return
        end
        if doc._id == nil then
            vim.notify(
                string.format("Neomongo: document #%d sans champ _id.", index),
                vim.log.levels.ERROR
            )
            return
        end
    end

    local success, message = mongo.apply_changes(meta, decoded)
    if not success then
        logger("save_collection_buffer error: " .. tostring(message))
        vim.notify(
            "Neomongo: échec de la sauvegarde - " .. tostring(message),
            vim.log.levels.ERROR
        )
        return
    end

    state.set_docs(meta.uri, meta.db, meta.coll, decoded)
    -- Mark the buffer as clean so users are not prompted again.
    vim.api.nvim_buf_set_option(bufnr, "modified", false)
    vim.notify(
        string.format("Neomongo: %s.%s sauvegardé.", meta.db, meta.coll),
        vim.log.levels.INFO
    )
    pcall(vim.api.nvim_exec_autocmds, "BufWritePost", { buffer = bufnr })
end

function M.save_document_buffer(bufnr, meta)
    -- Persist a single document buffer and refresh cached state afterwards.
    local doc_info = {
        index = meta.index,
        id = ui.format_id(meta.doc_id),
        label = string.format("Document #%d", meta.index or 0),
    }
    ui.set_json_buffer_options(bufnr)
    ui.apply_header_virtual(bufnr, meta.display_name, meta.db, meta.coll, meta.uri, doc_info)

    local ok, decoded = decode_json_buffer(bufnr)
    if not ok or type(decoded) ~= "table" or vim.tbl_islist(decoded) then
        vim.notify("Neomongo: le document doit être un objet JSON valide.", vim.log.levels.ERROR)
        return
    end
    if decoded._id == nil then
        vim.notify("Neomongo: le document doit contenir un champ _id.", vim.log.levels.ERROR)
        return
    end

    local new_signature = ui.id_signature(decoded._id)
    if meta.doc_signature and new_signature ~= meta.doc_signature then
        vim.notify(
            "Neomongo: modification de _id non prise en charge dans l'éditeur de document.",
            vim.log.levels.ERROR
        )
        return
    end

    local success, message = mongo.apply_changes(meta, { decoded })
    if not success then
        logger("save_document_buffer error: " .. tostring(message))
        vim.notify(
            "Neomongo: échec de la sauvegarde du document - " .. tostring(message),
            vim.log.levels.ERROR
        )
        return
    end

    state.update_document(meta.uri, meta.db, meta.coll, meta.index, decoded)
    vim.notify(
        string.format("Neomongo: document #%d mis à jour.", meta.index or 0),
        vim.log.levels.INFO
    )

    vim.api.nvim_buf_set_option(bufnr, "modified", false)
    -- Gently reopen the dashboard after the buffer was closed.
    local root_opts = meta.root_opts or { uri = meta.uri, connection_name = meta.display_name }
    vim.schedule(function()
        if vim.api.nvim_buf_is_valid(bufnr) then
            pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
        end
        if reopen_callback then
            reopen_callback(root_opts)
        end
    end)
end

function M.ensure_autocmd()
    -- Lazily register a BufWriteCmd autocmd so saving buffers triggers persistence.
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
            if meta.mode == "document" then
                M.save_document_buffer(args.buf, meta)
            else
                M.save_collection_buffer(args.buf, meta)
            end
        end,
    })
    M._save_group = group
end

return M
