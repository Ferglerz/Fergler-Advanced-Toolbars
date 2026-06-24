-- Renderers/_Widgets_simple_knob.lua
-- Circular knob with a background "flag" extending to one side.
-- Interaction: vertical drag (up = increase). Shift = fine (widget.fine_scale). Cmd = snap.

local WIDGET_DRAW = require("Renderers._Widgets_common_draw")
return function(ctx, widget, rel_x, rel_y, render_width, coords, draw_list, text_color, bg_color, preview_mode)
    local height = CONFIG.SIZES.HEIGHT
    local is_disabled = widget.is_disabled and widget.is_disabled() or false

    local track_bg = 0x222222FF
    local arc_value_color = bg_color or 0x888888FF
    arc_value_color = arc_value_color & 0xFFFFFF00 | 0xFF

    if is_disabled then
        track_bg = 0x1A1A1AFF
        arc_value_color = arc_value_color & 0xFFFFFF00 | 0x55
        text_color = text_color & 0xFFFFFF00 | 0x60
    end

    local pointer_color = text_color & 0xFFFFFF00 | 0xFF

    local normalized, range, min_v, max_v = UTILS.widgetSliderNormalized(widget)

    local is_merged = false
    if not preview_mode and widget._host_button then
        is_merged = CONFIG.UI.USE_GROUPING and not widget._host_button.is_alone
    end
    if preview_mode then
        is_merged = true
    end

    local pad_y = 4
    local edge_pad = is_merged and pad_y or 0
    local radius = math.max(6, (height - 2 * edge_pad) / 2)
    local cx_rel, cy_rel
    
    local direction = widget.knob_bg_direction or "right"
    -- If direction is "left", knob is on the left.
    if direction == "left" then
        cx_rel = rel_x + edge_pad + radius
    else
        cx_rel = rel_x + render_width - edge_pad - radius
    end
    cy_rel = rel_y + height / 2

    local bg_x1, bg_x2
    local text_area_x, text_area_w
    if direction == "left" then
        bg_x1 = cx_rel
        bg_x2 = rel_x + render_width
        text_area_x = cx_rel + radius
        text_area_w = render_width - (cx_rel + radius - rel_x)
    else
        bg_x1 = rel_x
        bg_x2 = cx_rel
        text_area_x = rel_x
        text_area_w = cx_rel - radius - rel_x
    end

    local cx, cy = coords:relativeToDrawList(cx_rel, cy_rel)
    local rx1, ry1 = coords:relativeToDrawList(bg_x1, rel_y + pad_y)
    local rx2, ry2 = coords:relativeToDrawList(bg_x2, rel_y + height - pad_y)
    
    -- Draw background flag
    if is_merged then
        local flag_bg = track_bg & 0xFFFFFF00 | 0x50
        local flags = direction == "left" and reaper.ImGui_DrawFlags_RoundCornersRight() or reaper.ImGui_DrawFlags_RoundCornersLeft()
        reaper.ImGui_DrawList_AddRectFilled(draw_list, rx1, ry1, rx2, ry2, flag_bg, pad_y, flags)
    end

    -- Draw knob body
    reaper.ImGui_DrawList_AddCircleFilled(draw_list, cx, cy, radius, track_bg, 24)
    reaper.ImGui_DrawList_AddCircle(draw_list, cx, cy, radius, track_bg & 0xFFFFFF00 | 0x55, 0, 1.0)

    -- Lit arc
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

    -- Pointer
    local pointer_a = a0 + normalized * span
    local pr = radius * 0.72
    local px = cx + math.sin(pointer_a) * pr
    local py = cy - math.cos(pointer_a) * pr
    reaper.ImGui_DrawList_AddLine(draw_list, cx, cy, px, py, pointer_color, 2.0)
    reaper.ImGui_DrawList_AddCircleFilled(draw_list, px, py, 3.0, pointer_color, 12)

    -- Text
    WIDGET_DRAW.drawSliderWidgetValueAndLabel(ctx, coords, draw_list, widget, text_area_x, rel_y, text_area_w, text_color)

    if not preview_mode then
        local is_active = reaper.ImGui_IsItemActive(ctx)
        local pixels_full = widget.knob_vertical_pixels or 100

        if is_active and widget.setValue and not is_disabled then
            local _, mouse_y = coords:getRelativeMouse()
            local key_mods = reaper.ImGui_GetKeyMods(ctx)
            local is_shift_down = (key_mods & reaper.ImGui_Mod_Shift()) ~= 0
            local is_cmd_down = (key_mods & reaper.ImGui_Mod_Ctrl()) ~= 0

            if not widget.last_slider_value or widget.last_shift_state ~= is_shift_down then
                widget.last_slider_value = widget.value
                widget.knob_drag_start_y = mouse_y
                widget.last_shift_state = is_shift_down
            end

            local delta_y = widget.knob_drag_start_y - mouse_y
            local fine = widget.fine_scale or 0.1
            local delta_normalized = delta_y / pixels_full
            if is_shift_down then
                delta_normalized = delta_normalized * fine
            end
            local new_value = (widget.last_slider_value or 0) + delta_normalized * range

            new_value = math.max(min_v, math.min(max_v, new_value))

            local should_snap = not widget.default_snap_disabled
            if is_cmd_down then
                should_snap = not should_snap
            end
            if is_shift_down then
                should_snap = false
            end

            if should_snap then
                if widget.snap_points then
                    local best = new_value
                    local dist = math.huge
                    for _, pt in ipairs(widget.snap_points) do
                        local d = math.abs(new_value - pt)
                        if d < dist then
                            dist = d
                            best = pt
                        end
                    end
                    new_value = best
                elseif widget.snap_increment then
                    new_value = math.floor(new_value / widget.snap_increment + 0.5) * widget.snap_increment
                    new_value = math.max(min_v, math.min(max_v, new_value))
                end
            end

            if math.abs(new_value - (widget.value or 0)) > 0.0001 then
                widget.value = new_value
                pcall(widget.setValue, new_value)
            end
        else
            if widget.last_slider_value then
                widget.last_slider_value = nil
                widget.knob_drag_start_y = nil
                widget.last_shift_state = nil
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
