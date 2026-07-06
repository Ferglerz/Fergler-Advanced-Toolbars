-- Widgets/item_rate_nudge.lua
-- Tier 3 example: discrete action chips that nudge selected item playrate by semitones.

local WIDGET = require("Utils.Widget.widget_factory")

local LN2 = math.log(2)

local ENTRIES = {
    { id = "dn1", short_label = "-1st", label = "Nudge rate -1 semitone" },
    { id = "reset", short_label = "Reset", label = "Reset item rate to 1.0×" },
    { id = "up1", short_label = "+1st", label = "Nudge rate +1 semitone" },
    { id = "dn12", short_label = "-12", label = "Nudge rate -12 semitones" },
    { id = "up12", short_label = "+12", label = "Nudge rate +12 semitones" },
}

local NUDGE = {
    dn1 = -1,
    up1 = 1,
    dn12 = -12,
    up12 = 12,
}

local function reset_selected_items_rate()
    local count = reaper.CountSelectedMediaItems(0)
    if count < 1 then
        return
    end
    reaper.Undo_BeginBlock()
    for i = 0, count - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        if item then
            reaper.SetMediaItemInfo_Value(item, "D_PLAYRATE", 1.0)
            reaper.UpdateItemInProject(item)
        end
    end
    reaper.UpdateArrange()
    reaper.Undo_EndBlock("Reset item rate", -1)
end

local function nudge_semitones(delta)
    local count = reaper.CountSelectedMediaItems(0)
    if count < 1 then
        return
    end
    reaper.Undo_BeginBlock()
    for i = 0, count - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        if item then
            local rate = reaper.GetMediaItemInfo_Value(item, "D_PLAYRATE")
            if rate and rate > 0 then
                local st = 12 * math.log(rate) / LN2
                local new_rate = math.pow(2, (st + delta) / 12)
                reaper.SetMediaItemInfo_Value(item, "D_PLAYRATE", new_rate)
                reaper.UpdateItemInProject(item)
            end
        end
    end
    reaper.UpdateArrange()
    reaper.Undo_EndBlock("Item rate nudge", -1)
end

return WIDGET.DISCRETE_CHIP_ROW.new({
    name = "Item Rate Nudge",
    category = "Items & selection",
    update_interval = 0.2,
    description = "Nudge playrate of selected items by semitones.",
    width = 0,
    entries = ENTRIES,
    prefix = "irn_",
    preview_ids = { "dn1", "reset", "up1" },
    on_entry_click = function(_self, entry)
        if entry.id == "reset" then
            reset_selected_items_rate()
            return
        end
        local delta = NUDGE[entry.id]
        if delta then
            nudge_semitones(delta)
        end
    end,
})
