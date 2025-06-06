-- Renderers/_Widgets.lua

local WidgetRenderer = {}
WidgetRenderer.__index = WidgetRenderer

function WidgetRenderer.new()
    local self = setmetatable({}, WidgetRenderer)

    return self
end

local function renderDisplayWidget(ctx, widget, x1, y1, render_width, window_pos, draw_list, text_color)
    local height = CONFIG.SIZES.HEIGHT

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
        local label_color = COLOR_UTILS.toImGuiColor(CONFIG.COLORS.GROUP.LABEL)
        local label_width = reaper.ImGui_CalcTextSize(ctx, widget.label)
        local label_x_base = x1 + (render_width - label_width) / 2
        local label_y_base = y1 + 4
        
        local label_x, label_y = UTILS.applyScrollOffset(ctx, label_x_base, label_y_base)
        reaper.ImGui_DrawList_AddText(draw_list, label_x, label_y, label_color, widget.label)
    end
end

local function renderSliderWidget(ctx, widget, x1, y1, x2, render_width, window_pos, draw_list, text_color)
    local height = CONFIG.SIZES.HEIGHT

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
        
        -- Get key modifiers
        local key_mods = reaper.ImGui_GetKeyMods(ctx)
        local is_shift_down = (key_mods & reaper.ImGui_Mod_Shift()) ~= 0
        local is_cmd_down = (key_mods & reaper.ImGui_Mod_Ctrl()) ~= 0
        
        -- Apply scroll offset for interaction calculations
        local track_x1_with_scroll = track_x1_base - scroll_x
        local track_x2_with_scroll = track_x2_base - scroll_x
        
        -- Store initial value on first active frame
        if not widget.last_slider_value then
            widget.last_slider_value = widget.value
            widget.slider_drag_start_x = mouse_x
        end
        
        local track_width = track_x2_with_scroll - track_x1_with_scroll
        local new_normalized
        
        if is_shift_down then
            -- Fine control - reduce sensitivity by scale factor when shift is pressed
            local fine_scale = widget.fine_scale or 0.1
            local delta_x = (mouse_x - widget.slider_drag_start_x) * fine_scale
            new_normalized = ((widget.last_slider_value - (widget.min_value or 0)) / range) + (delta_x / track_width)
        else
            -- Normal control - direct mapping from mouse position
            new_normalized = (mouse_x - track_x1_with_scroll) / track_width
        end
        
        new_normalized = math.max(0, math.min(1, new_normalized))
        
        local new_value = (widget.min_value or 0) + new_normalized * range
        
        -- Apply snapping if cmd/ctrl is pressed and snap_increment is defined
        if is_cmd_down and widget.snap_increment then
            new_value = math.floor(new_value / widget.snap_increment + 0.5) * widget.snap_increment
        end
        
        -- Only update if value changed
        if math.abs(new_value - (widget.value or 0)) > 0.0001 then
            widget.value = new_value
            -- Call setValue
            pcall(widget.setValue, new_value)
        end
    else
        -- Reset tracking variables when not active
        if widget.last_slider_value then
            widget.last_slider_value = nil
            widget.slider_drag_start_x = nil
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
end

local function renderDropdownWidget(ctx, widget, x1, y1, x2, render_width, window_pos, draw_list, text_color)
    local height = CONFIG.SIZES.HEIGHT

    -- Display current selection or placeholder as text
    local display_text = widget.selected_text or widget.placeholder or "Select..."
    
    -- Format the text with scroll offset
    local text_x_base = x1 + 8
    local text_y_base = y1 + (height - reaper.ImGui_GetTextLineHeight(ctx)) / 2
    
    local text_x, text_y = UTILS.applyScrollOffset(ctx, text_x_base, text_y_base)
    reaper.ImGui_DrawList_AddText(draw_list, text_x, text_y, text_color, display_text)

    -- Draw dropdown arrow using existing triangle function
    local arrow_size = 8
    local arrow_x_base = x2 - arrow_size - 8
    local arrow_y_base = y1 + height / 2
    
    local arrow_x, arrow_y = UTILS.applyScrollOffset(ctx, arrow_x_base, arrow_y_base)
    
    DRAWING.triangle(
        draw_list,
        arrow_x,
        arrow_y,
        arrow_size,
        arrow_size,
        text_color,
        DRAWING.ANGLE_DOWN
    )

    -- Draw label using config colors
    if widget.label and widget.label ~= "" then
        local label_color = COLOR_UTILS.toImGuiColor(CONFIG.COLORS.GROUP.LABEL)
        local label_x_base = x1 + 4
        local label_y_base = y1 + 4
        
        local label_x, label_y = UTILS.applyScrollOffset(ctx, label_x_base, label_y_base)
        reaper.ImGui_DrawList_AddText(draw_list, label_x, label_y, label_color, widget.label)
    end

    -- Handle dropdown interaction (left-click only, right-click handled by main renderer)
    if reaper.ImGui_IsItemClicked(ctx, 0) then
        -- Create a temporary button and use existing dropdown system
        local temp_button = {
            instance_id = "widget_dropdown_" .. tostring(widget),
            dropdown_menu = widget.dropdown_menu or {},
            display_text = widget.label or "Dropdown Widget",
            widget_ref = widget,
            dynamic_items = widget.dropdown_menu -- Pass items as dynamic_items
        }
        
        -- Get mouse position for dropdown placement
        local mouse_x, mouse_y = reaper.ImGui_GetMousePos(ctx)
        
        -- Use existing showDropdownMenu from Interactions
        C.Interactions:showDropdownMenu(ctx, temp_button, {x = mouse_x, y = mouse_y})
    end
end

local function updateWidgetValue(widget)
    local current_time = reaper.time_precise()
    local should_update = (current_time - (widget.last_update_time or 0) >= (widget.update_interval or 0.5))

    if should_update and widget.getValue then
        local success, value = pcall(widget.getValue, widget)
        if success then
            widget.value = value
        end
        widget.last_update_time = current_time
    end
end

function WidgetRenderer:renderWidget(ctx, button, pos_x, pos_y, window_pos, draw_list, layout)
    if not button.widget then
        return false -- Not handled
    end

    local widget = button.widget

    -- Update widget value
    updateWidgetValue(widget)

    -- Set up invisible interaction area for all widgets
    local render_width = layout and layout.width or widget.width
    local clicked, is_hovered, is_clicked = C.Interactions:setupInteractionArea(
        ctx, pos_x, pos_y, render_width, layout.height, "widget_" .. button.instance_id
    )

    -- Handle right-click for all widgets (opens button settings menu)
    if is_hovered and reaper.ImGui_IsMouseClicked(ctx, 1) then
        -- Check for alt modifier
        local key_mods = reaper.ImGui_GetKeyMods(ctx)
        local is_alt_down = (key_mods & reaper.ImGui_Mod_Alt()) ~= 0
        
        -- Always open settings on right-click, or alt+right-click
        C.Interactions:showButtonSettings(button, button.parent_group)
        reaper.ImGui_OpenPopup(ctx, "button_settings_menu_" .. button.instance_id)
    end

    -- Get text color
    local text_color = COLOR_UTILS.toImGuiColor(CONFIG.COLORS.NORMAL.TEXT.NORMAL)
    if is_hovered then
        text_color = COLOR_UTILS.toImGuiColor(CONFIG.COLORS.NORMAL.TEXT.HOVER)
    end

    local x1 = window_pos.x + pos_x
    local y1 = window_pos.y + pos_y
    local x2 = x1 + render_width

    -- Render based on type
    if widget.type == "display" then
        renderDisplayWidget(ctx, widget, x1, y1, render_width, window_pos, draw_list, text_color)
        return true, render_width
        
    elseif widget.type == "slider" then
        renderSliderWidget(ctx, widget, x1, y1, x2, render_width, window_pos, draw_list, text_color)
        return true, render_width
        
    elseif widget.type == "dropdown" then
        renderDropdownWidget(ctx, widget, x1, y1, x2, render_width, window_pos, draw_list, text_color)
        return true, render_width
    end

    return false -- Not handled
end

return WidgetRenderer.new()