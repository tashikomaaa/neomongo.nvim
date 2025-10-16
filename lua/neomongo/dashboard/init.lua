-- Lightweight wrapper that wires the dashboard picker with the save subsystem.
local save = require("neomongo.dashboard.save")
local pickers = require("neomongo.dashboard.pickers")

local M = {}

function M.open(opts)
    -- Delegate to the picker module which owns every interactive widget.
    pickers.open(opts)
end

save.setup({
    reopen = function(root_opts)
        M.open(root_opts)
    end,
})

return M
