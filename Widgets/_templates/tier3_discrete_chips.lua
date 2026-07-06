-- Gold template: discrete action chips (tier 3 — WIDGET.DISCRETE_CHIP_ROW.new).
-- Gold example: Widgets/item_rate_nudge.lua. Copy to Widgets/my_actions.lua. This folder is not auto-loaded.

local WIDGET = require("Utils.Widget.widget_factory")

local ENTRIES = {
    { id = "go", command_id = 0, short_label = "Go", label = "TODO: set command_id" },
}

WIDGET.CHIP_MS.normalize_chip_entries(ENTRIES)

return WIDGET.DISCRETE_CHIP_ROW.new({
    name = "My Action Chips",
    category = "General",
    update_interval = 1.0,
    description = "Short picker description",
    width = 0,
    entries = ENTRIES,
    prefix = "mw_",
    preview_ids = { "go" },
})
