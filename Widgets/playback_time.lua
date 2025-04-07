-- widgets/current_time_display.lua
local widget = {
    name = "Current Track Time",
    update_interval = 0.05,
    type = "display",
    width = 180,
    format = "%s",
    label = "Time",
    description = "Displays current project time",
    
    getValue = function()
        local position = reaper.GetPlayPosition()
        if reaper.GetPlayState() == 0 then
            position = reaper.GetCursorPosition()
        end
        
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

return widget