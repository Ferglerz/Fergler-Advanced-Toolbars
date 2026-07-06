-- Gold template: mode multiswitch (tier 2 — WIDGET.CHIP_MODE.new).
-- Copy to Widgets/my_modes.lua. This folder is not auto-loaded.

local WIDGET = require("Utils.Widget.widget_factory")

local MODES = {
    { id = "a", label = "Mode A" },
    { id = "b", label = "Mode B" },
}

return WIDGET.CHIP_MODE.new({
    name = "My Mode Widget",
    category = "General",
    update_interval = 0.2,
    description = "Short picker description",
    width = 160,
    modes = MODES,
    prefix = "mw_",
    preview_ids = { "a", "b" },
    default_active_id = "a",
    getValue = function(self)
        self._active_id = "a"
        return 0
    end,
    apply = function(_self, mode)
        -- Apply mode to project
    end,
})
