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

-- Edit-mode insertion chip: outer disk = toolbar text color, inner white, legacy line-drawn + / × (same geometry as old triangle chip).
function Drawing.insertionGlyph(draw_list, cx, cy, outer_r, outer_color, symbol)
    local oc = (outer_color & 0xFFFFFF00) | 0xFF
    reaper.ImGui_DrawList_AddCircleFilled(draw_list, cx, cy, outer_r, oc, 24)

    -- Legacy symbol metrics (renderTriangleWithSymbol): tw = 2*tsz, s = tw/2 = tsz, t = 2
    local tsz_legacy = CONFIG.SIZES.HEIGHT / 4
    local s = tsz_legacy
    local t = 2.0
    local min_inner = s / 2 + 2
    local inner_r = math.min(outer_r - 1.5, math.max(outer_r * 0.58, min_inner))
    if inner_r < 2 then
        inner_r = 2
    end
    if inner_r >= outer_r then
        inner_r = outer_r - 1.5
    end
    reaper.ImGui_DrawList_AddCircleFilled(draw_list, cx, cy, inner_r, COLOR_UTILS.toImGuiColor("#FFFFFFFF"), 24)

    local black = COLOR_UTILS.toImGuiColor("#000000FF")
    if symbol == "plus" then
        reaper.ImGui_DrawList_AddLine(draw_list, cx - s / 2, cy, cx + s / 2, cy, black, t)
        reaper.ImGui_DrawList_AddLine(draw_list, cx, cy - s / 2, cx, cy + s / 2, black, t)
    else
        reaper.ImGui_DrawList_AddLine(draw_list, cx - s / 2, cy - s / 2, cx + s / 2, cy + s / 2, black, t)
        reaper.ImGui_DrawList_AddLine(draw_list, cx + s / 2, cy - s / 2, cx - s / 2, cy + s / 2, black, t)
    end
end

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

-- Shared text-chip metrics for compact widget/button action pills.
function Drawing.getTextChipMetrics(ctx, text, inset_h, inset_v)
    inset_h = inset_h or 4
    inset_v = inset_v or 3
    local line_h = reaper.ImGui_GetTextLineHeight(ctx)
    local text_w = reaper.ImGui_CalcTextSize(ctx, text or "")
    local chip_w = text_w + inset_h * 2
    local chip_h = line_h + inset_v * 2
    return text_w, line_h, chip_w, chip_h
end

-- Right-aligned chip rectangle inside a button/widget.
function Drawing.getRightAlignedTextChipRect(ctx, rel_x, rel_y, render_width, text, right_pad, inset_h, inset_v)
    right_pad = right_pad or 0
    local _, _, chip_w, chip_h = Drawing.getTextChipMetrics(ctx, text, inset_h, inset_v)
    local chip_x = rel_x + render_width - chip_w - right_pad
    local chip_y = rel_y + (CONFIG.SIZES.HEIGHT - chip_h) / 2
    return chip_x, chip_y, chip_w, chip_h
end

-- Draw a rounded text chip at relative coordinates.
function Drawing.drawTextChip(ctx, coords, draw_list, rel_x, rel_y, width, height, text, style)
    style = style or {}
    local rounding = style.rounding or 3
    local text_color = style.text_color or 0xFFFFFFFF
    local bg_color = style.bg_color or 0x00000000
    local border_color = style.border_color

    local x1, y1 = coords:relativeToDrawList(rel_x, rel_y)
    local x2, y2 = coords:relativeToDrawList(rel_x + width, rel_y + height)
    reaper.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, bg_color, rounding)
    if border_color then
        reaper.ImGui_DrawList_AddRect(draw_list, x1, y1, x2, y2, border_color, rounding)
    end

    local text_w = reaper.ImGui_CalcTextSize(ctx, text or "")
    local text_rel_x = rel_x + (width - text_w) / 2
    local text_rel_y = rel_y + (height - reaper.ImGui_GetTextLineHeight(ctx)) / 2
    local tx, ty = coords:relativeToDrawList(text_rel_x, text_rel_y)
    reaper.ImGui_DrawList_AddText(draw_list, tx, ty, text_color, text or "")
end

return Drawing
