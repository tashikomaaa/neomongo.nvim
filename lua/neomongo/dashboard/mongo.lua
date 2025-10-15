local logger = require("neomongo.log").scope("dashboard.mongo")
local state = require("neomongo.dashboard.state")

local M = {}

local function js_string(str)
    return string.format("%q", str)
end

function M.list_databases(uri)
    logger("list_databases: uri=" .. tostring(uri))
    local cmd = string.format(
        'mongosh %s --quiet --eval "JSON.stringify(db.adminCommand({ listDatabases: 1 }))"',
        uri
    )
    logger("list_databases CMD: " .. cmd)
    local result = vim.fn.system(cmd)
    logger("list_databases Result: " .. result)
    if vim.v.shell_error ~= 0 then
        return {}
    end
    local ok, json = pcall(vim.fn.json_decode, result)
    if not ok or not json or not json.databases then
        logger("list_databases decode error")
        return {}
    end
    return json.databases
end

function M.list_collections(uri, db)
    logger(string.format("list_collections: %s/%s", tostring(uri), tostring(db)))
    local cmd = string.format(
        'mongosh %s/%s --quiet --eval "JSON.stringify(db.getCollectionNames())"',
        uri,
        db
    )
    logger("list_collections CMD: " .. cmd)
    local result = vim.fn.system(cmd)
    logger("list_collections Result: " .. result)
    if vim.v.shell_error ~= 0 then
        return {}
    end
    local ok, collections = pcall(vim.fn.json_decode, result)
    if not ok or not collections then
        logger("list_collections decode error")
        return {}
    end
    return collections
end

function M.fetch_collection(uri, db, coll)
    local cached = state.get(uri, db, coll)
    if cached and not cached.filter then
        return cached
    end

    local cmd = string.format(
        'mongosh %s/%s --quiet --eval "JSON.stringify(db.getCollection(\'%s\').find().limit(100).toArray())"',
        uri,
        db,
        coll
    )
    logger("fetch_collection CMD: " .. cmd)
    local result = vim.fn.system(cmd)
    logger("fetch_collection Result: " .. result)

    if vim.v.shell_error ~= 0 then
        return state.set_error(uri, db, coll, result)
    end

    local ok, docs = pcall(vim.fn.json_decode, result)
    if not ok or type(docs) ~= "table" then
        return state.set_error(uri, db, coll, result)
    end

    return state.set(uri, db, coll, {
        error = false,
        message = nil,
        docs = docs,
        filter = nil,
    })
end

function M.query_collection(uri, db, coll, filter, opts)
    opts = opts or {}
    local ok, payload = pcall(vim.fn.json_encode, filter or {})
    if not ok or not payload then
        return nil, "Impossible d'encoder le filtre JSON."
    end

    local limit = tonumber(opts.limit) or 100
    if limit < 1 then
        limit = 1
    end
    limit = math.floor(limit)

    local script = ([[
const filter = EJSON.parse(%s);
let cursor = db.getCollection(%s).find(filter);
const limit = %d;
if (limit > 0) {
  cursor = cursor.limit(limit);
}
const docs = cursor.toArray();
print(EJSON.stringify(docs));
]]):format(js_string(payload), js_string(coll), limit)

    local cmd = string.format(
        "mongosh %s/%s --quiet --eval %s",
        vim.fn.shellescape(uri),
        vim.fn.shellescape(db),
        vim.fn.shellescape(script)
    )
    logger("query_collection CMD: " .. cmd)
    local result = vim.fn.system(cmd)
    logger("query_collection Result: " .. tostring(result))

    if vim.v.shell_error ~= 0 then
        return nil, result
    end

    local decode_ok, docs = pcall(vim.fn.json_decode, result)
    if not decode_ok or type(docs) ~= "table" then
        return nil, result
    end

    return docs
end

function M.apply_changes(meta, docs)
    local ok, payload = pcall(vim.fn.json_encode, docs)
    if not ok or not payload then
        return false, "Impossible d'encoder les documents modifiés."
    end

    local script = ([=[
const docs = EJSON.parse(%s);
const database = db.getSiblingDB(%s);
const collection = database.getCollection(%s);
const uniqueIndexes = collection.getIndexes().filter((index) => {
  if (!index || !index.unique) { return false; }
  const keys = index.key || {};
  return Object.keys(keys).length > 0;
});

function normalizeId(value) {
  if (value == null) { return value; }
  if (typeof value === "object") {
    if (value._bsontype === "ObjectId") {
      return value;
    }
    if (value.$oid && typeof value.$oid === "string" && ObjectId.isValid(value.$oid)) {
      return new ObjectId(value.$oid);
    }
  } else if (typeof value === "string" && ObjectId.isValid(value)) {
    return new ObjectId(value);
  }
  return value;
}

function getValueByPath(source, path) {
  if (!source) { return undefined; }
  const parts = path.split(".");
  let current = source;
  for (let i = 0; i < parts.length; i++) {
    if (current == null) { return undefined; }
    current = current[parts[i]];
  }
  return current;
}

function findExistingByUnique(doc) {
  for (let i = 0; i < uniqueIndexes.length; i++) {
    const index = uniqueIndexes[i];
    const keys = Object.keys(index.key || {});
    if (!keys.length) { continue; }
    const query = {};
    let valid = true;
    for (let j = 0; j < keys.length; j++) {
      const field = keys[j];
      const value = getValueByPath(doc, field);
      if (value === undefined) {
        valid = false;
        break;
      }
      query[field] = value;
    }
    if (!valid) { continue; }
    const found = collection.findOne(query);
    if (found) {
      return found;
    }
  }
  return null;
}

docs.forEach((doc) => {
  if (!doc._id) { throw new Error("Chaque document doit contenir un champ _id"); }
  const normalizedId = normalizeId(doc._id);
  let existing = normalizedId !== undefined ? collection.findOne({ _id: normalizedId }) : null;
  if (!existing) {
    existing = findExistingByUnique(doc);
  }
  if (!existing) {
    const newDoc = Object.assign({}, doc);
    if (normalizedId !== undefined) {
      newDoc._id = normalizedId;
    }
    collection.insertOne(newDoc);
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
    collection.updateOne({ _id: existing._id }, update);
  }
});
print("NEOMONGO_SAVE_OK");
]=]):format(js_string(payload), js_string(meta.db), js_string(meta.coll))

    local cmd = string.format(
        "mongosh %s --quiet --eval %s",
        vim.fn.shellescape(meta.uri),
        vim.fn.shellescape(script)
    )

    logger("apply_changes CMD: " .. cmd)
    local result = vim.fn.system(cmd)
    logger("apply_changes Result: " .. tostring(result))

    if vim.v.shell_error ~= 0 then
        return false, result
    end

    if not tostring(result):find("NEOMONGO_SAVE_OK", 1, true) then
        return false, result
    end

    return true, "Sauvegarde réussie."
end

return M
