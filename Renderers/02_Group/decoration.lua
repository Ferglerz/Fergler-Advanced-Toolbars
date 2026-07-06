function GroupRenderer:calculateDecorationGeometry(label_x, label_y, text_width, text_height, left_x_draw, right_x_draw, is_vertical)
    local line_thickness = 1.0
    local h_padding = math.max(1, math.floor((CONFIG.SIZES.PADDING or 6) / 2))

    local rounding
    if is_vertical then
        rounding = CONFIG.SIZES.ROUNDING
    else
        rounding = math.min(CONFIG.SIZES.ROUNDING, CONFIG.SIZES.HEIGHT / 2)
    end

    local curve_size
    if is_vertical then
        curve_size = rounding
    else
        curve_size = rounding + 4 + text_height / 2
    end

    local left_line_start = label_x - h_padding
    local left_line_end
    local right_line_start = label_x + text_width + h_padding
    local right_line_end
    if is_vertical then
        left_line_end = left_x_draw
        right_line_end = right_line_start + (left_line_start - left_line_end) - 2
    else
        left_line_end = left_x_draw + curve_size - h_padding
        right_line_end = right_x_draw - curve_size + h_padding
    end

    return {
        left_line_start = left_line_start,
        left_line_end = left_line_end,
        right_line_start = right_line_start,
        right_line_end = right_line_end,
        label_y = label_y,
        curve_size = curve_size,
        line_thickness = line_thickness
    }
end

-- Draw a single curve segment
function GroupRenderer:drawCurveSegment(draw_list, line_end, label_y, curve_size, t, next_t, is_left, line_color, line_thickness)
    local alpha = is_left and (1 - t) or t
    local angle = is_left and (math.pi * (1 - t) / 2) or (math.pi * t / 2)
    local next_angle = is_left and (math.pi * (1 - next_t) / 2) or (math.pi * next_t / 2)
    
    local curve_x = line_end + (is_left and -1 or 1) * curve_size * math.cos(angle)
    local curve_y = label_y - curve_size + curve_size * math.sin(angle)
    
    local next_x = line_end + (is_left and -1 or 1) * curve_size * math.cos(next_angle)
    local next_y = label_y - curve_size + curve_size * math.sin(next_angle)
    
    local color = COLOR_UTILS.modulateAlpha(line_color, alpha)
    
    reaper.ImGui_DrawList_AddLine(draw_list, curve_x, curve_y, next_x, next_y, color, line_thickness)
end

-- Render decoration lines (horizontal lines)
function GroupRenderer:renderDecorationLines(draw_list, geometry, line_color)
    reaper.ImGui_DrawList_AddLine(
        draw_list,
        geometry.left_line_start,
        geometry.label_y,
        geometry.left_line_end,
        geometry.label_y,
        line_color,
        geometry.line_thickness
    )
    reaper.ImGui_DrawList_AddLine(
        draw_list,
        geometry.right_line_start,
        geometry.label_y,
        geometry.right_line_end,
        geometry.label_y,
        line_color,
        geometry.line_thickness
    )
end

-- Render decoration curves
function GroupRenderer:renderDecorationCurves(draw_list, geometry, line_color)
    local segments = 16
    for i = 0, segments - 1 do
        local t = i / segments
        local next_t = (i + 1) / segments
        
        -- Draw left curve segment
        self:drawCurveSegment(
            draw_list,
            geometry.left_line_end,
            geometry.label_y,
            geometry.curve_size,
            t,
            next_t,
            true, -- is_left
            line_color,
            geometry.line_thickness
        )
        
        -- Draw right curve segment
        self:drawCurveSegment(
            draw_list,
            geometry.right_line_end,
            geometry.label_y,
            geometry.curve_size,
            t,
            next_t,
            false, -- is_left
            line_color,
            geometry.line_thickness
        )
    end
end

-- Main label decoration rendering function (orchestration)
function GroupRenderer:renderLabelDecoration(draw_list, label_x, label_y, text_width, text_height, left_x_draw, right_x_draw, is_vertical, line_color_override)
    local line_color = line_color_override or CONFIG_MANAGER:color("GROUP", "DECORATION")

    local geometry = self:calculateDecorationGeometry(label_x, label_y, text_width, text_height, left_x_draw, right_x_draw, is_vertical)
    
    -- Render lines
    self:renderDecorationLines(draw_list, geometry, line_color)
    
    -- Render curves
    self:renderDecorationCurves(draw_list, geometry, line_color)
end

return GroupRenderer