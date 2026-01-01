-- widgets/master_peak.lua
local widget = {
    name = "Master Peak Display",
    update_interval = 0.033, -- ~30 FPS
    type = "display",
    width = 90,
    format = "%.1f dB",
    label = "Master",
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
            local left_db = left_peak > 0 and (20 * math.log(left_peak, 10)) or -60
            local right_db = right_peak > 0 and (20 * math.log(right_peak, 10)) or -60
            
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
    
    renderCustom = function(ctx, self, rel_x, rel_y, render_width, coords, draw_list, text_color)
        local height = CONFIG.SIZES.HEIGHT
        
        -- Draw stereo meter backgrounds
        local meter_width = 8
        local meter_spacing = 2
        local meter_total_width = meter_width * 2 + meter_spacing
        local meter_height = height - 15
        local meter_y = rel_y + 11
        local meter_x_left = rel_x + render_width - meter_total_width - 4
        local meter_x_right = meter_x_left + meter_width + meter_spacing
        
        local l_bg_x1, l_bg_y1 = coords:relativeToDrawList(meter_x_left, meter_y)
        local l_bg_x2, l_bg_y2 = coords:relativeToDrawList(meter_x_left + meter_width, meter_y + meter_height)
        local r_bg_x1, r_bg_y1 = coords:relativeToDrawList(meter_x_right, meter_y)
        local r_bg_x2, r_bg_y2 = coords:relativeToDrawList(meter_x_right + meter_width, meter_y + meter_height)
        
        -- Backgrounds
        reaper.ImGui_DrawList_AddRectFilled(draw_list, l_bg_x1, l_bg_y1, l_bg_x2, l_bg_y2, 0x222222FF, 2)
        reaper.ImGui_DrawList_AddRectFilled(draw_list, r_bg_x1, r_bg_y1, r_bg_x2, r_bg_y2, 0x222222FF, 2)
        
        -- Calculate fill heights based on per-channel levels (-60 to 0 dB range)
        local l_norm = math.max(0, math.min(1, (self.left_level + 60) / 60))
        local r_norm = math.max(0, math.min(1, (self.right_level + 60) / 60))
        local l_fill_height = meter_height * l_norm
        local r_fill_height = meter_height * r_norm
        
        -- Color based on level (green -> yellow -> red)
        local fill_color
        if (self.peak_level + 60) / 60 < 0.7 then
            fill_color = 0x00FF00FF -- Green
        elseif (self.peak_level + 60) / 60 < 0.9 then
            fill_color = 0xFFFF00FF -- Yellow
        else
            fill_color = 0xFF0000FF -- Red
        end
        
        -- Draw fill
        if l_fill_height > 0 then
            local fill_y = l_bg_y2 - l_fill_height
            reaper.ImGui_DrawList_AddRectFilled(draw_list, l_bg_x1, fill_y, l_bg_x2, l_bg_y2, fill_color, 2)
        end
        if r_fill_height > 0 then
            local fill_y = r_bg_y2 - r_fill_height
            reaper.ImGui_DrawList_AddRectFilled(draw_list, r_bg_x1, fill_y, r_bg_x2, r_bg_y2, fill_color, 2)
        end
        
        -- Draw clip indicator (red border when clipping)
        if self.clip_indicator then
            reaper.ImGui_DrawList_AddRect(draw_list, l_bg_x1, l_bg_y1, l_bg_x2, l_bg_y2, 0xFF0000FF, 0, 0, 3)
            reaper.ImGui_DrawList_AddRect(draw_list, r_bg_x1, r_bg_y1, r_bg_x2, r_bg_y2, 0xFF0000FF, 0, 0, 3)
        end
        
        -- Draw text
        local text = string.format(self.format or "%.1f dB", self.session_peak or self.peak_level)
        local text_width = reaper.ImGui_CalcTextSize(ctx, text)
        local text_x = rel_x + (render_width - meter_total_width - text_width - 8) / 2
        local text_y = rel_y + (height - reaper.ImGui_GetTextLineHeight(ctx)) / 2 + 7
        
        local text_draw_x, text_draw_y = coords:relativeToDrawList(text_x, text_y)
        reaper.ImGui_DrawList_AddText(draw_list, text_draw_x, text_draw_y, text_color, text)
        
        -- Draw label
        if self.label and self.label ~= "" then
            local label_color = COLOR_UTILS.toImGuiColor(CONFIG.COLORS.GROUP.LABEL)
            local label_width = reaper.ImGui_CalcTextSize(ctx, self.label)
            local label_x = rel_x + (render_width - meter_width - label_width - 8) / 2
            local label_y = rel_y + 1
            
            local label_draw_x, label_draw_y = coords:relativeToDrawList(label_x, label_y)
            reaper.ImGui_DrawList_AddText(draw_list, label_draw_x, label_draw_y, label_color, self.label)
        end
    end
}

return widget
