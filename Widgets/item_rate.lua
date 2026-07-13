-- widgets/item_rate.lua
-- Item playrate as semitone slider (-24 … +24), with preset chips in slide-out.

local WIDGET = require("Utils.Widget.widget_factory")
local ITEM_SLIDER = require("Utils.Widget.item_selection_slider")

local widget = {}

widget.name = "Item Rate"
widget.category = "Items & selection"
widget.default_value = 0.0
widget.update_interval = 0.05
widget.type = "slider"
widget.width = 120
widget.min_value = -24
widget.max_value = 24
widget.format = "%+.0fst"
widget.title = "Rate"
widget.description = "Controls playrate for selected media items in semitones. Hover for presets; Shift for fine drag; Cmd toggles snap."
widget.snap_increment = 1.0
widget.fine_scale = 0.1
widget.slider_drag_tooltip = true

ITEM_SLIDER.attach(widget, {
    default_value = 0.0,
    undo_label = "Item rate",
    use_undo_block = true,
    read_first = function(item)
        local rate = reaper.GetMediaItemInfo_Value(item, "D_PLAYRATE")
        return UTILS.rateToSemitones(rate)
    end,
    write_item = function(item, value)
        local rate = UTILS.semitonesToRate(value)
        reaper.SetMediaItemInfo_Value(item, "D_PLAYRATE", rate)
    end,
})

WIDGET.SLIDER_QUICK_CHIPS.attach(widget, {
    slide_out = true,
    slide_out_chip_rows = 1,
    prefix = "irq_",
    entry_rows = {
        {
            { id = "m12", short_label = "-12", value = -12 },
            { id = "m6", short_label = "-6", value = -6 },
            { id = "z", short_label = "0", value = 0 },
            { id = "p6", short_label = "+6", value = 6 },
            { id = "p12", short_label = "+12", value = 12 },
        },
    },
})

return widget
