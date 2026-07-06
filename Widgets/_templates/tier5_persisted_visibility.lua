-- Gold template: per-button visibility toggles (tier 5 pattern).
-- Copy to Widgets/my_widget.lua. Uses WIDGET.VIS + settings menu.
-- This folder is not auto-loaded.

local WIDGET = require("Utils.Widget.widget_factory")

local PARTS = { "a", "b" }

local widget = {
    name = "My Visibility Widget",
    category = "General",
    type = "display",
    width = 80,
    update_interval = 0.2,
    description = "Right-click to choose visible parts",
    chip_widget = true,
    _visible = nil,
}

local function ensure_vis(self)
    WIDGET.VIS.ensure_bool_field(self, PARTS, "_visible")
end

function widget.exportPersistedOptions(self)
    ensure_vis(self)
    return WIDGET.VIS.export_bool_map(self, {
        ordered_ids = PARTS,
        field = "_visible",
        persist_key = "visible",
    })
end

function widget.applyPersistedOptions(self, opts)
    WIDGET.VIS.apply_persisted_bool_map(self, opts, {
        ordered_ids = PARTS,
        field = "_visible",
        persist_key = "visible",
        restore_id = "a",
        min_after_apply = 1,
    })
end

function widget.onSettingsMenu(self, ctx, button)
    ensure_vis(self)
    local rows = {}
    for _, id in ipairs(PARTS) do
        rows[#rows + 1] = {
            label = id == "a" and "Part A" or "Part B",
            get = function(h)
                return h._visible[id] ~= false
            end,
            set = function(h, v)
                h._visible[id] = v
            end,
        }
    end
    WIDGET.VIS.draw_checkbox_list(ctx, button, self, {
        title = "Visible parts",
        rows = rows,
        total_visible = function(h)
            return WIDGET.VIS.count_enabled(h, PARTS, "_visible")
        end,
    })
end

function widget.getValue(self)
    return 0
end

-- Add renderCustom / hitTestSubcontrols for your layout.

return widget
