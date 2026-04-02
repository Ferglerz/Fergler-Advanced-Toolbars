-- Renderers/_Widgets_slider.lua
-- Slider widget draw + drag interaction; loaded by Renderers/_Widgets.lua

return function(ctx, widget, rel_x, rel_y, render_width, coords, draw_list, text_color, preview_mode)
    local height = CONFIG.SIZES.HEIGHT

    local is_disabled = widget.is_disabled and widget.is_disabled() or false

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
    local track_rel_y = rel_y + (height - track_height) / 2 + 5
    local track_rel_x1 = rel_x + 10
    local track_rel_x2 = rel_x + render_width - 10

    local track_x1, track_y = coords:relativeToDrawList(track_rel_x1, track_rel_y)
    local track_x2, _ = coords:relativeToDrawList(track_rel_x2, track_rel_y)

    reaper.ImGui_DrawList_AddRectFilled(
        draw_list, track_x1, track_y, track_x2, track_y + track_height,
        slider_bg, track_height / 2
    )

    local range = (widget.max_value or 1) - (widget.min_value or 0)
    local normalized = range ~= 0 and ((widget.value or 0) - (widget.min_value or 0)) / range or 0
    normalized = math.max(0, math.min(1, normalized))

    local fill_width = (track_x2 - track_x1) * normalized
    reaper.ImGui_DrawList_AddRectFilled(
        draw_list, track_x1, track_y, track_x1 + fill_width, track_y + track_height,
        slider_fill, track_height / 2
    )

    local handle_radius = track_height - 1
    local handle_x = track_x1 + (track_x2 - track_x1) * normalized
    local handle_y = track_y + track_height / 2

    reaper.ImGui_DrawList_AddCircleFilled(draw_list, handle_x, handle_y, handle_radius, slider_handle, 20)

    local slider_value = widget.value
    local slider_fmt = type(slider_value) == "number" and "%.2f" or "%s"
    local text = UTILS.safeFormat(widget.format or slider_fmt, slider_value or 0)
    local text_color_half = text_color & 0xFFFFFF00 | 0x80

    local text_x, text_y = coords:relativeToDrawList(rel_x + 4, rel_y + 4)
    reaper.ImGui_DrawList_AddText(draw_list, text_x, text_y, text_color_half, text)

    if widget.label and widget.label ~= "" then
        local label_width = reaper.ImGui_CalcTextSize(ctx, widget.label)
        local label_x, label_y = coords:relativeToDrawList(rel_x + render_width - label_width - 4, rel_y + 1)
        reaper.ImGui_DrawList_AddText(draw_list, label_x, label_y, text_color_half, widget.label)
    end

    if not preview_mode then
        local is_active = reaper.ImGui_IsItemActive(ctx)

        if is_active and widget.setValue and not is_disabled then
            local mouse_x, mouse_y = reaper.ImGui_GetMousePos(ctx)
            local key_mods = reaper.ImGui_GetKeyMods(ctx)
            local is_shift_down = (key_mods & reaper.ImGui_Mod_Shift()) ~= 0
            local is_cmd_down = (key_mods & reaper.ImGui_Mod_Ctrl()) ~= 0

            if not widget.last_slider_value then
                widget.last_slider_value = widget.value
                widget.slider_drag_start_x = mouse_x
            end

            local track_width = track_rel_x2 - track_rel_x1
            local new_normalized

            if is_shift_down then
                local fine_scale = widget.fine_scale or 0.1
                local delta_x = (mouse_x - widget.slider_drag_start_x) * fine_scale
                new_normalized = ((widget.last_slider_value - (widget.min_value or 0)) / range) + (delta_x / track_width)
            else
                local screen_track_x1, _ = coords:toScreen(track_rel_x1, 0)
                new_normalized = (mouse_x - screen_track_x1) / track_width
            end

            new_normalized = math.max(0, math.min(1, new_normalized))
            local new_value = (widget.min_value or 0) + new_normalized * range

            if is_cmd_down and widget.snap_increment then
                new_value = math.floor(new_value / widget.snap_increment + 0.5) * widget.snap_increment
            end

            if math.abs(new_value - (widget.value or 0)) > 0.0001 then
                widget.value = new_value
                pcall(widget.setValue, new_value)
            end
        else
            if widget.last_slider_value then
                widget.last_slider_value = nil
                widget.slider_drag_start_x = nil
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
