-- Gold template: plain readout (tier 1 — no factory).
-- Copy to Widgets/my_readout.lua. This folder is not auto-loaded.

local widget = {
    name = "My Readout",
    category = "General",
    type = "display",
    width = 120,
    update_interval = 0.1,
    format = "%.2f",
    title = "Value",
    description = "Short picker description",

    getValue = function()
        return 0
    end,
}

return widget
