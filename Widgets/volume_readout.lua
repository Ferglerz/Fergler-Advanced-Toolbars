-- widgets/volume_readout.lua
local widget = {
    name = "Track Volume Read-out",
    category = "Mix & monitoring",
    update_interval = 0.05,
    type = "display",
    width = 180,
    min_value = -60,
    max_value = 12,
    format = "%.1f dB",
    title = "Volume",
    description = "Display volume of last selected track",
    
    getValue = function()
        return UTILS.getSelectedTrackVolumeDb()
    end
}

return widget
