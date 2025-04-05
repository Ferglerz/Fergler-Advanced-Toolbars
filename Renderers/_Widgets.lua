-- Renderers/_Widgets.lua

local WidgetRenderer = {}
WidgetRenderer.__index = WidgetRenderer

function WidgetRenderer.new()
    local self = setmetatable({}, WidgetRenderer)

    return self
end

function WidgetRenderer:renderWidget(ctx, button, pos_x, pos_y, width, window_pos, draw_list)
    if not button.widget then
        return false -- Not handled
    end

    local widget = button.widget

    -- Update widget value
    local current_time = reaper.time_precise()
    local should_update = (current_time - (widget.last_update_time or 0) >= (widget.update_interval or 0.5))

    if should_update and widget.getValue then
        local success, value = pcall(widget.getValue)
        if success then
            widget.value = value
        end
        widget.last_update_time = current_time
    end

    -- Get text color
    local text_color = COLOR_UTILS.hexToImGuiColor(CONFIG.COLORS.NORMAL.TEXT.NORMAL)
    if button.is_hovered then
        text_color = COLOR_UTILS.hexToImGuiColor(CONFIG.COLORS.NORMAL.TEXT.HOVER)
    end

    -- Render based on type
    if widget.type == "display" then
        local height = CONFIG.SIZES.HEIGHT
        local x1 = window_pos.x + pos_x
        local y1 = window_pos.y + pos_y
        local render_width = width

        -- Format the value
        local text = string.format(widget.format or "%.2f", widget.value or 0)

        -- Draw the value text with scroll offset
        local text_width = reaper.ImGui_CalcTextSize(ctx, text)
        local text_x_base = x1 + (render_width - text_width) / 2
        local text_y_base = y1 + (height - reaper.ImGui_GetTextLineHeight(ctx)) / 2
        
        local text_x, text_y = UTILS.applyScrollOffset(ctx, text_x_base, text_y_base)
        reaper.ImGui_DrawList_AddText(draw_list, text_x, text_y, text_color, text)

        -- Draw label if exists with scroll offset
        if widget.label and widget.label ~= "" then
            local label_color = COLOR_UTILS.hexToImGuiColor(CONFIG.COLORS.GROUP.LABEL)
            local label_width = reaper.ImGui_CalcTextSize(ctx, widget.label)
            local label_x_base = x1 + (render_width - label_width) / 2
            local label_y_base = y1 + 4
            
            local label_x, label_y = UTILS.applyScrollOffset(ctx, label_x_base, label_y_base)
            reaper.ImGui_DrawList_AddText(draw_list, label_x, label_y, label_color, widget.label)
        end

        return true, render_width
    elseif widget.type == "slider" then
        local height = CONFIG.SIZES.HEIGHT
        local x1 = window_pos.x + pos_x
        local y1 = window_pos.y + pos_y
        local render_width = width
        local x2 = x1 + render_width

        -- Slider track
        local slider_bg = 0x222222FF -- Slider background

        local slider_fill
        if type(widget.col_primary) == "function" then
            local nativeColor = widget.col_primary()
            if nativeColor == nil then
                slider_fill = 0x888888FF
            else
                slider_fill = COLOR_UTILS.reaperColorToImGui(nativeColor)
            end
        else
            slider_fill = COLOR_UTILS.reaperColorToImGui(widget.col_primary) or 0x888888FF
        end

        local slider_handle = text_color & 0xFFFFFF00 | 0xFF

        -- Calculate track positions with scroll offset
        local track_height = 8
        local track_y_base = y1 + (height - track_height) / 2 + 5 -- Moved down 5 pixels
        local track_x1_base = x1 + 10
        local track_x2_base = x2 - 10
        
        local track_x1, track_y = UTILS.applyScrollOffset(ctx, track_x1_base, track_y_base)
        local track_x2, _ = UTILS.applyScrollOffset(ctx, track_x2_base, track_y_base)

        -- Render track with scroll offset
        reaper.ImGui_DrawList_AddRectFilled(
            draw_list,
            track_x1,
            track_y,
            track_x2,
            track_y + track_height,
            slider_bg,
            track_height / 2
        )

        -- Calculate normalized value
        local range = (widget.max_value or 1) - (widget.min_value or 0)
        local normalized = range ~= 0 and ((widget.value or 0) - (widget.min_value or 0)) / range or 0
        normalized = math.max(0, math.min(1, normalized))

        -- Slider fill with scroll offset
        local fill_width = (track_x2 - track_x1) * normalized
        reaper.ImGui_DrawList_AddRectFilled(
            draw_list,
            track_x1,
            track_y,
            track_x1 + fill_width,
            track_y + track_height,
            slider_fill,
            track_height / 2
        )

        -- Slider handle with scroll offset
        local handle_radius = track_height - 1
        local handle_x_base = track_x1_base + (track_x2_base - track_x1_base) * normalized
        local handle_y_base = track_y_base + track_height / 2
        
        local handle_x, handle_y = UTILS.applyScrollOffset(ctx, handle_x_base, handle_y_base)
        reaper.ImGui_DrawList_AddCircleFilled(draw_list, handle_x, handle_y, handle_radius, slider_handle, 20)

        -- Format value and draw at top left with scroll offset
        local text = string.format(widget.format or "%.2f", widget.value or 0)
        local text_color_half = text_color & 0xFFFFFF00 | 0x80
        
        local text_x, text_y = UTILS.applyScrollOffset(ctx, x1 + 4, y1 + 4)
        reaper.ImGui_DrawList_AddText(draw_list, text_x, text_y, text_color_half, text)

        -- Draw label at top right with scroll offset
        if widget.label and widget.label ~= "" then
            local label_width = reaper.ImGui_CalcTextSize(ctx, widget.label)
            local label_x, label_y = UTILS.applyScrollOffset(ctx, x2 - label_width - 4, y1 + 4)
            reaper.ImGui_DrawList_AddText(draw_list, label_x, label_y, text_color_half, widget.label)
        end

        -- Handle slider interaction
        local is_active = reaper.ImGui_IsItemActive(ctx)

        if is_active and widget.setValue then
            local mouse_x = reaper.ImGui_GetMousePos(ctx)
            local scroll_x = reaper.ImGui_GetScrollX(ctx)
            
            -- Apply scroll offset for interaction calculations
            local track_x1_with_scroll = track_x1_base - scroll_x
            local track_x2_with_scroll = track_x2_base - scroll_x
            
            local new_normalized = (mouse_x - track_x1_with_scroll) / (track_x2_with_scroll - track_x1_with_scroll)
            new_normalized = math.max(0, math.min(1, new_normalized))

            local new_value = (widget.min_value or 0) + new_normalized * range

            -- Only update if value changed
            if math.abs(new_value - (widget.value or 0)) > 0.0001 then
                widget.value = new_value
                -- Call setValue
                pcall(widget.setValue, new_value)
            end
        end

        if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
            -- Check if widget has a default_value defined
            if widget.default_value ~= nil then
                -- Set to default value
                widget.value = widget.default_value
                -- Call setValue with default value
                pcall(widget.setValue, widget.default_value)
            end
        end

        return true, render_width
    end

    return false -- Not handled
end

return WidgetRenderer.new()
