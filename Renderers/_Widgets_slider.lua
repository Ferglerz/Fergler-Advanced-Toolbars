-- Renderers/_Widgets_slider.lua
-- Slider widget draw + drag interaction; required by Renderers/_Widgets.lua

local SLIDER_QC = require("Renderers._Widgets_slider_quick_chips")
local WIDGET_DRAW = require("Renderers._Widgets_common_draw")

return function(ctx, widget, rel_x, rel_y, render_width, coords, draw_list, text_color, preview_mode, layout, bg_color)
    local height = CONFIG.SIZES.HEIGHT

    local is_disabled = widget.is_disabled and widget.is_disabled() or false

    local sx, sy, sw = rel_x, rel_y, render_width
    local qc_layout = nil
    if widget.slider_quick_chips and layout and SLIDER_QC.effective_show(widget, layout) then
        qc_layout = SLIDER_QC.compute_layout(ctx, widget, rel_x, rel_y, render_width, layout)
        if qc_layout then
            sx = qc_layout.slider_rel_x
            sy = qc_layout.slider_rel_y
            sw = qc_layout.slider_render_width
        end
    end

    local mx_qc, my_qc = coords:getRelativeMouse()
    local over_chips = qc_layout and SLIDER_QC.mouse_over_chips(coords, qc_layout.chips)

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

    if is_disabled then
        slider_bg = 0x1A1A1AFF
        slider_fill = 0x444444FF
        text_color = text_color & 0xFFFFFF00 | 0x60
    end

    local slider_handle = text_color & 0xFFFFFF00 | 0xFF

    local track_height = 8
    local track_rel_y = sy + (height - track_height) / 2 + 5
    local track_rel_x1 = sx + 10
    local track_rel_x2 = sx + sw - 10

    local track_x1, track_y = coords:relativeToDrawList(track_rel_x1, track_rel_y)
    local track_x2, _ = coords:relativeToDrawList(track_rel_x2, track_rel_y)

    reaper.ImGui_DrawList_AddRectFilled(
        draw_list, track_x1, track_y, track_x2, track_y + track_height,
        slider_bg, track_height / 2
    )

    local normalized, range, min_v = UTILS.widgetSliderNormalized(widget)

    local fill_width = (track_x2 - track_x1) * normalized
    reaper.ImGui_DrawList_AddRectFilled(
        draw_list, track_x1, track_y, track_x1 + fill_width, track_y + track_height,
        slider_fill, track_height / 2
    )

    local handle_radius = track_height - 1
    local handle_x = track_x1 + (track_x2 - track_x1) * normalized
    local handle_y = track_y + track_height / 2

    reaper.ImGui_DrawList_AddCircleFilled(draw_list, handle_x, handle_y, handle_radius, slider_handle, 20)

    WIDGET_DRAW.drawSliderWidgetValueAndLabel(ctx, coords, draw_list, widget, sx, sy, sw, text_color)

    if qc_layout and qc_layout.chips and #qc_layout.chips > 0 then
        local chip_bg = bg_color or 0x2A2A2AFF
        SLIDER_QC.draw_chips(ctx, widget, coords, draw_list, text_color, chip_bg, qc_layout, mx_qc, my_qc)
    end

    if not preview_mode then
        local is_active = reaper.ImGui_IsItemActive(ctx)

        if is_active and widget.setValue and not is_disabled and not over_chips then
            local mouse_x, mouse_y = coords:getRelativeMouse()
            local key_mods = reaper.ImGui_GetKeyMods(ctx)
            local is_shift_down = (key_mods & reaper.ImGui_Mod_Shift()) ~= 0
            local is_cmd_down = (key_mods & reaper.ImGui_Mod_Ctrl()) ~= 0

            if not widget.last_slider_value or widget.last_shift_state ~= is_shift_down then
                widget.last_slider_value = widget.value
                widget.slider_drag_start_x = mouse_x
                widget.last_shift_state = is_shift_down
            end

            local track_width = track_rel_x2 - track_rel_x1
            local new_normalized

            if is_shift_down then
                local fine_scale = widget.fine_scale or 0.1
                local delta_x = (mouse_x - widget.slider_drag_start_x) * fine_scale
                new_normalized = ((widget.last_slider_value - min_v) / range) + (delta_x / track_width)
            else
                new_normalized = (mouse_x - track_rel_x1) / track_width
            end

            new_normalized = math.max(0, math.min(1, new_normalized))
            local new_value = min_v + new_normalized * range

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
                end
            end

            if math.abs(new_value - (widget.value or 0)) > 0.0001 then
                widget.value = new_value
                pcall(widget.setValue, new_value)
            end
        else
            if widget.last_slider_value then
                widget.last_slider_value = nil
                widget.slider_drag_start_x = nil
                widget.last_shift_state = nil
            end
        end

        if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseDoubleClicked(ctx, 0) and not is_disabled and not over_chips then
            if widget.default_value ~= nil then
                widget.value = widget.default_value
                pcall(widget.setValue, widget.default_value)
            end
        end
    end
end
