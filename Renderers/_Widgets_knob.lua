-- Renderers/_Widgets_knob.lua
-- Circular knob for slider-type widgets when widget.slider_style == "knob".
-- Interaction: vertical drag (up = increase). Shift = fine (widget.fine_scale). Cmd = snap.

local WIDGET_DRAW = require("Renderers._Widgets_common_draw")
return function(ctx, widget, rel_x, rel_y, render_width, coords, draw_list, text_color, bg_color, preview_mode)
    local height = CONFIG.SIZES.HEIGHT
    local is_disabled = widget.is_disabled and widget.is_disabled() or false

    local track_bg = 0x222222FF
    -- Lit arc uses the same face color as the toolbar button (not widget.col_primary).
    local arc_value_color = bg_color or 0x888888FF
    arc_value_color = arc_value_color & 0xFFFFFF00 | 0xFF

    if is_disabled then
        track_bg = 0x1A1A1AFF
        arc_value_color = arc_value_color & 0xFFFFFF00 | 0x55
        text_color = text_color & 0xFFFFFF00 | 0x60
    end

    local pointer_color = text_color & 0xFFFFFF00 | 0xFF

    local normalized, range, min_v, max_v = UTILS.widgetSliderNormalized(widget)

    -- Largest circle that fits inside the button with edge padding; center is the widget midpoint.
    local edge_pad = 3
    local max_r = math.min((render_width - 2 * edge_pad) / 2, (height - 2 * edge_pad) / 2)
    local radius = math.max(6, max_r)
    local cx_rel = rel_x + render_width / 2
    local cy_rel = rel_y + height / 2

    local cx, cy = coords:relativeToDrawList(cx_rel, cy_rel)

    reaper.ImGui_DrawList_AddCircleFilled(draw_list, cx, cy, radius, track_bg, 24)
    reaper.ImGui_DrawList_AddCircle(draw_list, cx, cy, radius, track_bg & 0xFFFFFF00 | 0x55, 0, 1.0)

    -- Base geometry matches the slider-era knob; +90° so the sweep reads correctly on the toolbar.
    local a0 = math.rad(135) + math.rad(90)
    local span = math.rad(270)
    local arc_r = radius - 2
    local dim_arc = track_bg & 0xFFFFFF00 | 0x35
    local N = 28
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

    local pointer_a = a0 + normalized * span
    local pr = radius * 0.72
    local px = cx + math.sin(pointer_a) * pr
    local py = cy - math.cos(pointer_a) * pr
    reaper.ImGui_DrawList_AddLine(draw_list, cx, cy, px, py, pointer_color, 2.0)
    reaper.ImGui_DrawList_AddCircleFilled(draw_list, px, py, 3.0, pointer_color, 12)

    WIDGET_DRAW.drawSliderWidgetValueAndLabel(ctx, coords, draw_list, widget, rel_x, rel_y, render_width, text_color)

    if not preview_mode then
        local is_active = reaper.ImGui_IsItemActive(ctx)
        local pixels_full = widget.knob_vertical_pixels or 100

        if is_active and widget.setValue and not is_disabled then
            local _, mouse_y = reaper.ImGui_GetMousePos(ctx)
            local key_mods = reaper.ImGui_GetKeyMods(ctx)
            local is_shift_down = (key_mods & reaper.ImGui_Mod_Shift()) ~= 0
            local is_cmd_down = (key_mods & reaper.ImGui_Mod_Ctrl()) ~= 0

            if not widget.last_slider_value then
                widget.last_slider_value = widget.value
                widget.knob_drag_start_y = mouse_y
            end

            local delta_y = widget.knob_drag_start_y - mouse_y
            local fine = widget.fine_scale or 0.1
            local delta_normalized = delta_y / pixels_full
            if is_shift_down then
                delta_normalized = delta_normalized * fine
            end
            local new_value = (widget.last_slider_value or 0) + delta_normalized * range

            new_value = math.max(min_v, math.min(max_v, new_value))

            if is_cmd_down and widget.snap_increment then
                new_value = math.floor(new_value / widget.snap_increment + 0.5) * widget.snap_increment
                new_value = math.max(min_v, math.min(max_v, new_value))
            end

            if math.abs(new_value - (widget.value or 0)) > 0.0001 then
                widget.value = new_value
                pcall(widget.setValue, new_value)
            end
        else
            if widget.last_slider_value then
                widget.last_slider_value = nil
                widget.knob_drag_start_y = nil
            end
        end

        if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseDoubleClicked(ctx, 0) and not is_disabled then
            if widget.default_value ~= nil then
                widget.value = widget.default_value
                pcall(widget.setValue, widget.default_value)
            end
        end
    end
end
