-- widgets/master_peak.lua
local widget = {
    name = "Master Peak Display",
    category = "Mix & monitoring",
    update_interval = 0.033,
    type = "display",
    width = 90,
    format = "%.1f dB",
    title = "",
    display_style = "meter_strip",
    description = "Shows master track peak level with meter. Click to toggle master track in TCP.",

    peak_level = -60,
    left_level = -60,
    right_level = -60,
    session_peak = -60,
    clip_indicator = false,
    last_play_state = 0,

    getValue = function(self)
        local play_state = reaper.GetPlayState()
        local is_playing = (play_state & 1) == 1 or (play_state & 4) == 4
        local was_playing = (self.last_play_state & 1) == 1 or (self.last_play_state & 4) == 4

        if is_playing and not was_playing then
            self.session_peak = -60
            self.clip_indicator = false
        end

        local master_track = reaper.GetMasterTrack(0)
        if master_track then
            local left_peak = reaper.Track_GetPeakInfo(master_track, 0) or 0
            local right_peak = reaper.Track_GetPeakInfo(master_track, 1) or left_peak

            local left_db = UTILS.peakLinearToDb(left_peak)
            local right_db = UTILS.peakLinearToDb(right_peak)

            self.left_level = left_db
            self.right_level = right_db
            self.peak_level = math.max(left_db, right_db)

            if is_playing then
                self.session_peak = math.max(self.session_peak or -60, self.peak_level)
            end

            if self.peak_level > -0.1 then
                self.clip_indicator = true
            end
        end

        if play_state == 1 and self.last_play_state == 0 then
            self.clip_indicator = false
        end
        self.last_play_state = play_state

        return self.session_peak or self.peak_level
    end,

    display_meter = function(self)
        return {
            left_db = self.left_level,
            right_db = self.right_level,
            peak_db = self.peak_level,
            clip_indicator = self.clip_indicator,
        }
    end,

    onClick = function()
        reaper.Main_OnCommand(40075, 0)
    end,
}

return widget
