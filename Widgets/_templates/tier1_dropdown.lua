-- Gold template: dropdown (tier 1c — plain table, no factory).
-- Copy to Widgets/my_dropdown.lua and edit. This folder is not auto-loaded.

local widget = {
    name = "My Dropdown",
    category = "General",
    type = "dropdown",
    width = 140,
    update_interval = 0.5,
    placeholder = "Choose…",
    description = "Short picker description",
    dropdown_menu = {},

    -- Renderer calls scan* hooks before opening the menu (pick one pattern):
    scanRegions = function(self)
        self.dropdown_menu = {
            -- { name = "Label shown", region_pos = 0, region_end = 4, ... }
        }
    end,

    onClick = function(self, item)
        if item and item.region_pos then
            reaper.SetEditCurPos(item.region_pos, true, false)
        end
    end,
}

return widget
