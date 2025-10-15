# neomongo.nvim/lua/neomongo
![neomongo logo](https://github.com/tashikomaaa/neomongo.nvim/blob/a26f208c2c51a60479c30da5536f06e85c888545/assets/logo-full.png)

**Manage your MongoDB collections straight from Neovim.**

`neomongo.nvim` offers a lightweight workflow built around a Telescope-powered dashboard where you can explore databases, preview documents, and update collections without leaving your editor.

---

## 🚀 Features

- 🔭 Telescope dashboard listing databases on the left and collections on the right
- 📚 Collection picker that expands into a document list with live previews
- 🔍 Inline JSON filter (press `<C-f>` inside the document picker) to query the current collection without leaving Telescope
- 🤖 Filter autocompletion (`<C-Space>` in the document picker) suggesting field/operator templates based on the sampled documents
- 🧾 ASCII banner highlighting the active connection, database, and document metadata
- ✍️ Editable collection buffers (`:w` writes back to MongoDB using `mongosh`)
- 🗃️ Connection profiles stored in `~/.config/nvim/neomongo_connections.lua`
- ⚙️ Simple commands for connecting, listing databases, listing collections, and running ad hoc queries

---

## 📦 Installation
# neomongo.nvim/lua/neomongo

<a href="https://dotfyle.com/tashikomaaa/neomongonvim-lua-neomongo"><img src="https://dotfyle.com/tashikomaaa/neomongonvim-lua-neomongo/badges/plugins?style=flat" /></a>
<a href="https://dotfyle.com/tashikomaaa/neomongonvim-lua-neomongo"><img src="https://dotfyle.com/tashikomaaa/neomongonvim-lua-neomongo/badges/leaderkey?style=flat" /></a>
<a href="https://dotfyle.com/tashikomaaa/neomongonvim-lua-neomongo"><img src="https://dotfyle.com/tashikomaaa/neomongonvim-lua-neomongo/badges/plugin-manager?style=flat" /></a>


## Install Instructions

 > Install requires Neovim 0.9+. Always review the code before installing a configuration.

Clone the repository and install the plugins:

```sh
git clone git@github.com:tashikomaaa/neomongo.nvim ~/.config/tashikomaaa/neomongo.nvim
```

Open Neovim with this config:

```sh
NVIM_APPNAME=tashikomaaa/neomongo.nvim/lua/neomongo nvim
```
`neomongo.nvim` only depends on [`telescope.nvim`](https://github.com/nvim-telescope/telescope.nvim) and `plenary.nvim`.

```lua
-- lazy.nvim example
{
  "tashikomaaa/neomongo.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
  },
}
```

Once installed, the plugin is ready to use after configuration (see below).

---

## ⚙️ Setup

```lua
require("neomongo").setup({
  uri = "mongodb://localhost:27017",
  connection_name = "Local dev",
  connections_file = vim.fn.stdpath("config") .. "/neomongo_connections.lua",
  prompt_for_connection = true, -- set to false to skip the picker when only one entry exists
})
```

### Connection profiles

On first launch, `neomongo` ensures that the connections file exists (defaults to `~/.config/nvim/neomongo_connections.lua`). The file returns a Lua table:

```lua
return {
  { name = "Local", uri = "mongodb://localhost:27017" },
  { name = "Replica set", uri = "mongodb://mongo-01:27017" },
  -- Add more connections here
}
```

When `prompt_for_connection` is `true` (default), `:NeomongoDashboard` opens a picker letting you choose which connection you want to use. If only one connection is defined you can skip the prompt by setting `prompt_for_connection = false`.

---

## 🧭 Dashboard Workflow

1. Run `:NeomongoDashboard`.
2. Pick a connection (if several are defined). The picker lists databases and collections, each prefixed with an icon.
3. Hover a collection to preview up to 100 documents on the right. Each entry shows a folded one-line JSON summary.
4. Press `<CR>` on a collection to open a **document picker**: left-hand list of documents, right-hand JSON preview (Tree-sitter folds are enabled when available). Type a JSON filter in the Telescope prompt and hit `<C-f>` to re-query the collection (empty prompt reloads the default 100 docs). Need a hand? Hit `<C-Space>` for autocompletion templates (equals, `$in`, `$regex`, `$exists`, comparisons, `$or`, …) and then tweak the generated JSON. Press `<CR>` again to pop a floating window with the selected document; edit it directly and hit `:w` to update MongoDB and return to the dashboard, or use `<C-e>` to switch to the full editable collection buffer.
5. In the editable buffer (`neomongo://db/collection`), update the JSON array and hit `:w`; the plugin validates the JSON and issues insert-or-update commands for each document (documents *must* keep their `_id` field).

> ℹ️ Removing a document from the buffer does **not** delete it remotely. The save routine performs insert or update operations only. Document folding relies on the `nvim-treesitter` JSON parser when available.
> The editor prettifies JSON automatically; if a document contains extremely long lines Neovim may disable syntax highlighting to keep things responsive.

#### Quick filters from the picker

While the document picker is open, you can narrow the result set without leaving Telescope:

1. Type any valid MongoDB JSON filter (e.g. `{"status":"recruteur"}` or `{"missionId":{"$in":["123","456"]}}`) into the prompt, or press `<C-Space>` to pick a ready-made template for the currently sampled fields.
2. Press `<C-f>` (insert or normal mode) to execute the query. Up to 200 matching documents are shown; an empty prompt reloads the default unfiltered list.
3. Continue navigating, editing, or saving as usual.

This uses the same normalization routines as the save path, so `_id` values and unique indexes are handled consistently.
> Autocompletion assumes the current prompt contains valid JSON; if you get an error, tidy up the syntax before retrying `<C-Space>`.

Templates currently offered:

- `equals value` — quickly add `{ "field": "value" }`
- `$in list` — scaffold `{ "field": { "$in": ["a", "b"] } }`
- `$regex pattern` — add `{ "field": { "$regex": "" } }`
- `$exists flag` — add `{ "field": { "$exists": true } }`
- `$gte` / `$lte` — add range boundaries
- `$or`, `$and`, `$nor` — create compound array filters at the root

### Quick-start alias

Add this to your shell config if you want to jump into the dashboard from the command line:

```sh
alias neomongovim='nvim +"lua require(\"neomongo\").setup({ prompt_for_connection = true })" +"NeomongoDashboard"'
```

---

## 📜 Commands

| Command | Description |
|---------|-------------|
| `:NeomongoConnect` | Display a notification confirming a connection to the configured URI |
| `:NeomongoListDBs` | List databases using `mongosh` and echo the JSON response |
| `:NeomongoListCollections {db}` | List collections for the provided database name |
| `:NeomongoQuery {expression}` | Run an arbitrary `mongosh` expression against the configured URI |
| `:NeomongoDashboard` | Launch the Telescope dashboard described above |

All commands rely on `M.config.uri`; the dashboard additionally honours the connection selected from your profiles file.

---

## 🔧 Requirements

- **Neovim 0.9+**
- **mongosh** available on your `PATH`
- **nvim-lua/plenary.nvim**
- **nvim-telescope/telescope.nvim**

---

## 🤝 Contributing

Issues, ideas, and pull requests are welcome! Please open an issue to discuss large changes before submitting a PR.

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Open a pull request 🚀

---

## 📄 License

MIT License © 2025 [tashikomaaa](https://github.com/tashikomaaa)
