-- Renderers/01_Toolbar/helpers.lua

function ToolbarWindow:toolbarEdgePad()
    return math.max(1, math.floor((CONFIG.SIZES.PADDING or 6) / 2))
end

function ToolbarWindow:pinHeightPad()
    return self:toolbarEdgePad() * 2
end

-- REAPER API: col_main_bg2 = main window / transport background (see SetThemeColor / GetThemeColor docs).
function ToolbarWindow:themeTransportBackgroundImgui()
    if not reaper.GetThemeColor then
        return nil
    end
    local ok, c = pcall(function()
        return reaper.GetThemeColor("col_main_bg2", 0)
    end)
    if not ok or type(c) ~= "number" or c < 0 then
        return nil
    end
    return COLOR_UTILS.reaperColorToImGui(c)
end

-- Pinned UI-anchor toolbars always use horizontal row layout; height is content minimum only.
function ToolbarWindow:computePinnedMinContentHeight(layout, layout_switch, show_switch)
    if not layout.groups or #layout.groups == 0 then
        local label = (CONFIG.UI and CONFIG.UI.USE_GROUP_LABELS) and 24 or 0
        return (CONFIG.SIZES.HEIGHT or 38) + label + self:pinHeightPad()
    end
    local row_h = layout.height
    if show_switch and layout_switch then
        row_h = math.max(row_h, layout_switch.height)
    end
    return row_h + self:pinHeightPad()
end

function ToolbarWindow:buildPlaceholderShadowToolbar(currentToolbar, ph_group, ph_button)
    return {
        section = currentToolbar.section,
        name = currentToolbar.name,
        custom_name = currentToolbar.custom_name,
        groups = { ph_group },
        buttons = { ph_button },
        updateName = currentToolbar.updateName,
        addButton = currentToolbar.addButton
    }
end

function ToolbarWindow:renderEmptyDropHighlight(ctx, draw_list, coords, rect)
    local x1, y1 = coords:relativeToDrawList(rect.rel_x, rect.rel_y)
    local x2, y2 = coords:relativeToDrawList(rect.rel_x + rect.width, rect.rel_y + rect.height)
    reaper.ImGui_DrawList_AddRect(draw_list, x1, y1, x2, y2, 0x00FF00FF, 0, 0, 3)
end

function ToolbarWindow:calculateVerticalCenter(ctx, layout, editing_mode)
    if layout and layout.is_vertical then
        return (layout.padding_y or 0)
    end

    local window_height = reaper.ImGui_GetWindowHeight(ctx)
    local content_height = layout.height
    local center_y = (window_height - content_height) / 2
    local min_padding = self:toolbarEdgePad()
    return math.max(center_y, min_padding)
end

-- Thin line between toolbar-switch widget and main toolbar (same style as 03_Button_separator).
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
