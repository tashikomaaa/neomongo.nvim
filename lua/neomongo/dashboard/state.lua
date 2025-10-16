-- In-memory cache used by the dashboard to avoid redundant MongoDB round-trips.
local M = {}

-- Shared table storing the last responses per (uri, database, collection).
local cache = {}

local function cache_key(uri, db, coll)
    -- Compose a unique key so each collection view is cached independently.
    return string.format("%s|%s/%s", uri or "", db or "", coll or "")
end

function M.get(uri, db, coll)
    -- Return the cached entry when available.
    return cache[cache_key(uri, db, coll)]
end

function M.set(uri, db, coll, entry)
    -- Store a normalized cache entry describing the last known state.
    local stored = vim.tbl_extend("force", {
        uri = uri,
        db = db,
        coll = coll,
    }, entry or {})
    cache[cache_key(uri, db, coll)] = stored
    return stored
end

function M.set_error(uri, db, coll, message)
    -- Record the fact that the latest fetch failed together with the error payload.
    return M.set(uri, db, coll, {
        error = true,
        message = message,
        docs = nil,
        filter = nil,
    })
end

function M.set_docs(uri, db, coll, docs)
    -- Cache freshly obtained documents for the given collection.
    return M.set(uri, db, coll, {
        error = false,
        message = nil,
        docs = docs,
        filter = nil,
    })
end

function M.update_document(uri, db, coll, index, doc)
    -- Replace a single document in the cache after a successful save operation.
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
