local ButtonRenderer = {}
ButtonRenderer.__index = ButtonRenderer

function ButtonRenderer.new()
    local self = setmetatable({}, ButtonRenderer)
    self.cached_shadow_color = nil
    return self
end

function ButtonRenderer:getRoundingFlags(button, is_vertical)
    if not CONFIG.UI.USE_GROUPING or button.is_alone then
        return reaper.ImGui_DrawFlags_RoundCornersAll()
    end
    
    if button:isSeparator() then
        return reaper.ImGui_DrawFlags_RoundCornersNone()
    end
    
    if button.is_visual_section_start and button.is_visual_section_end then
        return reaper.ImGui_DrawFlags_RoundCornersAll()
    elseif button.is_visual_section_start then
        if is_vertical then
            return reaper.ImGui_DrawFlags_RoundCornersTop()
        end
        return reaper.ImGui_DrawFlags_RoundCornersLeft()
    elseif button.is_visual_section_end then
        if is_vertical then
            return reaper.ImGui_DrawFlags_RoundCornersBottom()
        end
        return reaper.ImGui_DrawFlags_RoundCornersRight()
    end
    
    return reaper.ImGui_DrawFlags_RoundCornersNone()
end

function ButtonRenderer:renderBackground(draw_list, button, rel_x, rel_y, width, bg_color, border_color, coords, is_vertical)
    local flags = self:getRoundingFlags(button, is_vertical)
    
    local x1, y1 = coords:relativeToDrawList(rel_x, rel_y)
    local x2, y2 = coords:relativeToDrawList(rel_x + width, rel_y + CONFIG.SIZES.HEIGHT)

    reaper.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, bg_color, CONFIG.SIZES.ROUNDING, flags)
    reaper.ImGui_DrawList_AddRect(draw_list, x1, y1, x2, y2, border_color, CONFIG.SIZES.ROUNDING, flags)
end

-- Get separator line color with caching
function ButtonRenderer:getSeparatorLineColor(button, mouse_key, bg_color)
    local line_color = bg_color  -- Default fallback
    if CONFIG.COLORS.SEPARATOR.LINE then
        -- Initialize separator cache if needed
        CACHE_UTILS.ensureButtonCacheSubtable(button, "separator")
        
        -- Create cache key for line color
        local mouse_key_upper = mouse_key:upper()
        local line_cache_key = "line_" .. mouse_key_upper
        
        -- Check cache first
        if button.cache.separator[line_cache_key] then
            line_color = button.cache.separator[line_cache_key]
        else
            -- Calculate and cache the line color
            line_color = COLOR_UTILS.toImGuiColor(CONFIG.COLORS.SEPARATOR.LINE[mouse_key_upper] or CONFIG.COLORS.SEPARATOR.LINE.NORMAL)
            button.cache.separator[line_cache_key] = line_color
        end
    end
    return line_color
end

-- Render separator line (solid or dashed, vertical or horizontal)
function ButtonRenderer:renderSeparatorLine(draw_list, coords, button, rel_x, rel_y, width, line_color, is_vertical, is_dashed)
    local thickness = is_dashed and 2.0 or 1.0
    
    if is_vertical then
        -- Horizontal line for vertical layout
        local separator_height = button.cache.layout and button.cache.layout.height or CONFIG.SIZES.SEPARATOR_SIZE
        local separator_rel_y = rel_y + separator_height / 2
        local x1_rel = rel_x + 6
        local x2_rel = rel_x + width - 6

        local x1_draw, separator_y = coords:relativeToDrawList(x1_rel, separator_rel_y)
        local x2_draw, _ = coords:relativeToDrawList(x2_rel, separator_rel_y)

        if is_dashed then
            local dash_length = CONFIG.SIZES.HEIGHT / 3
            local gap_length = 3
            local current_x = x1_draw

            while current_x < x2_draw do
                local end_x = math.min(current_x + dash_length, x2_draw)
                reaper.ImGui_DrawList_AddLine(draw_list, current_x, separator_y, end_x, separator_y, line_color, thickness)
                current_x = end_x + gap_length
            end
        else
            reaper.ImGui_DrawList_AddLine(draw_list, x1_draw, separator_y, x2_draw, separator_y, line_color, thickness)
        end
    else
        -- Vertical line for horizontal layout
        local separator_rel_x = rel_x + width / 2
        local y1_rel, y2_rel
        
        if is_dashed then
            y1_rel = rel_y + 4
            y2_rel = rel_y + CONFIG.SIZES.HEIGHT - 4
        else
            y1_rel = rel_y + CONFIG.SIZES.HEIGHT / 4
            y2_rel = rel_y + CONFIG.SIZES.HEIGHT - CONFIG.SIZES.HEIGHT / 4
        end
        
        local separator_x, _ = coords:relativeToDrawList(separator_rel_x, 0)
        local _, y1_draw = coords:relativeToDrawList(0, y1_rel)
        local _, y2_draw = coords:relativeToDrawList(0, y2_rel)
        
        if is_dashed then
            local dash_length = CONFIG.SIZES.HEIGHT / 16
            local gap_length = 3
            local current_y = y1_draw
            
            while current_y < y2_draw do
                local end_y = math.min(current_y + dash_length, y2_draw)
                reaper.ImGui_DrawList_AddLine(draw_list, separator_x, current_y, separator_x, end_y, line_color, thickness)
                current_y = end_y + gap_length
            end
        else
            reaper.ImGui_DrawList_AddLine(draw_list, separator_x, y1_draw, separator_x, y2_draw, line_color, thickness)
        end
    end
end

-- Render separator in editing mode
function ButtonRenderer:renderSeparatorEditingMode(ctx, button, rel_x, rel_y, width, coords, draw_list, bg_color, border_color, icon_color, text_color, line_color, is_vertical)
    -- Render background if not transparent
    if (bg_color & 0xFF) > 0 then  -- Check alpha channel
        local separator_height = is_vertical and (button.cache.layout and button.cache.layout.height or CONFIG.SIZES.SEPARATOR_SIZE) or CONFIG.SIZES.HEIGHT
        local x1, y1 = coords:relativeToDrawList(rel_x, rel_y)
        local x2, y2 = coords:relativeToDrawList(rel_x + width, rel_y + separator_height)
        reaper.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, bg_color, CONFIG.SIZES.ROUNDING)
        
        -- Render border if not transparent
        if (border_color & 0xFF) > 0 then
            reaper.ImGui_DrawList_AddRect(draw_list, x1, y1, x2, y2, border_color, CONFIG.SIZES.ROUNDING)
        end
    end
    
    -- Render dashed line
    self:renderSeparatorLine(draw_list, coords, button, rel_x, rel_y, width, line_color, is_vertical, true)
    
    -- Render text if not hidden and not default
    if not button.hide_label and button.display_text and button.display_text ~= "" and button.display_text ~= "SEPARATOR" then
        C.ButtonContent:renderText(
            ctx,
            button,
            rel_x,
            rel_y,
            text_color,
            width,
            0, -- no icon width
            0, -- no extra padding
            true, -- editing_mode
            coords,
            draw_list
        )
    end
    
    -- Render icon if present
    if button.icon_char or button.icon_path then
        C.ButtonContent:renderIcon(
            ctx,
            button,
            rel_x,
            rel_y,
            C.IconSelector,
            icon_color,
            width,
            0,  -- no extra padding
            coords,
            draw_list
        )
    end
end

-- Render separator in normal mode
function ButtonRenderer:renderSeparatorNormalMode(ctx, button, rel_x, rel_y, width, coords, draw_list, text_color, line_color, is_vertical)
    -- Render solid line
    self:renderSeparatorLine(draw_list, coords, button, rel_x, rel_y, width, line_color, is_vertical, false)
    
    -- Render text if not hidden and not default
    if not button.hide_label and button.display_text and button.display_text ~= "" and button.display_text ~= "SEPARATOR" then
        C.ButtonContent:renderText(
            ctx,
            button,
            rel_x,
            rel_y,
            text_color,
            width,
            0, -- no icon width
            0, -- no extra padding
            false, -- editing_mode
            coords,
            draw_list
        )
    end
end

-- Main separator rendering function (orchestration)
function ButtonRenderer:renderSeparator(ctx, button, rel_x, rel_y, width, coords, draw_list, editing_mode, state_key, mouse_key, is_vertical)
    -- Get colors for separator
    local bg_color, border_color, icon_color, text_color = COLOR_UTILS.getButtonColors(button, state_key, mouse_key)
    
    -- Get special line color for separators with caching
    local line_color = self:getSeparatorLineColor(button, mouse_key, bg_color)
    
    if editing_mode then
        self:renderSeparatorEditingMode(ctx, button, rel_x, rel_y, width, coords, draw_list, bg_color, border_color, icon_color, text_color, line_color, is_vertical)
    else
        self:renderSeparatorNormalMode(ctx, button, rel_x, rel_y, width, coords, draw_list, text_color, line_color, is_vertical)
    end
    
    return width
end

-- Helper function to render triangles with symbols
function ButtonRenderer:renderTriangleWithSymbol(draw_list, center_x, center_y, triangle_width, triangle_height, triangle_color, angle, symbol_type, symbol_color)
    -- Render the triangle
    DRAWING.triangle(
        draw_list,
        center_x,
        center_y,
        triangle_width,
        triangle_height,
        triangle_color,
        angle
    )

    -- Calculate symbol position and size
    local symbol_size = triangle_width / 2
    local symbol_thickness = 2.0
    
    -- Adjust symbol position based on triangle direction
    local symbol_offset = triangle_height / 12
    local symbol_center_x = center_x
    local symbol_center_y = center_y
    
    if angle == DRAWING.ANGLE_DOWN then
        symbol_center_y = center_y - symbol_offset + 8  -- Raise by 8 pixels
    elseif angle == DRAWING.ANGLE_UP then
        symbol_center_y = center_y + symbol_offset - 8  -- Lower by 8 pixels (invert direction)
    end

    if symbol_type == "plus" then
        -- Draw + as two crossing lines (horizontal and vertical)
        reaper.ImGui_DrawList_AddLine(
            draw_list,
            symbol_center_x - symbol_size/2, symbol_center_y,
            symbol_center_x + symbol_size/2, symbol_center_y,
            symbol_color, symbol_thickness
        )
        reaper.ImGui_DrawList_AddLine(
            draw_list,
            symbol_center_x, symbol_center_y - symbol_size/2,
            symbol_center_x, symbol_center_y + symbol_size/2,
            symbol_color, symbol_thickness
        )
    elseif symbol_type == "x" then
        -- Draw X as two crossing lines
        reaper.ImGui_DrawList_AddLine(
            draw_list,
            symbol_center_x - symbol_size/2, symbol_center_y - symbol_size/2,
            symbol_center_x + symbol_size/2, symbol_center_y + symbol_size/2,
            symbol_color, symbol_thickness
        )
        reaper.ImGui_DrawList_AddLine(
            draw_list,
            symbol_center_x + symbol_size/2, symbol_center_y - symbol_size/2,
            symbol_center_x - symbol_size/2, symbol_center_y + symbol_size/2,
            symbol_color, symbol_thickness
        )
    end
end

function ButtonRenderer:renderInsertionControls(ctx, button, rel_x, rel_y, width, coords, draw_list, mouse_screen_x, mouse_screen_y)
    local triangle_size = CONFIG.SIZES.HEIGHT / 4
    local hover_zone = 25

    -- Convert mouse from screen to relative coordinates (accounting for scroll)
    local mouse_rel_x, mouse_rel_y = coords:screenToRelative(mouse_screen_x, mouse_screen_y)
    
    -- Check if mouse is within hover zone to the RIGHT of the left edge
    local mouse_past_left_edge = mouse_rel_x >= rel_x
    local mouse_within_hover_zone = mouse_rel_x <= rel_x + hover_zone
    local mouse_near_button = math.abs(mouse_rel_y - rel_y) <= CONFIG.SIZES.HEIGHT + 30

    if not (mouse_past_left_edge and mouse_within_hover_zone and mouse_near_button) then
        return false
    end

    -- Don't show add separator for first button in group (separator already exists there)
    local is_first_button_in_group = false
    if button.parent_group then
        is_first_button_in_group = button.parent_group.buttons[1] == button
    end

    -- Fix issue #1: Center delete separator triangle on separator center
    local control_center_x = button:isSeparator() and (rel_x + width / 2) or rel_x
    
    -- Determine which controls to show based on mouse position and button type
    local show_top = mouse_rel_y < rel_y + CONFIG.SIZES.HEIGHT / 2
    local show_bottom = mouse_rel_y >= rel_y + CONFIG.SIZES.HEIGHT / 2
    
    -- Don't show bottom control (add separator) for first button in group
    if is_first_button_in_group and not button:isSeparator() then
        show_bottom = false
    end
    
    -- OPTIMIZATION: Reuse control objects to avoid garbage collection churn
    self.control_pool = self.control_pool or {}
    self.control_pool_index = (self.control_pool_index or 0) + 1
    
    local control = self.control_pool[self.control_pool_index]
    if not control then
        control = {}
        self.control_pool[self.control_pool_index] = control
    end
    
    -- Update control properties
    control.control_rel_x = control_center_x
    control.top_triangle_rel_y = rel_y - triangle_size - 8
    control.bottom_triangle_rel_y = rel_y + CONFIG.SIZES.HEIGHT + triangle_size + 8
    control.triangle_size = triangle_size
    control.show_top = show_top
    control.show_bottom = show_bottom
    control.is_separator_button = button:isSeparator()
    control.button_instance_id = button.instance_id
    control.mouse_distance_to_center = math.abs(mouse_rel_x - control_center_x)

    self.pending_insertion_controls = self.pending_insertion_controls or {}
    table.insert(self.pending_insertion_controls, control)

    local clicked_add_button = false
    local clicked_add_separator = false
    local clicked_delete_separator = false

    if reaper.ImGui_IsMouseClicked(ctx, 0) then
        local click_dist_top = math.sqrt((mouse_rel_x - control.control_rel_x)^2 + (mouse_rel_y - control.top_triangle_rel_y)^2)
        local click_dist_bottom = math.sqrt((mouse_rel_x - control.control_rel_x)^2 + (mouse_rel_y - control.bottom_triangle_rel_y)^2)

        if control.show_top and click_dist_top <= triangle_size + 5 then
            clicked_add_button = true
        elseif control.show_bottom and click_dist_bottom <= triangle_size + 5 then
            if button:isSeparator() then
                clicked_delete_separator = true
            else
                clicked_add_separator = true
            end
        end
    end
    
    return clicked_add_button, clicked_add_separator, clicked_delete_separator
end

function ButtonRenderer:renderPendingControlsOnTop(ctx, draw_list, coords)
    if not self.pending_insertion_controls then
        self.pending_insertion_controls = {}
    end

    -- Render insertion controls on top with hierarchy logic
    if self.pending_insertion_controls and #self.pending_insertion_controls > 0 then
        -- Find the closest control to show exclusively
        local closest_control = nil
        local min_distance = math.huge
        
        for _, control in ipairs(self.pending_insertion_controls) do
            if control.mouse_distance_to_center < min_distance then
                min_distance = control.mouse_distance_to_center
                closest_control = control
            end
        end
        
        -- Only render the closest control
        if closest_control then
            local control_x, _ = coords:relativeToDrawList(closest_control.control_rel_x, 0)
            local _, top_y = coords:relativeToDrawList(0, closest_control.top_triangle_rel_y)
            local _, bottom_y = coords:relativeToDrawList(0, closest_control.bottom_triangle_rel_y)

            local triangle_width = closest_control.triangle_size * 2
            local triangle_height = closest_control.triangle_size * 3
            
            -- Cache editing colors to avoid repeated conversion
            if not self.cached_editing_colors then
                self.cached_editing_colors = {
                    white = COLOR_UTILS.toImGuiColor("#FFFFFFFF"),
                    add_button = COLOR_UTILS.toImGuiColor("#4A90E2FF") & 0xFFFFFF7F,
                    delete = COLOR_UTILS.toImGuiColor("#FF0000FF") & 0xFFFFFF7F,
                    add_separator = COLOR_UTILS.toImGuiColor("#CCCCCCFF") & 0xFFFFFF7F
                }
            end
            
            local white_color = self.cached_editing_colors.white

            if closest_control.show_top then
                -- Add Button triangle - medium blue with +
                local add_button_color = self.cached_editing_colors.add_button
                
                self:renderTriangleWithSymbol(
                    draw_list,
                    control_x, top_y,
                    triangle_width, triangle_height,
                    add_button_color,
                    DRAWING.ANGLE_DOWN,
                    "plus",
                    white_color
                )
            end

            if closest_control.show_bottom then
                if closest_control.is_separator_button then
                    -- Delete separator triangle - red with X
                    local delete_color = self.cached_editing_colors.delete
                    
                    self:renderTriangleWithSymbol(
                        draw_list,
                        control_x, bottom_y,
                        triangle_width, triangle_height,
                        delete_color,
                        DRAWING.ANGLE_UP,
                        "x",
                        white_color
                    )
                else
                    -- Add Separator triangle - lighter gray with +
                    local add_separator_color = self.cached_editing_colors.add_separator
                    
                    self:renderTriangleWithSymbol(
                        draw_list,
                        control_x, bottom_y,
                        triangle_width, triangle_height,
                        add_separator_color,
                        DRAWING.ANGLE_UP,
                        "plus",
                        white_color
                    )
                end
            end
        end

        self.pending_insertion_controls = {}
    end
    
    -- Reset pool index for next frame
    self.control_pool_index = 0
end

function ButtonRenderer:handleAddButton(target_button)
    local new_button = C.ButtonDefinition.createButton("65535", "No-op (no action)")
    new_button.parent_toolbar = target_button.parent_toolbar

    local success = C.IniManager:insertButton(target_button, new_button, "before")

    if success then
        C.IniManager:reloadToolbars()
    end
end

function ButtonRenderer:handleAddSeparator(target_button)
    local separator = C.ButtonDefinition.createButton("-1", "SEPARATOR")
    separator.parent_toolbar = target_button.parent_toolbar

    local success = C.IniManager:insertButton(target_button, separator, "before")

    if success then
        C.IniManager:reloadToolbars()
    end
end

function ButtonRenderer:handleDeleteSeparator(separator_button)
    local success = C.IniManager:deleteButton(separator_button)

    if success then
        C.IniManager:reloadToolbars()
    end
end

-- Handle editing mode specific interactions (insertion controls, drag-drop)
function ButtonRenderer:handleEditingMode(ctx, button, rel_x, rel_y, width, coords, draw_list, is_hovered, is_vertical)
    if not self.pending_insertion_controls then
        self.pending_insertion_controls = {}
    end

    -- Get SCREEN mouse position for insertion controls (not relative)
    local mouse_screen_x, mouse_screen_y = reaper.ImGui_GetMousePos(ctx)

    if not C.DragDropManager:isDragging() then
        local clicked_add_button, clicked_add_separator, clicked_delete_separator = self:renderInsertionControls(
            ctx,
            button,
            rel_x,
            rel_y,
            width,
            coords,
            draw_list,
            mouse_screen_x,
            mouse_screen_y
        )

        if clicked_add_button then
            -- Always add buttons BEFORE the target
            self:handleAddButton(button)
        elseif clicked_add_separator then
            -- Always add separators BEFORE the target
            self:handleAddSeparator(button)
        elseif clicked_delete_separator then
            -- Use the specific button that was clicked
            self:handleDeleteSeparator(button)
        end
    end

    -- Make drag detection more sensitive for separators
    if button:isSeparator() then
        self:handleSeparatorDragDrop(ctx, button, is_hovered)
    else
        self:handleButtonDragDrop(ctx, button, is_hovered)
    end
end

-- Handle button interactions (clicks, right-clicks, hover)
function ButtonRenderer:handleButtonInteractions(ctx, button, clicked, is_hovered, is_clicked, editing_mode)
    C.Interactions:handleHover(ctx, button, is_hovered, editing_mode)

    -- Handle separator interactions early
    if button:isSeparator() then
        -- Separators have limited interactions - handled in renderSeparator
        return
    end

    -- Regular button interactions
    if editing_mode then
        -- Only allow settings menu for normal buttons, not separators
        if is_hovered and reaper.ImGui_IsMouseReleased(ctx, 0) then
            local drag_delta_x, drag_delta_y = reaper.ImGui_GetMouseDragDelta(ctx, 0)
            local total_movement = math.sqrt(drag_delta_x * drag_delta_x + drag_delta_y * drag_delta_y)

            if total_movement < 5 then
                C.Interactions:showButtonSettings(button, button.parent_group)
                reaper.ImGui_OpenPopup(ctx, "button_settings_menu_" .. button.instance_id)
            end
        end
    else
        -- Only normal buttons can execute commands
        if clicked and not (button.widget and button.widget.type == "slider") then
            C.ButtonManager:executeButtonCommand(button)
        end
    end

    -- Only normal buttons can have widgets with right-click
    if button.widget then
        if is_hovered and reaper.ImGui_IsMouseClicked(ctx, 1) then
            C.Interactions:showButtonSettings(button, button.parent_group)
            reaper.ImGui_OpenPopup(ctx, "button_settings_menu_" .. button.instance_id)
        end
    else
        C.Interactions:handleRightClick(ctx, button, is_hovered, editing_mode)
    end

    if button.is_right_clicked and reaper.ImGui_IsMouseReleased(ctx, 1) then
        button.is_right_clicked = false
    end
end

-- Apply drag preview effect to colors
function ButtonRenderer:applyDragPreviewColors(bg_color, border_color, icon_color, text_color, button)
    if C.DragDropManager:isDragging() and C.DragDropManager:getDragSource() and C.DragDropManager:getDragSource().instance_id == button.instance_id then
        return bg_color & 0xFFFFFF88, border_color & 0xFFFFFF88, icon_color & 0xFFFFFF88, text_color & 0xFFFFFF88
    end
    return bg_color, border_color, icon_color, text_color
end

-- Render button content (shadow, background, icon, text, widget)
function ButtonRenderer:renderButtonContent(ctx, button, rel_x, rel_y, coords, draw_list, editing_mode, layout, is_vertical, state_key, mouse_key, clicked, is_hovered, is_clicked)
    -- Get colors
    local bg_color, border_color, icon_color, text_color = COLOR_UTILS.getButtonColors(button, state_key, mouse_key)
    
    -- Apply drag preview effect if dragging
    bg_color, border_color, icon_color, text_color = self:applyDragPreviewColors(bg_color, border_color, icon_color, text_color, button)

    -- Render shadow
    if CONFIG.SIZES.DEPTH > 0 then
        local flags = self:getRoundingFlags(button, is_vertical)
        self:renderShadow(draw_list, rel_x, rel_y, layout.width, layout.height, flags, coords)
    end

    -- Render background
    self:renderBackground(draw_list, button, rel_x, rel_y, layout.width, bg_color, border_color, coords, is_vertical)

    -- Render widget if present (in normal mode)
    if button.widget and not editing_mode then
        local handled, width = C.WidgetRenderer:renderWidget(ctx, button, rel_x, rel_y, coords, draw_list, layout, clicked, is_hovered, is_clicked)
        if handled then
            return width
        end
    end

    -- Render icon and text (or edit mode overlay)
    if editing_mode and is_hovered and not C.DragDropManager:isDragging() then
        self:renderEditMode(ctx, rel_x, rel_y, layout.width, text_color)
    else
        local extra_padding = button.cached_width and button.cached_width.extra_padding or 0
        local icon_width = C.ButtonContent:renderIcon(
            ctx,
            button,
            rel_x,
            rel_y,
            C.IconSelector,
            icon_color,
            layout.width,
            extra_padding,
            coords,
            draw_list
        )

        C.ButtonContent:renderText(
            ctx,
            button,
            rel_x,
            rel_y,
            text_color,
            layout.width,
            icon_width,
            extra_padding,
            editing_mode,
            coords,
            draw_list
        )
    end

    return layout.width
end

-- Main button rendering function (orchestration)
function ButtonRenderer:renderButton(ctx, button, rel_x, rel_y, coords, draw_list, editing_mode, layout)
    local is_vertical = layout and layout.is_vertical

    -- Setup interaction area
    local clicked, is_hovered, is_clicked = C.Interactions:setupInteractionArea(ctx, rel_x, rel_y, layout.width, layout.height, button.instance_id)

    -- Handle editing mode specific logic
    if editing_mode then
        self:handleEditingMode(ctx, button, rel_x, rel_y, layout.width, coords, draw_list, is_hovered, is_vertical)
    end

    -- Handle button interactions
    self:handleButtonInteractions(ctx, button, clicked, is_hovered, is_clicked, editing_mode)

    -- Handle separator rendering early
    if button:isSeparator() then
        local state_key = C.Interactions:determineStateKey(button)
        local mouse_key = "NORMAL" -- disable hover animation
        return self:renderSeparator(ctx, button, rel_x, rel_y, layout.width, coords, draw_list, editing_mode, state_key, mouse_key, is_vertical)
    end

    -- Determine button state
    local state_key = C.Interactions:determineStateKey(button)
    local mouse_key = C.Interactions:determineMouseKey(is_hovered, is_clicked)

    -- Render button content
    local width = self:renderButtonContent(ctx, button, rel_x, rel_y, coords, draw_list, editing_mode, layout, is_vertical, state_key, mouse_key, clicked, is_hovered, is_clicked)

    button:markLayoutClean()
    return width
end

function ButtonRenderer:ensureDragState(button, include_drag_start_time)
    CACHE_UTILS.ensureButtonCache(button)
    if not button.cache.drag_state then
        button.cache.drag_state = {
            was_dragging_last_frame = false,
            mouse_down_on_button = false
        }
        if include_drag_start_time then
            button.cache.drag_state.drag_start_time = nil
        end
    end
    return button.cache.drag_state
end

function ButtonRenderer:handleSeparatorDragDrop(ctx, button, is_hovered)
    local drag_cache = self:ensureDragState(button, true)
    local mouse_dragging = reaper.ImGui_IsMouseDragging(ctx, 0)
    local mouse_down = reaper.ImGui_IsMouseDown(ctx, 0)
    local current_time = reaper.ImGui_GetTime(ctx)

    -- Track if mouse was pressed down on this button
    if is_hovered and reaper.ImGui_IsMouseClicked(ctx, 0) then
        drag_cache.mouse_down_on_button = true
        drag_cache.drag_start_time = current_time
    end

    -- Reset when mouse is released
    if not mouse_down then
        drag_cache.mouse_down_on_button = false
        drag_cache.drag_start_time = nil
    end

    -- Start drag if mouse was pressed on this button and we're dragging
    if drag_cache.mouse_down_on_button and not drag_cache.was_dragging_last_frame and not C.DragDropManager:isDragging() then
        -- Start drag immediately for separators (no delay) or after minimal movement
        if mouse_dragging or (drag_cache.drag_start_time and current_time - drag_cache.drag_start_time > 0.05) then
            if C.DragDropManager:startDrag(ctx, button) then
                local item_type = "separator"
            end
            drag_cache.drag_start_time = nil
        end
    end

    drag_cache.was_dragging_last_frame = mouse_dragging
end

function ButtonRenderer:handleButtonDragDrop(ctx, button, is_hovered)
    local drag_cache = self:ensureDragState(button, false)
    local mouse_dragging = reaper.ImGui_IsMouseDragging(ctx, 0)
    local mouse_down = reaper.ImGui_IsMouseDown(ctx, 0)

    -- Track if mouse was pressed down on this button
    if is_hovered and reaper.ImGui_IsMouseClicked(ctx, 0) then
        drag_cache.mouse_down_on_button = true
    end

    -- Reset when mouse is released
    if not mouse_down then
        drag_cache.mouse_down_on_button = false
    end

    -- Start drag if mouse was pressed on this button and we're dragging
    if drag_cache.mouse_down_on_button and mouse_dragging and not drag_cache.was_dragging_last_frame and not C.DragDropManager:isDragging() then
        if C.DragDropManager:startDrag(ctx, button) then
            local item_type = button:isSeparator() and "separator" or "button"
        end
    end

    drag_cache.was_dragging_last_frame = mouse_dragging
end

function ButtonRenderer:renderShadow(draw_list, rel_x, rel_y, width, height, flags, coords)
    if not self.cached_shadow_color then
        -- Use global cached color if available
        self.cached_shadow_color = CONFIG_MANAGER:getCachedColorSafe("SHADOW") or COLOR_UTILS.toImGuiColor(CONFIG.COLORS.SHADOW)
    end

    local x1, y1 = coords:relativeToDrawList(rel_x + CONFIG.SIZES.DEPTH, rel_y + CONFIG.SIZES.DEPTH)
    local x2, y2 = coords:relativeToDrawList(rel_x + width + CONFIG.SIZES.DEPTH, rel_y + height + CONFIG.SIZES.DEPTH)

    reaper.ImGui_DrawList_AddRectFilled(
        draw_list,
        x1,
        y1,
        x2,
        y2,
        self.cached_shadow_color,
        CONFIG.SIZES.ROUNDING,
        flags
    )
end

function ButtonRenderer:renderEditMode(ctx, rel_x, rel_y, width, text_color)
    local edit_text = "Edit"
    local text_width = reaper.ImGui_CalcTextSize(ctx, edit_text)
    local text_x = rel_x + (width - text_width) / 2
    local text_y = rel_y + (CONFIG.SIZES.HEIGHT - reaper.ImGui_GetTextLineHeight(ctx)) / 2

    reaper.ImGui_SetCursorPos(ctx, text_x, text_y)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), text_color)
    reaper.ImGui_Text(ctx, edit_text)
    reaper.ImGui_PopStyleColor(ctx)
end

return ButtonRenderer.new()