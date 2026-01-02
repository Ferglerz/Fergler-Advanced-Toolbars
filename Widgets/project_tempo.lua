-- widgets/project_tempo.lua
local widget = {
    name = "Project Tempo Display",
    update_interval = 0.1,
    type = "display",
    width = 86,
    format = "%.1f BPM",
    label = "Tempo",
    description = "Shows current project tempo. Click to tap tempo. Hover to see TAP mode.",
    
    -- Tap tempo state
    tap_times = {},
    is_hovering = false,
    
    getValue = function(self)
        if self.is_hovering then
            return "TAP"
        end
        return reaper.Master_GetTempo()
    end,
    
    onHover = function(self)
        self.is_hovering = true
    end,
    
    onClick = function(self)
        local current_time = reaper.time_precise()
        
        -- Add current time to tap times
        table.insert(self.tap_times, current_time)
        
        -- Keep only last 4 taps
        if #self.tap_times > 4 then
            table.remove(self.tap_times, 1)
        end
        
        -- Need at least 2 taps to calculate tempo
        if #self.tap_times >= 2 then
            local intervals = {}
            for i = 2, #self.tap_times do
                table.insert(intervals, self.tap_times[i] - self.tap_times[i-1])
            end
            
            -- Calculate average interval
            local total_interval = 0
            for _, interval in ipairs(intervals) do
                total_interval = total_interval + interval
            end
            local avg_interval = total_interval / #intervals
            
            -- Convert to BPM (60 seconds / interval in seconds)
            local new_tempo = 60.0 / avg_interval
            
            -- Set reasonable bounds
            new_tempo = math.max(60, math.min(300, new_tempo))
            
            -- Set the new tempo
            reaper.CSurf_OnTempoChange(new_tempo)
        end
    end,
    
    onRightClick = function()
        -- Launch metronome settings (action 40363)
        reaper.Main_OnCommand(40363, 0)
    end
}

-- Note: Hover state reset is handled in the main renderer

return widget
