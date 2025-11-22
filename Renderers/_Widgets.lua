-- Renderers/_Widgets.lua

local WidgetRenderer = {}
WidgetRenderer.__index = WidgetRenderer

function WidgetRenderer.new()
    local self = setmetatable({}, WidgetRenderer)
    return self
end

local function renderDisplayWidget(ctx, widget, rel_x, rel_y, render_width, coords, draw_list, text_color)
    local height = CONFIG.SIZES.HEIGHT

    -- Check for custom rendering first
    if widget.renderCustom then
        widget.renderCustom(ctx, widget, rel_x, rel_y, render_width, coords, draw_list, text_color)
        return
    end

    local text = string.format(widget.format or "%.2f", widget.value or 0)

    local text_width = reaper.ImGui_CalcTextSize(ctx, text)
    local text_rel_x = rel_x + (render_width - text_width) / 2
    local text_rel_y = rel_y + (height - reaper.ImGui_GetTextLineHeight(ctx)) / 2
    
    local text_x, text_y = coords:relativeToDrawList(text_rel_x, text_rel_y)
    
    reaper.ImGui_DrawList_AddText(draw_list, text_x, text_y, text_color, text)

    if widget.label and widget.label ~= "" then
        local label_color = COLOR_UTILS.toImGuiColor(CONFIG.COLORS.GROUP.LABEL)
        local label_width = reaper.ImGui_CalcTextSize(ctx, widget.label)
        local label_rel_x = rel_x + (render_width - label_width) / 2
        local label_rel_y = rel_y + 4
        
        local label_x, label_y = coords:relativeToDrawList(label_rel_x, label_rel_y)
        reaper.ImGui_DrawList_AddText(draw_list, label_x, label_y, label_color, widget.label)
    end
end

local function renderSliderWidget(ctx, widget, rel_x, rel_y, render_width, coords, draw_list, text_color)
    local height = CONFIG.SIZES.HEIGHT

    -- Check if widget is disabled
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
    
    -- Grey out colors if disabled
    if is_disabled then
        slider_bg = 0x1A1A1AFF
        slider_fill = 0x444444FF
        text_color = text_color & 0xFFFFFF00 | 0x60  -- Make text more transparent
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

    local text = string.format(widget.format or "%.2f", widget.value or 0)
    local text_color_half = text_color & 0xFFFFFF00 | 0x80
    
    local text_x, text_y = coords:relativeToDrawList(rel_x + 4, rel_y + 4)
    reaper.ImGui_DrawList_AddText(draw_list, text_x, text_y, text_color_half, text)

    if widget.label and widget.label ~= "" then
        local label_width = reaper.ImGui_CalcTextSize(ctx, widget.label)
        local label_x, label_y = coords:relativeToDrawList(rel_x + render_width - label_width - 4, rel_y + 4)
        reaper.ImGui_DrawList_AddText(draw_list, label_x, label_y, text_color_half, widget.label)
    end

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

local function renderDropdownWidget(ctx, widget, rel_x, rel_y, render_width, coords, draw_list, text_color)
    local height = CONFIG.SIZES.HEIGHT

    local display_text = widget.selected_text or widget.placeholder or "Select..."
    
    local text_rel_x = rel_x + 8
    local text_rel_y = rel_y + (height - reaper.ImGui_GetTextLineHeight(ctx)) / 2
    
    local text_x, text_y = coords:relativeToDrawList(text_rel_x, text_rel_y)
    
    reaper.ImGui_DrawList_AddText(draw_list, text_x, text_y, text_color, display_text)

    local arrow_size = 8
    local arrow_rel_x = rel_x + render_width - arrow_size - 8
    local arrow_rel_y = rel_y + height / 2
    
    local arrow_x, arrow_y = coords:relativeToDrawList(arrow_rel_x, arrow_rel_y)
    
    DRAWING.triangle(draw_list, arrow_x, arrow_y, arrow_size, arrow_size, text_color, DRAWING.ANGLE_DOWN)

    if widget.label and widget.label ~= "" then
        local label_color = COLOR_UTILS.toImGuiColor(CONFIG.COLORS.GROUP.LABEL)
        local label_rel_x = rel_x + 4
        local label_rel_y = rel_y + 4
        
        local label_x, label_y = coords:relativeToDrawList(label_rel_x, label_rel_y)
        reaper.ImGui_DrawList_AddText(draw_list, label_x, label_y, label_color, widget.label)
    end
end

local function updateWidgetValue(widget)
    local current_time = _G.FRAME_TIME or reaper.time_precise()
    local should_update = (current_time - (widget.last_update_time or 0) >= (widget.update_interval or 0.5))

    if should_update and widget.getValue then
        local success, value = pcall(widget.getValue, widget)
        if success then
            widget.value = value
        end
        widget.last_update_time = current_time
    end
end

function WidgetRenderer:renderWidget(ctx, button, rel_x, rel_y, coords, draw_list, layout, clicked, is_hovered, is_clicked)
    if not button.widget then
        return false
    end

    local widget = button.widget

    updateWidgetValue(widget)

    local render_width = layout and layout.width or widget.width

    -- Get text color from the parent button's color settings
    local state_key = C.Interactions:determineStateKey(button)
    local mouse_key = C.Interactions:determineMouseKey(is_hovered, is_clicked)
    local _, _, _, text_color = COLOR_UTILS.getButtonColors(button, state_key, mouse_key)

    -- Handle hover callbacks
    if is_hovered and widget.onHover then
        pcall(widget.onHover, widget)
    elseif not is_hovered and widget.is_hovering then
        -- Reset hover state when not hovering
        widget.is_hovering = false
    end

    -- Handle click callbacks
    if clicked and widget.onClick then
        pcall(widget.onClick, widget)
    end

    -- Handle right-click callbacks
    if reaper.ImGui_IsMouseClicked(ctx, 1) and is_hovered and widget.onRightClick then
        pcall(widget.onRightClick, widget)
    end

    if widget.type == "display" then
        renderDisplayWidget(ctx, widget, rel_x, rel_y, render_width, coords, draw_list, text_color)
        return true, render_width
        
    elseif widget.type == "slider" then
        renderSliderWidget(ctx, widget, rel_x, rel_y, render_width, coords, draw_list, text_color)
        return true, render_width
        
    elseif widget.type == "dropdown" then
        if clicked then
            local temp_button = {
                instance_id = "widget_dropdown_" .. tostring(widget),
                dropdown_menu = widget.dropdown_menu or {},
                display_text = widget.label or "Dropdown Widget",
                widget_ref = widget,
                dynamic_items = widget.dropdown_menu
            }
            
            local mouse_x, mouse_y = reaper.ImGui_GetMousePos(ctx)
            C.Interactions:showDropdownMenu(ctx, temp_button, {x = mouse_x, y = mouse_y})
        end
        
        renderDropdownWidget(ctx, widget, rel_x, rel_y, render_width, coords, draw_list, text_color)
        return true, render_width
    end

    return false
end

return WidgetRenderer.new()