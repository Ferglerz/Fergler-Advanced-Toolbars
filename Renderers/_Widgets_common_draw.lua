-- Renderers/_Widgets_common_draw.lua
-- Shared ImGui draw bits for widget renderers (_Widgets.lua, _Widgets_slider, _Widgets_knob).

local M = {}

function M.drawWidgetGroupLabelCentered(ctx, widget, rel_x, rel_y, render_width, coords, draw_list)
    if not widget.label or widget.label == "" then
        return
    end
    local label_color = COLOR_UTILS.toImGuiColor(CONFIG.COLORS.GROUP.LABEL)
    local label_width = reaper.ImGui_CalcTextSize(ctx, widget.label)
    local label_rel_x = rel_x + (render_width - label_width) / 2
    local label_rel_y = rel_y + 1
    local label_x, label_y = coords:relativeToDrawList(label_rel_x, label_rel_y)
    reaper.ImGui_DrawList_AddText(draw_list, label_x, label_y, label_color, widget.label)
end

--- Dropdown-style: label at rel_x + lead_x (default 4).
function M.drawWidgetGroupLabelLeading(ctx, widget, rel_x, rel_y, coords, draw_list, lead_x)
    if not widget.label or widget.label == "" then
        return
    end
    lead_x = lead_x or 4
    local label_color = COLOR_UTILS.toImGuiColor(CONFIG.COLORS.GROUP.LABEL)
    local label_rel_x = rel_x + lead_x
    local label_rel_y = rel_y + 1
    local label_x, label_y = coords:relativeToDrawList(label_rel_x, label_rel_y)
    reaper.ImGui_DrawList_AddText(draw_list, label_x, label_y, label_color, widget.label)
end

--- Slider and knob: value string vertically centered, optional label right-aligned.
function M.drawSliderWidgetValueAndLabel(ctx, coords, draw_list, widget, base_x, base_y, width, text_color)
    local slider_value = widget.value
    local text
    if type(widget.format) == "function" then
        text = widget.format(slider_value or 0)
    else
        local slider_fmt = type(slider_value) == "number" and "%.2f" or "%s"
        text = UTILS.safeFormat(widget.format or slider_fmt, slider_value or 0)
    end
    local text_color_half = text_color & 0xFFFFFF00 | 0x80
    
    local text_w, text_h = reaper.ImGui_CalcTextSize(ctx, text)
    local height = CONFIG and CONFIG.SIZES and CONFIG.SIZES.HEIGHT or 24
    local text_y_offset = (height - text_h) / 2
    local text_x, text_y = coords:relativeToDrawList(base_x + 4, base_y + text_y_offset)
    
    reaper.ImGui_DrawList_AddText(draw_list, text_x, text_y, text_color_half, text)
    
    if widget.label and widget.label ~= "" then
        local label_width, label_height = reaper.ImGui_CalcTextSize(ctx, widget.label)
        local label_y_offset = (height - label_height) / 2
        local label_x, label_y = coords:relativeToDrawList(base_x + width - label_width - 4, base_y + label_y_offset)
        reaper.ImGui_DrawList_AddText(draw_list, label_x, label_y, text_color_half, widget.label)
    end
end

return M
