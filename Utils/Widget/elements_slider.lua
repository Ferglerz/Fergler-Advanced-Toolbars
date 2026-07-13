-- Utils/Widget/elements_slider.lua
-- Horizontal slider rendering and value readouts.

local DRAWING = require("Utils.Draw.drawing")
local INTERACTION = require("Utils.Widget.elements_interaction")

local M = {}

--- Centered value readout in a horizontal band (e.g. slider quick-chip slide-out).
function M.drawSliderValueReadout(ctx, coords, draw_list, widget, base_x, base_y, width, band_height, text_color, alpha_factor)
    local text = UTILS.formatWidgetValue(widget)
    DRAWING.drawCenteredBandText(ctx, coords, draw_list, base_x, base_y, width, band_height, text, text_color, { dim = true, alpha_factor = alpha_factor })
end

--- Slider and knob: value string vertically centered, optional label right-aligned.
function M.drawSliderWidgetValueAndLabel(ctx, coords, draw_list, widget, base_x, base_y, width, text_color, bg_color, band_height, text_pad)
    local text = UTILS.formatWidgetValue(widget)
    local value_color = bg_color or COLOR_UTILS.setAlpha(text_color, 0x80)
    local label_color = COLOR_UTILS.setAlpha(text_color, 0x80)

    local height = band_height or (CONFIG and CONFIG.SIZES and CONFIG.SIZES.HEIGHT or 24)
    local pad = text_pad or 4
    local text_rel_y = DRAWING.centeredTextRelY(ctx, base_y, height, 0)

    DRAWING.drawTextRelative(coords, draw_list, base_x + pad, text_rel_y, value_color, text)

    if widget.label and widget.label ~= "" then
        local label_width = reaper.ImGui_CalcTextSize(ctx, widget.label)
        DRAWING.drawTextRelative(coords, draw_list, base_x + width - label_width - pad, text_rel_y, label_color, widget.label)
    end
end

-- Horizontal Slider element
function M.slider(ctx, widget, coords, draw_list, rel_x, rel_y, render_width, render_height, text_color, bg_color, is_disabled, preview_mode, layout)
    local height
    if layout then
        height = require("Utils.Chips.chip_row").widget_body_height(layout)
    else
        height = render_height or CONFIG.SIZES.HEIGHT or 24
    end

    local sx, sy, sw = rel_x, rel_y, render_width

    local slider_bg = 0x222222FF
    local slider_fill
    if type(widget.col_primary) == "function" then
        local nativeColor = widget.col_primary()
        if nativeColor == nil then
            slider_fill = 0x888888FF
        else
            slider_fill = COLOR_UTILS.reaperColorToImGui(nativeColor)
        end
    else
        if widget.col_primary then
            slider_fill = COLOR_UTILS.reaperColorToImGui(widget.col_primary)
        else
            slider_fill = 0x888888FF
        end
    end

    local slider_handle = COLOR_UTILS.setAlpha(text_color, 0xFF)
    if is_disabled then
        local muted = COLOR_UTILS.widgetDisabledSliderVisuals(text_color, bg_color, slider_fill)
        slider_bg = muted.track_bg
        slider_fill = muted.fill_color
        text_color = muted.text_color
        bg_color = muted.value_color
        slider_handle = muted.handle_color
    end

    local track_height = 8
    local track_rel_y = sy + (height - track_height) / 2 + 5
    local track_rel_x1 = sx + 10
    local track_rel_x2 = sx + sw - 10
    local track_width = track_rel_x2 - track_rel_x1

    DRAWING.drawRectFilledRelative(coords, draw_list, track_rel_x1, track_rel_y, track_width, track_height, slider_bg, track_height / 2)

    local normalized, range, min_v, max_v = UTILS.widgetSliderNormalized(widget)

    local fill_width = track_width * normalized
    DRAWING.drawRectFilledRelative(coords, draw_list, track_rel_x1, track_rel_y, fill_width, track_height, slider_fill, track_height / 2)

    local handle_radius = track_height - 1
    local handle_rel_x = track_rel_x1 + fill_width
    local handle_rel_y = track_rel_y + track_height / 2

    local handle_x, handle_y = coords:relativeToDrawList(handle_rel_x, handle_rel_y)
    reaper.ImGui_DrawList_AddCircleFilled(draw_list, handle_x, handle_y, handle_radius, slider_handle, 20)

    local show_value_on_toolbar = not (widget._slide_out_mode and widget.slider_quick_chips)
        and not widget.slider_drag_tooltip
    if show_value_on_toolbar then
        M.drawSliderWidgetValueAndLabel(ctx, coords, draw_list, widget, sx, sy, sw, text_color, bg_color)
    end

    if not preview_mode then
        local track_width = track_rel_x2 - track_rel_x1
        INTERACTION.handleDragInteraction(ctx, widget, coords, is_disabled, range, min_v, max_v, "slider", track_width, track_rel_x1)
        INTERACTION.showSliderDragTooltip(ctx, widget)
    end
end

return M
