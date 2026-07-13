-- widgets/item_pan.lua
local WIDGET = require("Utils.Widget.widget_factory")
local ITEM_SLIDER = require("Utils.Widget.item_selection_slider")

local widget = {}

widget.name = "Item Pan"
widget.category = "Items & selection"
widget.default_value = 0.0
widget.update_interval = 0.05
widget.type = "slider"
widget.width = 120
widget.min_value = -100
widget.max_value = 100
widget.format = "%.0f%%"
widget.title = "Pan"
widget.description = "Controls pan for all selected media items"
widget.snap_increment = 5.0
widget.fine_scale = 1.0
widget.slider_drag_tooltip = true

ITEM_SLIDER.attach(widget, {
    default_value = 0.0,
    undo_label = "Item Pan",
    read_first = function(item)
        local take = reaper.GetActiveTake(item)
        if not take then
            return 0
        end
        return reaper.GetMediaItemTakeInfo_Value(take, "D_PAN") * 100
    end,
    write_item = function(item, value)
        local take = reaper.GetActiveTake(item)
        if take then
            reaper.SetMediaItemTakeInfo_Value(take, "D_PAN", value / 100)
        end
    end,
})

WIDGET.SLIDER_QUICK_CHIPS.attach(widget, { slide_out = true })

return widget
