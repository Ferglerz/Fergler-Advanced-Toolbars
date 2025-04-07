-- widgets/volume_slider.lua
local widget = {
    name = "Track Volume Slider",
    default_value = 0.0,
    update_interval = 0.05,
    col_primary = function()
        local track = reaper.GetSelectedTrack(0, 0)
        if track then
            local color_native = reaper.GetMediaTrackInfo_Value(track, "I_CUSTOMCOLOR")
            return color_native
        end
        return nil
    end,
    type = "slider",
    width = 180,
    min_value = -60,
    max_value = 12,
    format = "%.1f dB",
    label = "Volume",
    description = "Controls volume of selected tracks",

    getValue = function()
        local track = reaper.GetSelectedTrack(0, 0)
        if track then
            local vol = reaper.GetMediaTrackInfo_Value(track, "D_VOL")
            return 20 * math.log(vol, 10) -- Convert to dB
        end
        return nil
    end,
    setValue = function(value)
        local num_tracks = reaper.CountSelectedTracks(0)
        for i = 0, num_tracks - 1 do
            local track = reaper.GetSelectedTrack(0, i)
            if track then
                local vol = 10 ^ (value / 20) -- Convert from dB
                reaper.SetMediaTrackInfo_Value(track, "D_VOL", vol)
            end
        end
    end
}

return widget
