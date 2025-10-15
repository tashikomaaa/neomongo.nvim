local M = {}

local cache = {}

local function cache_key(uri, db, coll)
    return string.format("%s|%s/%s", uri or "", db or "", coll or "")
end

function M.get(uri, db, coll)
    return cache[cache_key(uri, db, coll)]
end

function M.set(uri, db, coll, entry)
    local stored = vim.tbl_extend("force", {
        uri = uri,
        db = db,
        coll = coll,
    }, entry or {})
    cache[cache_key(uri, db, coll)] = stored
    return stored
end

function M.set_error(uri, db, coll, message)
    return M.set(uri, db, coll, {
        error = true,
        message = message,
        docs = nil,
    })
end

function M.set_docs(uri, db, coll, docs)
    return M.set(uri, db, coll, {
        error = false,
        message = nil,
        docs = docs,
    })
end

function M.update_document(uri, db, coll, index, doc)
    local entry = M.get(uri, db, coll)
    if not entry or type(entry.docs) ~= "table" then
        return
    end
    if index and entry.docs[index] then
        entry.docs[index] = doc
        entry.error = false
        entry.message = nil
    end
end

return M
