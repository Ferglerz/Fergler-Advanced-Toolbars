-- widgets/metronome_volume.lua
local widget = {
    name = "Metronome Volume Slider",
    default_value = 0.5,
    update_interval = 0.1,
    type = "slider",
    width = 120,
    min_value = 0,
    max_value = 1,
    format = "%.0f%%",
    label = "Click",
    description = "Controls metronome/click volume. Right-click for metronome settings.",
    snap_increment = 0.05,
    fine_scale = 0.01,
    
    getValue = function()
        -- Get metronome volume from config
        local vol = reaper.SNM_GetDoubleConfigVar("projmetrolvol", 0.5)
        return vol
    end,
    
    setValue = function(value)
        -- Set metronome volume in config
        reaper.SNM_SetDoubleConfigVar("projmetrolvol", value)
    end,
    
    onRightClick = function()
        -- Launch metronome settings (action 40363)
        reaper.Main_OnCommand(40363, 0)
    end
}

return widget
