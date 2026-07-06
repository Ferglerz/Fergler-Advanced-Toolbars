-- Renderers/01_Toolbar/switch_separator.lua

-- Thin line between toolbar-switch widget and main toolbar (same style as 03_Button_separator).
-- gap_before_sep: space between switch strip edge and separator column (can be larger than SPACING).
-- pin_shift_x: horizontal nudge when pinned with extra window width (left/center/right align).
function ToolbarWindow:drawToolbarSwitchSeparator(ctx, draw_list, coords, layout_switch, is_vertical, sep_size, centered_y, gap_before_sep, pin_shift_x, offset_x, offset_y, col_width)
    gap_before_sep = gap_before_sep or (CONFIG.SIZES and CONFIG.SIZES.SPACING) or 2
    pin_shift_x = pin_shift_x or 0
    offset_x = offset_x or 0
    offset_y = offset_y or 0
    local line_thickness = 2.0
    local line_color = CONFIG_MANAGER:color("SEPARATOR", "LINE", "NORMAL") or 0x666666FF
    local ww = col_width or reaper.ImGui_GetWindowWidth(ctx)
    local H = CONFIG.SIZES.HEIGHT
    local inset = math.max(2, math.floor(H / 6))

    if is_vertical then
        local separator_rel_y = layout_switch.height + gap_before_sep + sep_size / 2 + offset_y
        local x1_rel = 6 + pin_shift_x + offset_x
        local x2_rel = offset_x + ww - 6 + pin_shift_x
        local x1_draw, separator_y = coords:relativeToDrawList(x1_rel, separator_rel_y)
        local x2_draw, _ = coords:relativeToDrawList(x2_rel, separator_rel_y)
        reaper.ImGui_DrawList_AddLine(draw_list, x1_draw, separator_y, x2_draw, separator_y, line_color, line_thickness)
    else
        local separator_rel_x = layout_switch.width + gap_before_sep + sep_size / 2 + pin_shift_x + offset_x
        local y1_rel = centered_y + inset
        local y2_rel = centered_y + H - inset
        local separator_x = select(1, coords:relativeToDrawList(separator_rel_x, 0))
        local _, y1_draw = coords:relativeToDrawList(0, y1_rel)
        local _, y2_draw = coords:relativeToDrawList(0, y2_rel)
        reaper.ImGui_DrawList_AddLine(draw_list, separator_x, y1_draw, separator_x, y2_draw, line_color, line_thickness)
    end
end
