local ButtonRenderer = {}
ButtonRenderer.__index = ButtonRenderer

function ButtonRenderer.new()
    local self = setmetatable({}, ButtonRenderer)
    self.ctx = nil
    self.cached_shadow_color = nil
    return self
end

-- Calculate rounding flags based on button position and grouping
function ButtonRenderer:getRoundingFlags(button)
    if not CONFIG.UI.USE_GROUPING or button.is_alone then
        return reaper.ImGui_DrawFlags_RoundCornersAll()
    elseif button.is_section_start then
        return reaper.ImGui_DrawFlags_RoundCornersLeft()
    elseif button.is_section_end then
        return reaper.ImGui_DrawFlags_RoundCornersRight()
    end
    return reaper.ImGui_DrawFlags_RoundCornersNone()
end

-- Calculate button coordinates and dimensions
function ButtonRenderer:calculateButtonCoordinates(button, pos_x, pos_y, width, window_pos)
    -- Initialize screen cache if it doesn't exist
    if not button.cache.screen then
        button.cache.screen = {}
    end
    
    local screen = button.cache.screen
    local recalculate =
        not screen.width or 
        screen.window_x ~= window_pos.x or 
        screen.window_y ~= window_pos.y or
        screen.pos_x ~= pos_x or
        screen.pos_y ~= pos_y or
        screen.width ~= width

    if recalculate then
        -- Update cache with new values
        screen.window_x = window_pos.x
        screen.window_y = window_pos.y
        screen.pos_x = pos_x
        screen.pos_y = pos_y
        screen.width = width

        screen.x1 = window_pos.x + pos_x
        screen.y1 = window_pos.y + pos_y
        screen.x2 = screen.x1 + width
        screen.y2 = screen.y1 + CONFIG.SIZES.HEIGHT
    end

    return screen
end

-- Render the button background (fill and border)
function ButtonRenderer:renderBackground(draw_list, button, pos_x, pos_y, width, bg_color, border_color, window_pos)
    if not window_pos then
        return
    end

    local flags = self:getRoundingFlags(button)
    local screen_coords = self:calculateButtonCoordinates(button, pos_x, pos_y, width, window_pos)

    local x1, y1, x2, y2 = screen_coords.x1, screen_coords.y1, screen_coords.x2, screen_coords.y2

    -- Apply scroll offset to match widget positioning
    x1, y1 = UTILS.applyScrollOffset(self.ctx, x1, y1)
    x2, y2 = UTILS.applyScrollOffset(self.ctx, x2, y2)

    -- Render button background and border
    reaper.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, bg_color, CONFIG.SIZES.ROUNDING, flags)
    reaper.ImGui_DrawList_AddRect(draw_list, x1, y1, x2, y2, border_color, CONFIG.SIZES.ROUNDING, flags)
end

function ButtonRenderer:renderInsertionControls(ctx, button, pos_x, pos_y, width, window_pos, draw_list, mouse_x, mouse_y)
    -- Check if separator controls are already being rendered (higher priority)
    if self.pending_separator_controls and #self.pending_separator_controls > 0 then
        return false
    end
    
    local triangle_size = CONFIG.SIZES.HEIGHT / 4
    local hover_zone = 25
    
    -- Calculate positions without scroll first
    local left_edge_x_base = window_pos.x + pos_x
    local center_y_base = window_pos.y + pos_y + CONFIG.SIZES.HEIGHT / 2
    
    -- Apply scroll offset for proximity detection
    local left_edge_x, center_y = UTILS.applyScrollOffset(ctx, left_edge_x_base, center_y_base)
    
    -- Check if mouse is to the right of the left edge AND within hover zone
    local mouse_to_right_of_edge = mouse_x >= left_edge_x
    local near_left = math.abs(mouse_x - left_edge_x) <= hover_zone
    
    -- Only show controls if mouse is on positive side (right) of edge AND close enough
    if not (mouse_to_right_of_edge and near_left) then
        return false
    end
    
    -- Rest of the function remains the same...
    local control_x = left_edge_x_base
    local top_triangle_y = window_pos.y + pos_y - triangle_size - 8
    local bottom_triangle_y = window_pos.y + pos_y + CONFIG.SIZES.HEIGHT + triangle_size + 8
    
    -- Check which half of the button the mouse is over vertically
    local mouse_in_top_half = mouse_y < center_y
    local mouse_in_bottom_half = mouse_y >= center_y
    
    -- Only show one triangle based on vertical position
    local show_top = mouse_in_top_half
    local show_bottom = mouse_in_bottom_half
    
    -- Store for later rendering on top
    if not self.pending_insertion_controls then
        self.pending_insertion_controls = {}
    end
    
    table.insert(self.pending_insertion_controls, {
        control_x = control_x,
        top_triangle_y = top_triangle_y,
        bottom_triangle_y = bottom_triangle_y,
        triangle_size = triangle_size,
        mouse_x = mouse_x,
        mouse_y = mouse_y,
        show_top = show_top,
        show_bottom = show_bottom
    })
    
    -- Check for clicks (using scroll-adjusted positions for click detection)
    local clicked_add_button = false
    local clicked_add_separator = false
    
    if reaper.ImGui_IsMouseClicked(ctx, 0) then
        local control_x_scrolled, top_triangle_y_scrolled = UTILS.applyScrollOffset(ctx, control_x, top_triangle_y)
        local _, bottom_triangle_y_scrolled = UTILS.applyScrollOffset(ctx, control_x, bottom_triangle_y)
        
        local click_dist_to_top = math.sqrt((mouse_x - control_x_scrolled)^2 + (mouse_y - top_triangle_y_scrolled)^2)
        local click_dist_to_bottom = math.sqrt((mouse_x - control_x_scrolled)^2 + (mouse_y - bottom_triangle_y_scrolled)^2)
        
        if show_top and click_dist_to_top <= triangle_size + 5 then
            clicked_add_button = true
        elseif show_bottom and click_dist_to_bottom <= triangle_size + 5 then
            clicked_add_separator = true
        end
    end
    
    return clicked_add_button, clicked_add_separator, true
end

function ButtonRenderer:renderPendingControlsOnTop(ctx, draw_list)
    -- Initialize pending render arrays at start of frame
    if not self.pending_insertion_controls then
        self.pending_insertion_controls = {}
    end
    if not self.pending_separator_controls then
        self.pending_separator_controls = {}
    end
    
    -- Render insertion controls on top
    if self.pending_insertion_controls then
        for _, control in ipairs(self.pending_insertion_controls) do
            -- Apply scroll offset
            local scroll_control_x, scroll_top_y = UTILS.applyScrollOffset(ctx, control.control_x, control.top_triangle_y)
            local _, scroll_bottom_y = UTILS.applyScrollOffset(ctx, control.control_x, control.bottom_triangle_y)
            
            -- Colors using config group label color
            local base_color = COLOR_UTILS.toImGuiColor(CONFIG.COLORS.GROUP.LABEL)
            local triangle_bg_color = base_color & 0xFFFFFF7F  -- Make triangles half transparent
            local text_color = base_color
            
            local triangle_width = control.triangle_size * 2
            local triangle_height = control.triangle_size * 3
            
            -- Only render top triangle if it's the closest one
            if control.show_top then
                -- Draw top triangle (pointing DOWN toward button area)
                DRAWING.triangle(
                    draw_list,
                    scroll_control_x,
                    scroll_top_y,
                    triangle_width,
                    triangle_height,
                    triangle_bg_color,
                    DRAWING.ANGLE_DOWN
                )
                
                -- Draw "ADD BUTTON" text to the right
                local text_x = scroll_control_x + triangle_width/2 + 5
                local text_y = scroll_top_y - 6
                reaper.ImGui_DrawList_AddText(draw_list, text_x, text_y, text_color, "ADD BUTTON")
            end
            
            -- Only render bottom triangle if it's the closest one
            if control.show_bottom then
                -- Draw bottom triangle (pointing UP toward button area)
                DRAWING.triangle(
                    draw_list,
                    scroll_control_x,
                    scroll_bottom_y,
                    triangle_width,
                    triangle_height,
                    triangle_bg_color,
                    DRAWING.ANGLE_UP
                )
                
                -- Draw "ADD SEPARATOR" text to the right
                local sep_text_x = scroll_control_x + triangle_width/2 + 5
                local sep_text_y = scroll_bottom_y - 6
                reaper.ImGui_DrawList_AddText(draw_list, sep_text_x, sep_text_y, text_color, "ADD SEPARATOR")
            end
        end
        
        -- Clear the pending list
        self.pending_insertion_controls = {}
    end
    
    -- Render separator delete controls on top
if self.pending_separator_controls then
    for _, control in ipairs(self.pending_separator_controls) do
        -- Apply scroll offset
        local scroll_control_x, scroll_bottom_y = UTILS.applyScrollOffset(ctx, control.control_x, control.bottom_triangle_y)
        
        -- Colors using red for delete
        local base_color = COLOR_UTILS.toImGuiColor("#FF0000FF")
        local triangle_bg_color = base_color & 0xFFFFFF7F  -- Make triangles half transparent red
        local text_color = base_color
        
        local triangle_width = control.triangle_size * 2
        local triangle_height = control.triangle_size * 3
        
        -- Only render bottom triangle (pointing UP toward separator area)
        DRAWING.triangle(
            draw_list,
            scroll_control_x,
            scroll_bottom_y,
            triangle_width,
            triangle_height,
            triangle_bg_color,
            DRAWING.ANGLE_UP
        )
        
        -- Draw "DELETE SEPARATOR" text to the right
        local text_x = scroll_control_x + triangle_width/2 + 5
        local text_y = scroll_bottom_y - 6
        reaper.ImGui_DrawList_AddText(draw_list, text_x, text_y, text_color, "DELETE SEPARATOR")
    end
    
    -- Clear the pending list
    self.pending_separator_controls = {}
end
end

function ButtonRenderer:handleAddButton(target_button, is_left_side)
    local new_button = C.ButtonDefinition.createButton("65535", "No-op (no action)")
    new_button.parent_toolbar = target_button.parent_toolbar
    
    -- Find position in INI and insert
    local success = C.IniManager:insertButtonInIni(target_button, new_button, is_left_side and "before" or "after")
    
    if success then
        C.IniManager:reloadToolbars()
    end
end

function ButtonRenderer:handleAddSeparator(target_button, is_left_side)
    local separator = C.ButtonDefinition.createButton("-1", "SEPARATOR")
    separator.parent_toolbar = target_button.parent_toolbar
    
    -- Find position in INI and insert
    local success = C.IniManager:insertButtonInIni(target_button, separator, is_left_side and "before" or "after")
    
    if success then
        C.IniManager:reloadToolbars()
    end
end

function ButtonRenderer:handleDeleteSeparator(separator_button)
    local success = C.IniManager:deleteButtonFromIni(separator_button)
    
    if success then
        C.IniManager:reloadToolbars()
    end
end

function ButtonRenderer:renderSeparatorControls(ctx, button, pos_x, pos_y, width, window_pos, draw_list, mouse_x, mouse_y)
    local triangle_size = CONFIG.SIZES.HEIGHT / 4
    local hover_zone = 25
    
    -- Calculate positions without scroll first
    local left_edge_x_base = window_pos.x + pos_x
    local center_y_base = window_pos.y + pos_y + CONFIG.SIZES.HEIGHT / 2
    
    -- Apply scroll offset for proximity detection
    local left_edge_x, center_y = UTILS.applyScrollOffset(ctx, left_edge_x_base, center_y_base)
    
    -- Check if mouse is to the right of the left edge AND within hover zone
    local mouse_to_right_of_edge = mouse_x >= left_edge_x
    local near_left = math.abs(mouse_x - left_edge_x) <= hover_zone
    
    -- Only show controls if mouse is on positive side (right) of edge AND close enough
    if not (mouse_to_right_of_edge and near_left) then
        return false
    end
    
    -- Only show delete button on bottom half
    local mouse_in_bottom_half = mouse_y >= center_y
    if not mouse_in_bottom_half then
        return false
    end
    
    -- Use the same edit_width calculation as renderSeparatorInEditMode
    local edit_width = math.max(width, 20)  -- Minimum 20 pixels in edit mode
    
    -- Use base positions for triangle placement (before scroll)
    local control_x = window_pos.x + pos_x + edit_width / 2
    local bottom_triangle_y = window_pos.y + pos_y + CONFIG.SIZES.HEIGHT + triangle_size + 8
    
    -- Store for later rendering on top
    if not self.pending_separator_controls then
        self.pending_separator_controls = {}
    end
    
    table.insert(self.pending_separator_controls, {
        control_x = control_x,
        bottom_triangle_y = bottom_triangle_y,
        triangle_size = triangle_size,
        mouse_x = mouse_x,
        mouse_y = mouse_y,
        show_bottom = true
    })
    
    -- Check for clicks (using scroll-adjusted positions for click detection)
    local clicked_delete = false
    
    if reaper.ImGui_IsMouseClicked(ctx, 0) then
        local control_x_scrolled, bottom_triangle_y_scrolled = UTILS.applyScrollOffset(ctx, control_x, bottom_triangle_y)
        local click_dist_to_bottom = math.sqrt((mouse_x - control_x_scrolled)^2 + (mouse_y - bottom_triangle_y_scrolled)^2)
        
        if click_dist_to_bottom <= triangle_size + 5 then
            clicked_delete = true
        end
    end
    
    return clicked_delete
end

function ButtonRenderer:renderSeparatorInEditMode(ctx, button, pos_x, pos_y, width, window_pos, draw_list)
    -- Make separator interactive in edit mode with minimum width
    local edit_width = math.max(width, 20)  -- Minimum 20 pixels in edit mode
    
    local _, is_hovered, _ =
        C.Interactions:setupInteractionArea(ctx, pos_x, pos_y, edit_width, CONFIG.SIZES.HEIGHT, button.instance_id)

    -- Get colors based on interaction state
    local separator_color = COLOR_UTILS.toImGuiColor(CONFIG.COLORS.GROUP.DECORATION)
    local hover_color = COLOR_UTILS.toImGuiColor(CONFIG.COLORS.GROUP.LABEL)

    -- Use hover color if hovered
    local line_color = is_hovered and hover_color or separator_color

    -- Calculate separator position with scroll offset
    local separator_x_base = window_pos.x + pos_x + edit_width / 2
    local y1_base = window_pos.y + pos_y + 4
    local y2_base = window_pos.y + pos_y + CONFIG.SIZES.HEIGHT + CONFIG.SIZES.DEPTH
    
    -- Apply scroll offset
    local separator_x, y1 = UTILS.applyScrollOffset(ctx, separator_x_base, y1_base)
    local _, y2 = UTILS.applyScrollOffset(ctx, separator_x_base, y2_base)

    -- Draw dashed line
    local dash_length = CONFIG.SIZES.HEIGHT / 16
    local gap_length = 3
    local current_y = y1

    while current_y < y2 do
        local end_y = math.min(current_y + dash_length, y2)
        reaper.ImGui_DrawList_AddLine(draw_list, separator_x, current_y, separator_x, end_y, line_color, 2.0)
        current_y = end_y + gap_length
    end

    -- Return the edit width so layout calculations work correctly
    return edit_width
end

function ButtonRenderer:renderButton(ctx, button, pos_x, pos_y, window_pos, draw_list, editing_mode, layout)
    self.ctx = ctx
    
    -- Initialize pending render arrays at start of frame
    if not self.pending_insertion_controls then
        self.pending_insertion_controls = {}
    end
    if not self.pending_separator_controls then
        self.pending_separator_controls = {}
    end
    
    -- Get mouse position for insertion controls
    local mouse_x, mouse_y = reaper.ImGui_GetMousePos(ctx)

    -- Set up invisible button for interaction using instance_id for uniqueness
    local clicked, is_hovered, is_clicked =
        C.Interactions:setupInteractionArea(ctx, pos_x, pos_y, layout.width, layout.height, button.instance_id)

    -- Handle insertion controls in edit mode with priority hierarchy
    if editing_mode then
        -- Check if we're currently dragging (highest priority)
        local is_dragging = C.DragDropManager:isDragging()
        
        if not is_dragging and not button.is_separator then
            local clicked_add_button, clicked_add_separator, is_left_side = 
                self:renderInsertionControls(ctx, button, pos_x, pos_y, layout.width, window_pos, draw_list, mouse_x, mouse_y)
            
            if clicked_add_button then
                self:handleAddButton(button, is_left_side)
            elseif clicked_add_separator then
                self:handleAddSeparator(button, is_left_side)
            end
        end
    end

    -- Handle drag/drop in edit mode (from button context for ImGui compliance)
    if editing_mode then
        self:handleButtonDragDrop(ctx, button, is_hovered)
    end

    -- Track hover and interactions
    C.Interactions:handleHover(ctx, button, is_hovered, editing_mode)

    -- Handle clicks differently based on mode
    if editing_mode then
        -- In edit mode, only handle on mouse UP and only if no drag occurred
        if is_hovered and reaper.ImGui_IsMouseReleased(ctx, 0) then
            -- Check if this was a drag operation by measuring mouse movement since mouse down
            local drag_delta_x, drag_delta_y = reaper.ImGui_GetMouseDragDelta(ctx, 0)
            local total_movement = math.sqrt(drag_delta_x * drag_delta_x + drag_delta_y * drag_delta_y)
            
            if total_movement < 5 then -- 5 pixel threshold for accidental movement
                -- This was a click, not a drag - open edit menu
                C.Interactions:showButtonSettings(button, button.parent_group)
                reaper.ImGui_OpenPopup(ctx, "button_settings_menu_" .. button.instance_id)
            end
        end
    else
        -- Normal mode - handle clicks immediately for widgets and commands
        if clicked and not (button.widget and button.widget.type == "slider") then
            C.ButtonManager:executeButtonCommand(button)
        end
    end

    C.Interactions:handleRightClick(ctx, button, is_hovered, editing_mode)

    -- Reset right-clicked state when mouse button is released
    if button.is_right_clicked and reaper.ImGui_IsMouseReleased(ctx, 1) then
        button.is_right_clicked = false
    end

    -- Get colors based on state
    local state_key = C.Interactions:determineStateKey(button)
    local mouse_key = C.Interactions:determineMouseKey(is_hovered, is_clicked)
    local bg_color, border_color, icon_color, text_color = COLOR_UTILS.getButtonColors(button, state_key, mouse_key)

    -- Dim the source button during drag
    if editing_mode and C.DragDropManager:isDragging() and 
       C.DragDropManager:getDragSource() and 
       C.DragDropManager:getDragSource().instance_id == button.instance_id then
        bg_color = bg_color & 0xFFFFFF88  -- Make it more transparent
        border_color = border_color & 0xFFFFFF88
        icon_color = icon_color & 0xFFFFFF88
        text_color = text_color & 0xFFFFFF88
    end

    -- Apply shadow effect if needed
    if window_pos and CONFIG.SIZES.DEPTH > 0 then
        local screen_coords = {
            x1 = window_pos.x + pos_x,
            y1 = window_pos.y + pos_y,
            x2 = window_pos.x + pos_x + layout.width,
            y2 = window_pos.y + pos_y + layout.height
        }

        local flags = self:getRoundingFlags(button)
        self:renderShadow(draw_list, screen_coords.x1, screen_coords.y1, screen_coords.x2, screen_coords.y2, flags)
    end

    -- Render background
    self:renderBackground(draw_list, button, pos_x, pos_y, layout.width, bg_color, border_color, window_pos)

    -- For widget buttons, delegate rendering to widgets module
    if button.widget and not editing_mode then
        local handled, width = C.WidgetRenderer:renderWidget(ctx, button, pos_x, pos_y, window_pos, draw_list, layout)

        if handled then
            button:markLayoutClean()
            return width
        end
    end

    -- Always render content based on mode
    if editing_mode and is_hovered and not C.DragDropManager:isDragging() then
        -- Only show edit mode indicator when NOT dragging
        self:renderEditMode(ctx, pos_x, pos_y, layout.width, text_color)
    else
        -- Always render normal button content
        local icon_width =
            C.ButtonContent:renderIcon(
            ctx,
            button,
            pos_x,
            pos_y,
            C.IconSelector,
            icon_color,
            layout.width,
            button.cached_width and button.cached_width.extra_padding or 0
        )

        C.ButtonContent:renderText(
            ctx,
            button,
            pos_x,
            pos_y,
            text_color,
            layout.width,
            icon_width,
            button.cached_width and button.cached_width.extra_padding or 0
        )
    end

    button:markLayoutClean()

    return layout.width
end

function ButtonRenderer:handleButtonDragDrop(ctx, button, is_hovered)
    -- Initialize drag state cache if needed
    if not button.cache.drag_state then
        button.cache.drag_state = {
            was_dragging_last_frame = false
        }
    end
    
    local drag_cache = button.cache.drag_state
    local mouse_dragging = reaper.ImGui_IsMouseDragging(ctx, 0)
    
    -- Handle drag source (only when state changes)
    if is_hovered and mouse_dragging and not drag_cache.was_dragging_last_frame and not C.DragDropManager:isDragging() then
        -- First frame of dragging on this button - start drag
        if C.DragDropManager:startDrag(ctx, button) then
            local item_type = button.is_separator and "separator" or "button"
        end
    end
    
    -- Update drag state for next frame
    drag_cache.was_dragging_last_frame = mouse_dragging
end

function ButtonRenderer:renderShadow(draw_list, x1, y1, x2, y2, flags)
    -- Cache shadow color conversion
    if not self.cached_shadow_color then
        self.cached_shadow_color = COLOR_UTILS.toImGuiColor(CONFIG.COLORS.SHADOW)
    end
    
    -- Get scroll values once and apply inline
    local scroll_x = reaper.ImGui_GetScrollX(self.ctx)
    local scroll_y = reaper.ImGui_GetScrollY(self.ctx)
    
    reaper.ImGui_DrawList_AddRectFilled(
        draw_list,
        x1 - scroll_x + CONFIG.SIZES.DEPTH,
        y1 - scroll_y + CONFIG.SIZES.DEPTH,
        x2 - scroll_x + CONFIG.SIZES.DEPTH,
        y2 - scroll_y + CONFIG.SIZES.DEPTH,
        self.cached_shadow_color,
        CONFIG.SIZES.ROUNDING,
        flags
    )
end

function ButtonRenderer:renderEditMode(ctx, pos_x, pos_y, width, text_color)
    local edit_text = "Edit"
    local text_width = reaper.ImGui_CalcTextSize(ctx, edit_text)
    local text_x = pos_x + (width - text_width) / 2
    local text_y = pos_y + (CONFIG.SIZES.HEIGHT - reaper.ImGui_GetTextLineHeight(ctx)) / 2

    reaper.ImGui_SetCursorPos(ctx, text_x, text_y)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), text_color)
    reaper.ImGui_Text(ctx, edit_text)
    reaper.ImGui_PopStyleColor(ctx)
end

return ButtonRenderer.new()