local save = require("neomongo.dashboard.save")
local pickers = require("neomongo.dashboard.pickers")

local M = {}

function M.open(opts)
    pickers.open(opts)
end

save.setup({
    reopen = function(root_opts)
        M.open(root_opts)
    end,
})

return M
