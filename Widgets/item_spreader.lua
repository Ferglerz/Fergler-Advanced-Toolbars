-- widgets/item_spreader.lua
local widget = {}

widget.name = "Item Spreader"
widget.category = "Items & selection"
widget.default_value = 0.0
widget.update_interval = 0.05
widget.type = "slider"
widget.width = 120
widget.min_value = -100
widget.max_value = 100
widget.format = "%.0f%%"
widget.title = "Spread"
widget.description = "Spreads items relative to their average center."
widget.snap_increment = 10.0
widget.fine_scale = 2.0

-- State for tracking selection changes
widget.cached_value = 0
widget.last_selection_hash = ""
widget.initial_state = nil -- Stores { average_pan, max_spread, items = { {guid, original_pan, offset} } }

widget.is_disabled = function()
    local item_count = reaper.CountSelectedMediaItems(0)
    return item_count <= 1
end

widget.getValue = function()
    return UTILS.cachedOnSelectionChange(widget, "last_selection_hash", "cached_value", 0, function()
        widget.initial_state = nil

        local max_spread = 0
        local item_count = reaper.CountSelectedMediaItems(0)
        local total_pan = 0
        local valid_items = 0

        if item_count > 0 then
            for i = 0, item_count - 1 do
                local item = reaper.GetSelectedMediaItem(0, i)
                if item then
                    local take = reaper.GetActiveTake(item)
                    if take then
                        local pan = reaper.GetMediaItemTakeInfo_Value(take, "D_PAN")
                        total_pan = total_pan + pan
                        valid_items = valid_items + 1
                    end
                end
            end

            local average_pan = valid_items > 0 and (total_pan / valid_items) or 0

            for i = 0, item_count - 1 do
                local item = reaper.GetSelectedMediaItem(0, i)
                if item then
                    local take = reaper.GetActiveTake(item)
                    if take then
                        local pan = reaper.GetMediaItemTakeInfo_Value(take, "D_PAN")
                        local dist = math.abs(pan - average_pan)
                        if dist > max_spread then
                            max_spread = dist
                        end
                    end
                end
            end
        end

        return max_spread * 100
    end, function()
        widget.initial_state = nil
    end)
end

widget.setValue = function(value)
    -- Update cache immediately
    widget.cached_value = value
    
    local item_count = reaper.CountSelectedMediaItems(0)
    if item_count == 0 then return end
    
    -- Capture initial state if not already captured
    if not widget.initial_state then
        local state = {
            items = {},
            average_pan = 0,
            max_spread = 0,
            is_centered = false
        }
        
        local total_pan = 0
        local valid_items = 0
        
        -- First pass: Collect items and calculate average
        for i = 0, item_count - 1 do
            local item = reaper.GetSelectedMediaItem(0, i)
            if item then
                local take = reaper.GetActiveTake(item)
                if take then
                    local pan = reaper.GetMediaItemTakeInfo_Value(take, "D_PAN")
                    table.insert(state.items, {
                        item = item,
                        original_pan = pan
                    })
                    total_pan = total_pan + pan
                    valid_items = valid_items + 1
                end
            end
        end
        
        if valid_items > 0 then
            state.average_pan = total_pan / valid_items
            
            -- Second pass: Calculate offsets and max spread
            for _, item_data in ipairs(state.items) do
                local offset = item_data.original_pan - state.average_pan
                item_data.offset = offset
                
                local dist = math.abs(offset)
                if dist > state.max_spread then
                    state.max_spread = dist
                end
            end
            
            -- Check if items are effectively centered (collapsed)
            if state.max_spread < 0.01 then
                state.is_centered = true
            end
            
            widget.initial_state = state
        end
    end
    
    -- Apply spread
    if widget.initial_state then
        local state = widget.initial_state
        local spread_factor = value / 100 -- 0 to 1 (or negative for inversion)
        
        for i, item_data in ipairs(state.items) do
            local new_pan
            
            if state.is_centered then
                -- Special case: Alternating spread
                -- Even items go left, odd items go right (or vice versa)
                -- We use the index i to alternate
                local direction = (i % 2 == 0) and 1 or -1
                -- Scale the spread by the factor. At 100%, we spread to -1 and 1
                new_pan = state.average_pan + (direction * spread_factor)
            else
                -- Standard case: Scale relative to average
                -- If value is 100, we want to restore the original max spread (or keep it if it was already max)
                -- But wait, the user wants to INCREASE/DECREASE.
                -- If value is 0, items should collapse to average.
                -- If value is 100, items should be at their "maximum useful spread" (which might be their original, or wider).
                
                -- Let's interpret "value" as a multiplier of the ORIGINAL spread?
                -- No, the widget is a slider 0-100%.
                -- Usually 0% = collapsed, 100% = full stereo width.
                
                -- Let's try: New Offset = Normalized Offset * Value
                -- Where Normalized Offset = Original Offset / Max Spread (so it's -1 to 1)
                
                if state.max_spread > 0 then
                    local normalized_offset = item_data.offset / state.max_spread
                    new_pan = state.average_pan + (normalized_offset * spread_factor)
                else
                    new_pan = state.average_pan
                end
            end
            
            -- Clamp to -1..1
            new_pan = math.max(-1, math.min(1, new_pan))
            
            local take = reaper.GetActiveTake(item_data.item)
            if take then
                reaper.SetMediaItemTakeInfo_Value(take, "D_PAN", new_pan)
                reaper.UpdateItemInProject(item_data.item)
            end
        end
        
        reaper.UpdateArrange()
        reaper.Undo_OnStateChange("Item Spread")
    end
end

require("Renderers.Widgets.slider_quick_chips").attach(widget, { slide_out = true })

return widget
