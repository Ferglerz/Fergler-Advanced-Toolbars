-- presets/playback_rate_slider.lua
local preset = {
    name = "Playback Rate Slider",
    default_value = 1.0,
    update_interval = 0.05,
    col_primary = function(reaper)
        local rate = reaper.Master_GetPlayRate(0)
        if rate ~= 1.0 then
            return reaper.GetThemeColor("playrate_edited", 0)
        else
            return nil
        end
    end,    
    type = "slider",
    width = 180,
    min_value = 0.25,
    max_value = 4,
    format = "%.2fx",
    label = "Rate",
    description = "Controls playback rate of project",
    -- Directly define functions
    getValue = function(reaper)
        return reaper.Master_GetPlayRate(0)
    end,
    setValue = function(reaper, value)
        reaper.CSurf_OnPlayRateChange(value)
    end
}

return preset