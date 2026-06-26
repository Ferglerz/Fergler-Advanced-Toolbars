-- widgets/item_pan.lua
local widget = {}

widget.name = "Item Pan Slider"
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

-- State for tracking selection changes
widget.cached_value = 0
widget.last_selection_hash = ""

widget.is_disabled = function()
    local item_count = reaper.CountSelectedMediaItems(0)
    return item_count == 0
end

widget.getValue = function()
    return UTILS.cachedOnSelectionChange(widget, "last_selection_hash", "cached_value", 0, function()
        local item = reaper.GetSelectedMediaItem(0, 0)
        if not item then
            return 0
        end
        local take = reaper.GetActiveTake(item)
        if not take then
            return 0
        end
        return reaper.GetMediaItemTakeInfo_Value(take, "D_PAN") * 100
    end)
end

widget.setValue = function(value)
    -- Update cache immediately so it doesn't snap back
    widget.cached_value = value
    
    -- Apply pan to all selected items
    local item_count = reaper.CountSelectedMediaItems(0)
    
    if item_count > 0 then
        local pan_normalized = value / 100 -- Convert from -100..100 to -1..1
        
        for i = 0, item_count - 1 do
            local item = reaper.GetSelectedMediaItem(0, i)
            if item then
                local take = reaper.GetActiveTake(item)
                if take then
                    reaper.SetMediaItemTakeInfo_Value(take, "D_PAN", pan_normalized)
                    reaper.UpdateItemInProject(item)
                end
            end
        end
        
        -- Update the project and undo state
        reaper.UpdateArrange()
        reaper.Undo_OnStateChange("Item Pan")
    end
end

require("Renderers.Widgets.slider_quick_chips").attach(widget, { slide_out = true })

return widget
