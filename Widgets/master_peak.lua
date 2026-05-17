-- widgets/master_peak.lua
local PEAK_METERS = require("Utils.widget_draw_peak_meters")

local widget = {
    name = "Master Peak Display",
    category = "Mix & monitoring",
    update_interval = 0.033, -- ~30 FPS
    type = "display",
    width = 90,
    format = "%.1f dB",
    title = "Master",
    description = "Shows master track peak level with meter. Click to toggle master track in TCP.",
    
    -- Meter state
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

        -- Reset running peak on new playback start
        if is_playing and not was_playing then
            self.session_peak = -60
            self.clip_indicator = false
        end

        -- Get master track
        local master_track = reaper.GetMasterTrack(0)
        if master_track then
            -- Get peak info per-channel; Track_GetPeakInfo returns one value per call
            local left_peak = reaper.Track_GetPeakInfo(master_track, 0) or 0
            local right_peak = reaper.Track_GetPeakInfo(master_track, 1) or left_peak
            
            -- Convert to dB and take the higher of the two
            local left_db = UTILS.peakLinearToDb(left_peak)
            local right_db = UTILS.peakLinearToDb(right_peak)
            
            self.left_level = left_db
            self.right_level = right_db
            self.peak_level = math.max(left_db, right_db)
            
            if is_playing then
                self.session_peak = math.max(self.session_peak or -60, self.peak_level)
            end

            -- Check for clipping (above -0.1 dB)
            if self.peak_level > -0.1 then
                self.clip_indicator = true
            end
        end
        
        -- Reset clip indicator on playback start after stop
        if play_state == 1 and self.last_play_state == 0 then
            self.clip_indicator = false
        end
        self.last_play_state = play_state
        
        return self.session_peak or self.peak_level
    end,
    
    onClick = function()
        -- Toggle master track visibility in TCP (action 40075)
        reaper.Main_OnCommand(40075, 0)
    end,
    
    renderCustom = function(ctx, self, rel_x, rel_y, render_width, coords, draw_list, text_color, _layout, _bg_color)
        local height = CONFIG.SIZES.HEIGHT

        local meter_width = 8
        local meter_spacing = 2
        local meter_total_width = meter_width * 2 + meter_spacing
        local meter_height = height - 15
        local meter_y = rel_y + 11
        local meter_x_left = rel_x + render_width - meter_total_width - 4

        PEAK_METERS.draw_stereo_vertical(draw_list, coords, {
            x_left = meter_x_left,
            y = meter_y,
            meter_w = meter_width,
            gap = meter_spacing,
            height = meter_height,
            left_db = self.left_level,
            right_db = self.right_level,
            peak_db = self.peak_level,
            clip_indicator = self.clip_indicator,
            corner_round = 2,
        })

        local text_span = render_width - meter_total_width - 8
        local text = string.format(self.format or "%.1f dB", self.session_peak or self.peak_level)
        DRAWING.drawWidgetCenteredValueText(ctx, text, rel_x, rel_y, text_span, height, coords, draw_list, text_color, 7)
        DRAWING.drawWidgetCenteredLabel(ctx, self, rel_x, rel_y, text_span, coords, draw_list, rel_y + 1)
    end
}

return widget
