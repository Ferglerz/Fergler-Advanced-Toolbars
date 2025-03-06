-- presets/volume_slider.lua
local preset = {
    name = "Track Volume Read-out",
    update_interval = 0.05,
    type = "display",
    width = 180,
    min_value = -60,
    max_value = 12,
    format = "%.1f dB",
    label = "Volume",
    description = "Controls volume of selected track",
    -- Directly define functions
    getValue = function(reaper)
        local track = reaper.GetSelectedTrack(0, 0)
        if track then
            local vol = reaper.GetMediaTrackInfo_Value(track, "D_VOL")
            return 20 * math.log(vol, 10)
        end
        return nil
    end,
    }

return preset
