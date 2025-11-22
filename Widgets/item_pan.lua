-- widgets/item_pan.lua
local widget = {}

widget.name = "Item Pan Slider"
widget.default_value = 0.0
widget.update_interval = 0.05
widget.type = "slider"
widget.width = 120
widget.min_value = -100
widget.max_value = 100
widget.format = "%.0f%%"
widget.label = "Pan"
widget.description = "Controls pan for all selected media items"
widget.snap_increment = 5.0
widget.fine_scale = 1.0

-- State for tracking selection changes
widget.cached_value = 0
widget.last_selection_hash = ""

-- Helper to generate a hash for the current selection
widget.getSelectionHash = function()
    local item_count = reaper.CountSelectedMediaItems(0)
    if item_count == 0 then return "empty" end
    
    local hash_parts = {}
    for i = 0, item_count - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        -- Use pointer address as unique identifier for the session
        table.insert(hash_parts, tostring(item))
    end
    return table.concat(hash_parts, ",")
end

widget.is_disabled = function()
    local item_count = reaper.CountSelectedMediaItems(0)
    return item_count == 0
end

widget.getValue = function()
    -- Check if selection changed
    local current_hash = widget.getSelectionHash()
    
    -- Handle empty selection explicitly
    if current_hash == "empty" then
        widget.cached_value = 0
        widget.last_selection_hash = "empty"
        return 0
    end
    
    if current_hash ~= widget.last_selection_hash then
        -- Selection changed, recalculate from first item
        widget.last_selection_hash = current_hash
        
        local item = reaper.GetSelectedMediaItem(0, 0)
        if item then
            local take = reaper.GetActiveTake(item)
            if take then
                local pan = reaper.GetMediaItemTakeInfo_Value(take, "D_PAN")
                widget.cached_value = pan * 100 -- Convert from -1..1 to -100..100
            else
                widget.cached_value = 0
            end
        else
            widget.cached_value = 0
        end
    end
    
    return widget.cached_value
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

return widget
