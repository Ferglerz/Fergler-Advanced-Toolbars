-- widgets/region_list.lua
local widget = {
    name = "Region List",
    update_interval = 1.0,
    type = "dropdown",
    width = 125,
    placeholder = "Select Region...",
    label = "Regions",
    description = "Quick jump to project regions with time display",
    selected_text = "Regions",
    
    dropdown_menu = {},
    
    scanRegions = function(self)
        local regions = {}
        local marker_count = reaper.CountProjectMarkers(0)
        
        for i = 0, marker_count - 1 do
            local retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers3(0, i)
            
            if isrgn then
                -- Format time as M:SS
                local minutes = math.floor(pos / 60)
                local seconds = math.floor(pos % 60)
                local time_str = string.format("%d:%02d", minutes, seconds)
                
                local display_name = time_str .. " - " .. (name or "Unnamed Region")
                
                table.insert(regions, {
                    name = display_name,
                    action_id = "",
                    region_pos = pos,
                    region_end = rgnend,
                    region_name = name or "Unnamed Region"
                })
            end
        end
        
        -- Sort regions by position
        table.sort(regions, function(a, b) return a.region_pos < b.region_pos end)
        
        self.dropdown_menu = regions
    end,
    
    getValue = function(self)
        -- Scan regions periodically
        if not self.last_scan_time or (reaper.time_precise() - self.last_scan_time) > self.update_interval then
            self:scanRegions()
            self.last_scan_time = reaper.time_precise()
        end
        
        local region_count = #self.dropdown_menu
        return "Regions (" .. region_count .. ")"
    end,
    
    onSelect = function(self, selected_item)
        if not selected_item then return end
        
        if selected_item.region_pos then
            -- Set edit cursor to region start
            reaper.SetEditCurPos(selected_item.region_pos, false, false)
            
            -- Adjust zoom to fit the region
            local region_length = selected_item.region_end - selected_item.region_pos
            if region_length > 0 then
                -- Set time selection to the region
                reaper.GetSet_LoopTimeRange(true, false, selected_item.region_pos, selected_item.region_end, false)
                
                -- Zoom to fit the time selection
                reaper.Main_OnCommand(40730, 0) -- View: Zoom to time selection
            end
            
            -- Update arrange view
            reaper.UpdateArrange()
        end
        
        -- Reset display text back to default
        self.selected_text = "Regions"
    end
}

return widget
