-- Stereo vertical peak meters (-60..0 dB) shared by master peak-style widgets.

local M = {}

local METER_BG = 0x222222FF

--- Draw two vertical meters; fill color from combined peak_db (-60..0 segment).
function M.draw_stereo_vertical(draw_list, coords, opts)
    local meter_w = opts.meter_w or 8
    local gap = opts.gap or 2
    local x_left = opts.x_left
    local y = opts.y
    local h = opts.height
    local left_db = opts.left_db or -60
    local right_db = opts.right_db or -60
    local peak_db = opts.peak_db or math.max(left_db, right_db)
    local clip = opts.clip_indicator == true
    local round = opts.corner_round or 2

    local x_right = x_left + meter_w + gap

    local l_x1, l_y1 = coords:relativeToDrawList(x_left, y)
    local l_x2, l_y2 = coords:relativeToDrawList(x_left + meter_w, y + h)
    local r_x1, r_y1 = coords:relativeToDrawList(x_right, y)
    local r_x2, r_y2 = coords:relativeToDrawList(x_right + meter_w, y + h)

    reaper.ImGui_DrawList_AddRectFilled(draw_list, l_x1, l_y1, l_x2, l_y2, METER_BG, round)
    reaper.ImGui_DrawList_AddRectFilled(draw_list, r_x1, r_y1, r_x2, r_y2, METER_BG, round)

    local l_norm = math.max(0, math.min(1, (left_db + 60) / 60))
    local r_norm = math.max(0, math.min(1, (right_db + 60) / 60))
    local l_fill = h * l_norm
    local r_fill = h * r_norm

    local fill_color
    if (peak_db + 60) / 60 < 0.7 then
        fill_color = 0x00FF00FF
    elseif (peak_db + 60) / 60 < 0.9 then
        fill_color = 0xFFFF00FF
    else
        fill_color = 0xFF0000FF
    end

    if l_fill > 0 then
        local fy = l_y2 - l_fill
        reaper.ImGui_DrawList_AddRectFilled(draw_list, l_x1, fy, l_x2, l_y2, fill_color, round)
    end
    if r_fill > 0 then
        local fy = r_y2 - r_fill
        reaper.ImGui_DrawList_AddRectFilled(draw_list, r_x1, fy, r_x2, r_y2, fill_color, round)
    end

    if clip then
        reaper.ImGui_DrawList_AddRect(draw_list, l_x1, l_y1, l_x2, l_y2, 0xFF0000FF, 0, 0, 3)
        reaper.ImGui_DrawList_AddRect(draw_list, r_x1, r_y1, r_x2, r_y2, 0xFF0000FF, 0, 0, 3)
    end
end

return M
