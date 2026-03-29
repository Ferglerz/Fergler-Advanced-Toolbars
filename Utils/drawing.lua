-- Utils/drawing.lua
local Drawing = {}

-- angle: Direction in degrees (0 = up, 90 = right, 180 = down, 270 = left)
function Drawing.triangle(draw_list, center_x, center_y, width, height, color, angle)
    -- Convert angle to radians
    local rad = math.rad(angle)
    
    -- Calculate the three points of the triangle based on the angle
    -- The triangle points in the direction specified by angle
    local point1_x = center_x + math.sin(rad) * (height / 2)
    local point1_y = center_y - math.cos(rad) * (height / 2)
    
    local point2_x = center_x - math.sin(rad + math.pi/2) * (width / 2)
    local point2_y = center_y + math.cos(rad + math.pi/2) * (width / 2)
    
    local point3_x = center_x + math.sin(rad + math.pi/2) * (width / 2)
    local point3_y = center_y - math.cos(rad + math.pi/2) * (width / 2)
    
    -- Draw the triangle
    reaper.ImGui_DrawList_AddTriangleFilled(
        draw_list,
        point1_x, point1_y,  -- Point in the direction of angle
        point2_x, point2_y,  -- Point to the 'left' of the direction
        point3_x, point3_y,  -- Point to the 'right' of the direction
        color
    )
end

Drawing.ANGLE_UP = 0
Drawing.ANGLE_RIGHT = 90
Drawing.ANGLE_DOWN = 180
Drawing.ANGLE_LEFT = 270

-- Shared layout for custom display widgets (matches Renderers/_Widgets display path)
function Drawing.drawWidgetCenteredValueText(ctx, text, rel_x, rel_y, span_width, height, coords, draw_list, text_color, vertical_offset)
    vertical_offset = vertical_offset or 7
    local text_width = reaper.ImGui_CalcTextSize(ctx, text)
    local text_rel_x = rel_x + (span_width - text_width) / 2
    local text_rel_y = rel_y + (height - reaper.ImGui_GetTextLineHeight(ctx)) / 2 + vertical_offset
    local tx, ty = coords:relativeToDrawList(text_rel_x, text_rel_y)
    reaper.ImGui_DrawList_AddText(draw_list, tx, ty, text_color, text)
end

function Drawing.drawWidgetCenteredLabel(ctx, widget, rel_x, rel_y, span_width, coords, draw_list, label_rel_y)
    if not widget.label or widget.label == "" then
        return
    end
    label_rel_y = label_rel_y or (rel_y + 1)
    local label_color = COLOR_UTILS.toImGuiColor(CONFIG.COLORS.GROUP.LABEL)
    local label_width = reaper.ImGui_CalcTextSize(ctx, widget.label)
    local label_rel_x = rel_x + (span_width - label_width) / 2
    local lx, ly = coords:relativeToDrawList(label_rel_x, label_rel_y)
    reaper.ImGui_DrawList_AddText(draw_list, lx, ly, label_color, widget.label)
end

return Drawing
