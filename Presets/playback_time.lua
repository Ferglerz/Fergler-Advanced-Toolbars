-- presets/current_time_display.lua
local preset = {
    name = "Current Track Time",
    update_interval = 0.05,
    type = "display",
    width = 180,
    format = "%s",
    label = "Time",
    description = "Displays current project time in ruler format",
    -- Directly define functions
    getValue = function(reaper)
        local position = reaper.GetPlayPosition()
        if reaper.GetPlayState() == 0 then
            position = reaper.GetCursorPosition()
        end
        
        -- Format position based on current ruler time unit
        local time_mode = reaper.GetProjectTimeSignature2(0)
        local ruler_time = reaper.format_timestr_pos(position, "", -1)
        local hms_time = reaper.format_timestr_pos(position, "", 5)
        
        -- If ruler time is already in h:m:s format, just return ruler time
        if ruler_time:find("[:.]") then
            return ruler_time
        else
            return ruler_time .. " (" .. hms_time .. ")"
        end
    end,
}

return preset