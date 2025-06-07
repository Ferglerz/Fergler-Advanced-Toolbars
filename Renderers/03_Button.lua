local ButtonRenderer = {}
ButtonRenderer.__index = ButtonRenderer

function ButtonRenderer.new()
    local self = setmetatable({}, ButtonRenderer)
    self.cached_shadow_color = nil
    return self
end

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

function ButtonRenderer:renderBackground(draw_list, button, rel_x, rel_y, width, bg_color, border_color, coords)
    local flags = self:getRoundingFlags(button)
    
    local x1, y1 = coords:relativeToDrawList(rel_x, rel_y)
    local x2, y2 = coords:relativeToDrawList(rel_x + width, rel_y + CONFIG.SIZES.HEIGHT)

    reaper.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, bg_color, CONFIG.SIZES.ROUNDING, flags)
    reaper.ImGui_DrawList_AddRect(draw_list, x1, y1, x2, y2, border_color, CONFIG.SIZES.ROUNDING, flags)
end

function ButtonRenderer:renderInsertionControls(ctx, button, rel_x, rel_y, width, coords, draw_list, mouse_screen_x, mouse_screen_y)
    if self.pending_separator_controls and #self.pending_separator_controls > 0 then
        return false
    end

    local triangle_size = CONFIG.SIZES.HEIGHT / 4
    local hover_zone = 25

    -- Convert mouse from screen to relative coordinates (accounting for scroll)
    local window_x, window_y = reaper.ImGui_GetWindowPos(ctx)
    local scroll_x = reaper.ImGui_GetScrollX(ctx)
    local scroll_y = reaper.ImGui_GetScrollY(ctx)
    
    local mouse_rel_x = mouse_screen_x - window_x + scroll_x
    local mouse_rel_y = mouse_screen_y - window_y + scroll_y
    
    -- Check if mouse is within hover zone to the RIGHT of the left edge
    local mouse_past_left_edge = mouse_rel_x >= rel_x
    local mouse_within_hover_zone = mouse_rel_x <= rel_x + hover_zone
    local mouse_near_button = math.abs(mouse_rel_y - rel_y) <= CONFIG.SIZES.HEIGHT + 30

    if not (mouse_past_left_edge and mouse_within_hover_zone and mouse_near_button) then
        return false
    end

    local control = {
        control_rel_x = rel_x,
        top_triangle_rel_y = rel_y - triangle_size - 8,
        bottom_triangle_rel_y = rel_y + CONFIG.SIZES.HEIGHT + triangle_size + 8,
        triangle_size = triangle_size,
        show_top = mouse_rel_y < rel_y + CONFIG.SIZES.HEIGHT / 2,
        show_bottom = mouse_rel_y >= rel_y + CONFIG.SIZES.HEIGHT / 2
    }

    self.pending_insertion_controls = self.pending_insertion_controls or {}
    table.insert(self.pending_insertion_controls, control)

    local clicked_add_button = false
    local clicked_add_separator = false

    if reaper.ImGui_IsMouseClicked(ctx, 0) then
        local click_dist_top = math.sqrt((mouse_rel_x - control.control_rel_x)^2 + (mouse_rel_y - control.top_triangle_rel_y)^2)
        local click_dist_bottom = math.sqrt((mouse_rel_x - control.control_rel_x)^2 + (mouse_rel_y - control.bottom_triangle_rel_y)^2)

        if control.show_top and click_dist_top <= triangle_size + 5 then
            clicked_add_button = true
        elseif control.show_bottom and click_dist_bottom <= triangle_size + 5 then
            clicked_add_separator = true
        end
    end

    return clicked_add_button, clicked_add_separator, mouse_rel_y < rel_y + CONFIG.SIZES.HEIGHT / 2
end

function ButtonRenderer:renderPendingControlsOnTop(ctx, draw_list, coords)
    if not self.pending_insertion_controls then
        self.pending_insertion_controls = {}
    end
    if not self.pending_separator_controls then
        self.pending_separator_controls = {}
    end

    -- Render insertion controls on top
    if self.pending_insertion_controls then
        for _, control in ipairs(self.pending_insertion_controls) do
            local control_x, _ = coords:relativeToDrawList(control.control_rel_x, 0)
            local _, top_y = coords:relativeToDrawList(0, control.top_triangle_rel_y)
            local _, bottom_y = coords:relativeToDrawList(0, control.bottom_triangle_rel_y)

            local base_color = COLOR_UTILS.toImGuiColor(CONFIG.COLORS.GROUP.LABEL)
            local triangle_bg_color = base_color & 0xFFFFFF7F
            local text_color = base_color

            local triangle_width = control.triangle_size * 2
            local triangle_height = control.triangle_size * 3

            if control.show_top then
                DRAWING.triangle(
                    draw_list,
                    control_x,
                    top_y,
                    triangle_width,
                    triangle_height,
                    triangle_bg_color,
                    DRAWING.ANGLE_DOWN
                )

                local text_x = control_x + triangle_width / 2 + 5
                local text_y = top_y - 6
                reaper.ImGui_DrawList_AddText(draw_list, text_x, text_y, text_color, "ADD BUTTON")
            end

            if control.show_bottom then
                DRAWING.triangle(
                    draw_list,
                    control_x,
                    bottom_y,
                    triangle_width,
                    triangle_height,
                    triangle_bg_color,
                    DRAWING.ANGLE_UP
                )

                local sep_text_x = control_x + triangle_width / 2 + 5
                local sep_text_y = bottom_y - 6
                reaper.ImGui_DrawList_AddText(draw_list, sep_text_x, sep_text_y, text_color, "ADD SEPARATOR")
            end
        end

        self.pending_insertion_controls = {}
    end

    -- Render separator delete controls on top
    if self.pending_separator_controls then
        for _, control in ipairs(self.pending_separator_controls) do
            local control_x, _ = coords:relativeToDrawList(control.control_rel_x, 0)
            local _, bottom_y = coords:relativeToDrawList(0, control.bottom_triangle_rel_y)

            local base_color = COLOR_UTILS.toImGuiColor("#FF0000FF")
            local triangle_bg_color = base_color & 0xFFFFFF7F
            local text_color = base_color

            local triangle_width = control.triangle_size * 2
            local triangle_height = control.triangle_size * 3

            DRAWING.triangle(
                draw_list,
                control_x,
                bottom_y,
                triangle_width,
                triangle_height,
                triangle_bg_color,
                DRAWING.ANGLE_UP
            )

            local text_x = control_x + triangle_width / 2 + 5
            local text_y = bottom_y - 6
            reaper.ImGui_DrawList_AddText(draw_list, text_x, text_y, text_color, "DELETE SEPARATOR")
        end

        self.pending_separator_controls = {}
    end
end

function ButtonRenderer:handleAddButton(target_button, is_left_side)
    local new_button = C.ButtonDefinition.createButton("65535", "No-op (no action)")
    new_button.parent_toolbar = target_button.parent_toolbar

    local success = C.IniManager:insertButtonInIni(target_button, new_button, is_left_side and "before" or "after")

    if success then
        C.IniManager:reloadToolbars()
    end
end

function ButtonRenderer:handleAddSeparator(target_button, is_left_side)
    local separator = C.ButtonDefinition.createButton("-1", "SEPARATOR")
    separator.parent_toolbar = target_button.parent_toolbar

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

function ButtonRenderer:renderSeparatorControls(ctx, button, rel_x, rel_y, width, coords, draw_list, mouse_screen_x, mouse_screen_y)
    local triangle_size = CONFIG.SIZES.HEIGHT / 4
    local hover_zone = 25

    -- Convert mouse from screen to relative coordinates (accounting for scroll)
    local window_x, window_y = reaper.ImGui_GetWindowPos(ctx)
    local scroll_x = reaper.ImGui_GetScrollX(ctx)
    local scroll_y = reaper.ImGui_GetScrollY(ctx)
    
    local mouse_rel_x = mouse_screen_x - window_x + scroll_x
    local mouse_rel_y = mouse_screen_y - window_y + scroll_y

    -- Check if mouse is within hover zone to the RIGHT of the left edge  
    local mouse_past_left_edge = mouse_rel_x >= rel_x
    local mouse_within_hover_zone = mouse_rel_x <= rel_x + hover_zone
    local mouse_near_separator = math.abs(mouse_rel_y - rel_y) <= CONFIG.SIZES.HEIGHT + 30

    if not (mouse_past_left_edge and mouse_within_hover_zone and mouse_near_separator) then
        return false
    end

    -- Only show delete button on bottom half
    local mouse_in_bottom_half = mouse_rel_y >= rel_y + CONFIG.SIZES.HEIGHT / 2
    if not mouse_in_bottom_half then
        return false
    end

    local edit_width = math.max(width, 20)

    local control_rel_x = rel_x + edit_width / 2
    local bottom_triangle_rel_y = rel_y + CONFIG.SIZES.HEIGHT + triangle_size + 8

    if not self.pending_separator_controls then
        self.pending_separator_controls = {}
    end

    table.insert(
        self.pending_separator_controls,
        {
            control_rel_x = control_rel_x,
            bottom_triangle_rel_y = bottom_triangle_rel_y,
            triangle_size = triangle_size,
            show_bottom = true
        }
    )

    local clicked_delete = false

    if reaper.ImGui_IsMouseClicked(ctx, 0) then
        local click_dist_to_bottom = math.sqrt((mouse_rel_x - control_rel_x)^2 + (mouse_rel_y - bottom_triangle_rel_y)^2)

        if click_dist_to_bottom <= triangle_size + 5 then
            clicked_delete = true
        end
    end

    return clicked_delete
end

function ButtonRenderer:renderSeparatorInEditMode(ctx, button, rel_x, rel_y, width, coords, draw_list)
    local edit_width = math.max(width, 20)

    local _, is_hovered, _ = C.Interactions:setupInteractionArea(ctx, rel_x, rel_y, edit_width, CONFIG.SIZES.HEIGHT, button.instance_id)

    local separator_color = COLOR_UTILS.toImGuiColor(CONFIG.COLORS.GROUP.DECORATION)
    local hover_color = COLOR_UTILS.toImGuiColor(CONFIG.COLORS.GROUP.LABEL)

    local line_color = is_hovered and hover_color or separator_color

    local separator_rel_x = rel_x + edit_width / 2
    local y1_rel = rel_y + 4
    local y2_rel = rel_y + CONFIG.SIZES.HEIGHT + CONFIG.SIZES.DEPTH

    local separator_x, _ = coords:relativeToDrawList(separator_rel_x, 0)
    local _, y1 = coords:relativeToDrawList(0, y1_rel)
    local _, y2 = coords:relativeToDrawList(0, y2_rel)

    local dash_length = CONFIG.SIZES.HEIGHT / 16
    local gap_length = 3
    local current_y = y1

    while current_y < y2 do
        local end_y = math.min(current_y + dash_length, y2)
        reaper.ImGui_DrawList_AddLine(draw_list, separator_x, current_y, separator_x, end_y, line_color, 2.0)
        current_y = end_y + gap_length
    end

    return edit_width
end

function ButtonRenderer:renderButton(ctx, button, rel_x, rel_y, coords, draw_list, editing_mode, layout)
    if not self.pending_insertion_controls then
        self.pending_insertion_controls = {}
    end

    -- Get SCREEN mouse position for insertion controls (not relative)
    local mouse_screen_x, mouse_screen_y = reaper.ImGui_GetMousePos(ctx)

    local clicked, is_hovered, is_clicked = C.Interactions:setupInteractionArea(ctx, rel_x, rel_y, layout.width, layout.height, button.instance_id)

    if editing_mode then
        if not C.DragDropManager:isDragging() and not button.is_separator then
            local clicked_add_button, clicked_add_separator, is_left_side = self:renderInsertionControls(
                ctx,
                button,
                rel_x,
                rel_y,
                layout.width,
                coords,
                draw_list,
                mouse_screen_x,
                mouse_screen_y
            )

            if clicked_add_button then
                self:handleAddButton(button, is_left_side)
            elseif clicked_add_separator then
                self:handleAddSeparator(button, is_left_side)
            end
        end

        self:handleButtonDragDrop(ctx, button, is_hovered)
    end

    C.Interactions:handleHover(ctx, button, is_hovered, editing_mode)

    if editing_mode then
        if is_hovered and reaper.ImGui_IsMouseReleased(ctx, 0) then
            local drag_delta_x, drag_delta_y = reaper.ImGui_GetMouseDragDelta(ctx, 0)
            local total_movement = math.sqrt(drag_delta_x * drag_delta_x + drag_delta_y * drag_delta_y)

            if total_movement < 5 then
                C.Interactions:showButtonSettings(button, button.parent_group)
                reaper.ImGui_OpenPopup(ctx, "button_settings_menu_" .. button.instance_id)
            end
        end
    else
        if clicked and not (button.widget and button.widget.type == "slider") then
            C.ButtonManager:executeButtonCommand(button)
        end
    end

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

    local state_key = C.Interactions:determineStateKey(button)
    local mouse_key = C.Interactions:determineMouseKey(is_hovered, is_clicked)
    local bg_color, border_color, icon_color, text_color = COLOR_UTILS.getButtonColors(button, state_key, mouse_key)

    if editing_mode and C.DragDropManager:isDragging() and C.DragDropManager:getDragSource() and C.DragDropManager:getDragSource().instance_id == button.instance_id then
        bg_color = bg_color & 0xFFFFFF88
        border_color = border_color & 0xFFFFFF88
        icon_color = icon_color & 0xFFFFFF88
        text_color = text_color & 0xFFFFFF88
    end

    if CONFIG.SIZES.DEPTH > 0 then
        local flags = self:getRoundingFlags(button)
        self:renderShadow(draw_list, rel_x, rel_y, layout.width, layout.height, flags, coords)
    end

    self:renderBackground(draw_list, button, rel_x, rel_y, layout.width, bg_color, border_color, coords)

    if button.widget and not editing_mode then
        local handled, width = C.WidgetRenderer:renderWidget(ctx, button, rel_x, rel_y, coords, draw_list, layout, clicked, is_hovered, is_clicked)

        if handled then
            button:markLayoutClean()
            return width
        end
    end

    if editing_mode and is_hovered and not C.DragDropManager:isDragging() then
        self:renderEditMode(ctx, rel_x, rel_y, layout.width, text_color)
    else
        local icon_width = C.ButtonContent:renderIcon(
            ctx,
            button,
            rel_x,
            rel_y,
            C.IconSelector,
            icon_color,
            layout.width,
            button.cached_width and button.cached_width.extra_padding or 0
        )

        C.ButtonContent:renderText(
            ctx,
            button,
            rel_x,
            rel_y,
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
    if not button.cache.drag_state then
        button.cache.drag_state = {
            was_dragging_last_frame = false
        }
    end

    local drag_cache = button.cache.drag_state
    local mouse_dragging = reaper.ImGui_IsMouseDragging(ctx, 0)

    if is_hovered and mouse_dragging and not drag_cache.was_dragging_last_frame and not C.DragDropManager:isDragging() then
        if C.DragDropManager:startDrag(ctx, button) then
            local item_type = button.is_separator and "separator" or "button"
        end
    end

    drag_cache.was_dragging_last_frame = mouse_dragging
end

function ButtonRenderer:renderShadow(draw_list, rel_x, rel_y, width, height, flags, coords)
    if not self.cached_shadow_color then
        self.cached_shadow_color = COLOR_UTILS.toImGuiColor(CONFIG.COLORS.SHADOW)
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