-- Utils/Widget/elements_knob.lua
-- Rotary knob rendering (knob and simple_knob styles).

local DRAWING = require("Utils.Draw.drawing")
local KNOB_LAYOUT = require("Utils.Widget.knob_layout")
local INTERACTION = require("Utils.Widget.elements_interaction")
local SLIDER = require("Utils.Widget.elements_slider")

local M = {}

-- Rotary Knob element (supports both "knob" and "simple_knob" styles)
function M.knob(ctx, widget, coords, draw_list, rel_x, rel_y, render_width, render_height, text_color, bg_color, is_disabled, preview_mode, style, bg_only)
    local height = render_height or CONFIG.SIZES.HEIGHT or 24
    style = style or widget.slider_style or "knob"

    local track_bg = 0x222222FF
    local arc_value_color = bg_color or 0x888888FF
    arc_value_color = COLOR_UTILS.setAlpha(arc_value_color, 0xFF)

    local value_bg_color = bg_color
    local ring_color = COLOR_UTILS.setAlpha(track_bg, 0x55)
    local dim_arc_color = COLOR_UTILS.setAlpha(track_bg, 0x35)

    if is_disabled then
        local muted = COLOR_UTILS.widgetDisabledSliderVisuals(text_color, bg_color, arc_value_color)
        track_bg = muted.track_bg
        arc_value_color = muted.fill_color
        text_color = muted.text_color
        value_bg_color = muted.value_color
        ring_color = muted.ring_color
        dim_arc_color = muted.dim_arc
    end

    local normalized, range, min_v, max_v = UTILS.widgetSliderNormalized(widget)

    local edge_pad = style == "simple_knob" and 0 or 3

    local radius
    if style == "simple_knob" then
        radius = math.max(6, (height - 2 * edge_pad) / 2)
    else
        local max_r = math.min((render_width - 2 * edge_pad) / 2, (height - 2 * edge_pad) / 2)
        radius = math.max(6, max_r)
    end

    local cx_rel, cy_rel
    local direction = widget.knob_bg_direction or "right"

    if style == "simple_knob" then
        if direction == "left" then
            cx_rel = rel_x + edge_pad + radius
        else
            cx_rel = rel_x + render_width - edge_pad - radius
        end
    else
        cx_rel = rel_x + render_width / 2
    end
    cy_rel = rel_y + height / 2

    local text_area_x, text_area_w = KNOB_LAYOUT.text_area(rel_x, render_width, style, direction, height, ctx)
    local readout_pad = KNOB_LAYOUT.readout_outer_pad(ctx, height)
    local bg_x1, bg_x2
    if style == "simple_knob" then
        if direction == "left" then
            bg_x1 = cx_rel
            bg_x2 = rel_x + render_width - readout_pad
        else
            bg_x1 = rel_x + readout_pad
            bg_x2 = cx_rel
        end
    end

    local cx, cy = coords:relativeToDrawList(cx_rel, cy_rel)

    -- Draw background flag for simple_knob (matches regular chip height; metrics scale with button height)
    if style == "simple_knob" then
        local flag_y, flag_band_h, flag_rounding = KNOB_LAYOUT.flag_chip_band(ctx, height)
        local flag_bg, _ = COLOR_UTILS.widgetPillColors(text_color, bg_color or track_bg, { filled = true })
        if is_disabled then
            flag_bg = COLOR_UTILS.modulateAlpha(COLOR_UTILS.setAlpha(flag_bg, 0x55), COLOR_UTILS.WIDGET_DISABLED_EXTRA_FADE)
        end
        local flags = direction == "left" and reaper.ImGui_DrawFlags_RoundCornersRight() or reaper.ImGui_DrawFlags_RoundCornersLeft()
        DRAWING.drawRectFilledRelative(coords, draw_list, bg_x1, rel_y + flag_y, bg_x2 - bg_x1, flag_band_h, flag_bg, flag_rounding, flags)
    end

    -- Draw knob body
    reaper.ImGui_DrawList_AddCircleFilled(draw_list, cx, cy, radius, track_bg, 24)
    reaper.ImGui_DrawList_AddCircle(draw_list, cx, cy, radius, ring_color, 0, 1.0)

    if not bg_only then
        -- Lit arc
        local a0 = math.rad(135) + math.rad(90)
        local span = math.rad(270)
        local arc_r = radius - 2
        local dim_arc = dim_arc_color
        local N = 32
        for j = 0, N - 1 do
            local ang1 = a0 + (j / N) * span
            local ang2 = a0 + ((j + 1) / N) * span
            local x1 = cx + math.sin(ang1) * arc_r
            local y1 = cy - math.cos(ang1) * arc_r
            local x2 = cx + math.sin(ang2) * arc_r
            local y2 = cy - math.cos(ang2) * arc_r
            local lit = (j + 0.5) / N < normalized
            reaper.ImGui_DrawList_AddLine(draw_list, x1, y1, x2, y2, lit and arc_value_color or dim_arc, 3.0)
        end

        -- Pointer
        local pointer_a = a0 + normalized * span
        local pr = radius * 0.72
        local px = cx + math.sin(pointer_a) * pr
        local py = cy - math.cos(pointer_a) * pr
        reaper.ImGui_DrawList_AddLine(draw_list, cx, cy, px, py, arc_value_color, 2.0)

        -- Text value
        if not widget.slider_drag_tooltip then
            local flag_y, flag_band_h, _, flag_text_pad = KNOB_LAYOUT.flag_chip_band(ctx, height)
            SLIDER.drawSliderWidgetValueAndLabel(ctx, coords, draw_list, widget, text_area_x, rel_y + flag_y, text_area_w, text_color, value_bg_color, flag_band_h, flag_text_pad)
        end

        if not preview_mode then
            local pixels_full = widget.knob_vertical_pixels or 100
            INTERACTION.handleDragInteraction(ctx, widget, coords, is_disabled, range, min_v, max_v, "knob", pixels_full)
            INTERACTION.showSliderDragTooltip(ctx, widget)
        end
    end
end

return M
