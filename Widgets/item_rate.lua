-- widgets/item_rate.lua
-- Item playrate as semitone slider (-24 … +24), with preset chips in slide-out.

local WIDGET = require("Utils.Widget.widget_factory")

local LN2 = math.log(2)

local function rate_to_semitones(rate)
    rate = UTILS.asNumber(rate, nil)
    if not rate or rate <= 0 then
        return 0
    end
    return 12 * math.log(rate) / LN2
end

local function semitones_to_rate(st)
    st = UTILS.asNumber(st, 0) or 0
    return math.pow(2, st / 12)
end

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

widget.cached_value = 0
widget.last_selection_hash = ""

widget.is_disabled = function()
    return reaper.CountSelectedMediaItems(0) == 0
end

widget.getValue = function()
    return UTILS.cachedOnSelectionChange(widget, "last_selection_hash", "cached_value", 0, function()
        local item = reaper.GetSelectedMediaItem(0, 0)
        if not item then
            return 0
        end
        local rate = reaper.GetMediaItemInfo_Value(item, "D_PLAYRATE")
        return rate_to_semitones(rate)
    end)
end

widget.setValue = function(value)
    widget.cached_value = value
    local rate = semitones_to_rate(value)
    local item_count = reaper.CountSelectedMediaItems(0)

    if item_count > 0 then
        reaper.Undo_BeginBlock()
        for i = 0, item_count - 1 do
            local item = reaper.GetSelectedMediaItem(0, i)
            if item then
                reaper.SetMediaItemInfo_Value(item, "D_PLAYRATE", rate)
                reaper.UpdateItemInProject(item)
            end
        end
        reaper.UpdateArrange()
        reaper.Undo_EndBlock("Item rate", -1)
    end
end

WIDGET.SLIDER_QUICK_CHIPS.attach(widget, {
    slide_out = true,
    slide_out_chip_rows = 1,
    prefix = "irq_",
    entry_rows = {
        {
            { id = "m12", short_label = "-12", value = -12 },
            { id = "m6", short_label = "-6", value = -6 },
            { id = "m1", short_label = "-1", value = -1 },
            { id = "z", short_label = "0", value = 0 },
            { id = "p1", short_label = "+1", value = 1 },
            { id = "p6", short_label = "+6", value = 6 },
            { id = "p12", short_label = "+12", value = 12 },
        },
    },
})

return widget
