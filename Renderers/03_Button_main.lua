-- Renderers/03_Button_main.lua
-- Geometry, chrome, colors, drag/drop, and main button render path; merged onto ButtonRenderer by 03_Button.lua

local Main = {}

function Main:getRoundingFlags(button, is_vertical)
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

function Main:renderBackground(draw_list, button, rel_x, rel_y, width, bg_color, border_color, coords, is_vertical)
    local flags = self:getRoundingFlags(button, is_vertical)
    
    local x1, y1 = coords:relativeToDrawList(rel_x, rel_y)
    local x2, y2 = coords:relativeToDrawList(rel_x + width, rel_y + CONFIG.SIZES.HEIGHT)

    reaper.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, bg_color, CONFIG.SIZES.ROUNDING, flags)
    reaper.ImGui_DrawList_AddRect(draw_list, x1, y1, x2, y2, border_color, CONFIG.SIZES.ROUNDING, flags)
end

-- Helper function to copy color properties from one button to another
function Main:copyColorProperties(source_button, target_button)
    if not source_button then
        return
    end
    
    -- Determine which default colors to use based on button type
    local default_state = source_button:isSeparator() and "SEPARATOR" or "NORMAL"
    local default_colors = CONFIG.COLORS[default_state]
    
    -- Always initialize custom_color structure
    target_button.custom_color = {}
    
    -- Copy each colorable item individually, falling back to defaults if not present
    -- Background
    if source_button.custom_color and source_button.custom_color.background and source_button.custom_color.background.normal then
        target_button.custom_color.background = {
            normal = source_button.custom_color.background.normal
        }
    elseif default_colors and default_colors.BG then
        target_button.custom_color.background = {
            normal = default_colors.BG.NORMAL
        }
    end
    
    -- Border
    if source_button.custom_color and source_button.custom_color.border and source_button.custom_color.border.normal then
        target_button.custom_color.border = {
            normal = source_button.custom_color.border.normal
        }
    elseif default_colors and default_colors.BORDER then
        target_button.custom_color.border = {
            normal = default_colors.BORDER.NORMAL
        }
    end
    
    -- Text
    if source_button.custom_color and source_button.custom_color.text and source_button.custom_color.text.normal then
        target_button.custom_color.text = {
            normal = source_button.custom_color.text.normal
        }
    elseif default_colors and default_colors.TEXT then
        target_button.custom_color.text = {
            normal = default_colors.TEXT.NORMAL
        }
    end
    
    -- Icon
    if source_button.custom_color and source_button.custom_color.icon and source_button.custom_color.icon.normal then
        target_button.custom_color.icon = {
            normal = source_button.custom_color.icon.normal
        }
    elseif default_colors and default_colors.ICON then
        target_button.custom_color.icon = {
            normal = default_colors.ICON.NORMAL
        }
    end
    
    -- Hover state
    if source_button.custom_color and source_button.custom_color.hover then
        target_button.custom_color.hover = {}
        if source_button.custom_color.hover.background then
            target_button.custom_color.hover.background = source_button.custom_color.hover.background
        elseif default_colors and default_colors.BG and default_colors.BG.HOVER then
            target_button.custom_color.hover.background = default_colors.BG.HOVER
        end
        if source_button.custom_color.hover.border then
            target_button.custom_color.hover.border = source_button.custom_color.hover.border
        elseif default_colors and default_colors.BORDER and default_colors.BORDER.HOVER then
            target_button.custom_color.hover.border = default_colors.BORDER.HOVER
        end
    elseif default_colors and default_colors.BG and (default_colors.BG.HOVER or default_colors.BORDER and default_colors.BORDER.HOVER) then
        target_button.custom_color.hover = {}
        if default_colors.BG.HOVER then
            target_button.custom_color.hover.background = default_colors.BG.HOVER
        end
        if default_colors.BORDER and default_colors.BORDER.HOVER then
            target_button.custom_color.hover.border = default_colors.BORDER.HOVER
        end
    end
    
    -- Active/Clicked state
    if source_button.custom_color and source_button.custom_color.active then
        target_button.custom_color.active = {}
        if source_button.custom_color.active.background then
            target_button.custom_color.active.background = source_button.custom_color.active.background
        elseif default_colors and default_colors.BG and default_colors.BG.CLICKED then
            target_button.custom_color.active.background = default_colors.BG.CLICKED
        end
        if source_button.custom_color.active.border then
            target_button.custom_color.active.border = source_button.custom_color.active.border
        elseif default_colors and default_colors.BORDER and default_colors.BORDER.CLICKED then
            target_button.custom_color.active.border = default_colors.BORDER.CLICKED
        end
    elseif default_colors and default_colors.BG and (default_colors.BG.CLICKED or default_colors.BORDER and default_colors.BORDER.CLICKED) then
        target_button.custom_color.active = {}
        if default_colors.BG.CLICKED then
            target_button.custom_color.active.background = default_colors.BG.CLICKED
        end
        if default_colors.BORDER and default_colors.BORDER.CLICKED then
            target_button.custom_color.active.border = default_colors.BORDER.CLICKED
        end
    end
    
    -- Copy user_colors if they exist (they modify the defaults)
    if source_button.user_colors then
        target_button.user_colors = {}
        for key, value in pairs(source_button.user_colors) do
            target_button.user_colors[key] = value
        end
    end
    
    -- Copy border_offset if it exists
    if source_button.border_offset then
        target_button.border_offset = {
            saturation = source_button.border_offset.saturation or 0.0,
            value = source_button.border_offset.value or 0.0
        }
    end
end

function Main:handleAddButton(target_button)
    local new_button = C.ButtonDefinition.createButton("65535", "No-op (no action)")
    new_button.parent_toolbar = target_button.parent_toolbar

    -- Find neighboring button to inherit colors from
    local source_button = nil
    if target_button.parent_toolbar and target_button.parent_toolbar.buttons then
        -- Find the index of the target button
        local target_index = nil
        for i, button in ipairs(target_button.parent_toolbar.buttons) do
            if button.instance_id == target_button.instance_id then
                target_index = i
                break
            end
        end
        
        if target_index then
            -- Try to get the button to the left (index - 1)
            -- This is the button that will be to the left of the new button after insertion
            if target_index > 1 then
                source_button = target_button.parent_toolbar.buttons[target_index - 1]
            end
            
            -- If no left button, use the target button itself
            -- The target will be to the right of the new button after insertion
            if not source_button then
                source_button = target_button
            end
        end
    end
    
    -- Copy color properties from the neighboring button
    if source_button then
        self:copyColorProperties(source_button, new_button)
    end

    C.IniManager:insertButton(target_button, new_button, "before")
end

function Main:handleAddSeparator(target_button)
    local separator = C.ButtonDefinition.createButton("-1", "SEPARATOR")
    separator.parent_toolbar = target_button.parent_toolbar

    C.IniManager:insertButton(target_button, separator, "before")
end

function Main:handleDeleteSeparator(separator_button)
    C.IniManager:deleteButton(separator_button)
end

-- Handle editing mode specific interactions (insertion controls, drag-drop)
function Main:handleEditingMode(ctx, button, rel_x, rel_y, width, coords, draw_list, is_hovered, is_vertical, button_height)
    if button.is_empty_toolbar_placeholder then
        return
    end

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
            mouse_screen_y,
            is_vertical,
            button_height
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
function Main:handleButtonInteractions(ctx, button, clicked, is_hovered, is_clicked, editing_mode)
    C.Interactions:handleHover(ctx, button, is_hovered, editing_mode)

    if button.is_empty_toolbar_placeholder then
        if clicked and not C.DragDropManager:isDragging() then
            local new_button = C.ButtonDefinition.createButton("65535", "No-op (no action)")
            new_button.parent_toolbar = button.parent_toolbar
            C.IniManager:insertFirstButtonInSection(button.parent_toolbar.section, new_button)
        end
        return
    end

    -- Handle separator interactions early
    if button:isSeparator() then
        -- Separators have limited interactions - handled in renderSeparator
        return
    end

    -- Check for command (Ctrl/Cmd) modifier
    local key_mods = reaper.ImGui_GetKeyMods(ctx)
    local is_cmd_down = (key_mods & reaper.ImGui_Mod_Ctrl()) ~= 0

    -- If Cmd/Ctrl is held AND (clicked OR right-clicked), always open settings
    local open_settings_menu = is_cmd_down and (
        (is_hovered and reaper.ImGui_IsMouseClicked(ctx, 0)) or
        (is_hovered and reaper.ImGui_IsMouseClicked(ctx, 1))
    )

    if open_settings_menu then
        C.Interactions:showButtonSettings(button, button.parent_group)
        reaper.ImGui_OpenPopup(ctx, "button_settings_menu_" .. button.instance_id)
        return
    end

    -- Regular button interactions
    if editing_mode then
        -- Only allow settings menu for normal buttons, not separators
        if is_hovered and reaper.ImGui_IsMouseReleased(ctx, 0) then
            local drag_delta_x, drag_delta_y = reaper.ImGui_GetMouseDragDelta(ctx, 0)
            local total_movement = math.sqrt(drag_delta_x * drag_delta_x + drag_delta_y * drag_delta_y)

            if total_movement < 5 then
                local alt_down = reaper.ImGui_Mod_Alt and (reaper.ImGui_GetKeyMods(ctx) & reaper.ImGui_Mod_Alt()) ~= 0
                if alt_down then
                    C.IniManager:deleteButton(button)
                    return
                end
                C.Interactions:showButtonSettings(button, button.parent_group)
                reaper.ImGui_OpenPopup(ctx, "button_settings_menu_" .. button.instance_id)
            end
        end
    else
        -- Only normal buttons can execute commands
        if clicked and not BUTTON_UTILS.isWidgetSlider(button) and not BUTTON_UTILS.isWidgetDropdown(button) then
            C.ButtonManager:executeButtonCommand(button)
        end
    end

    -- Only normal buttons can have widgets with right-click
    if BUTTON_UTILS.hasWidget(button) then
        if is_hovered and reaper.ImGui_IsMouseClicked(ctx, 1) then
            -- If widget supplies a handler and not editing, let it handle right-click
            if not editing_mode and button.widget and button.widget.onRightClick then
                -- Widget right-click handled elsewhere
            else
                -- Open settings for right-click if not handled by widget
                C.Interactions:showButtonSettings(button, button.parent_group)
                reaper.ImGui_OpenPopup(ctx, "button_settings_menu_" .. button.instance_id)
            end
        end
    else
        C.Interactions:handleRightClick(ctx, button, is_hovered, editing_mode)
    end

    if button.is_right_clicked and reaper.ImGui_IsMouseReleased(ctx, 1) then
        button.is_right_clicked = false
    end
end

-- Apply drag preview effect to colors
function Main:applyDragPreviewColors(bg_color, border_color, icon_color, text_color, button)
    if C.DragDropManager:isGroupDrag() and C.DragDropManager:getDragSourceGroup() and button.parent_group == C.DragDropManager:getDragSourceGroup() then
        return bg_color & 0xFFFFFF88, border_color & 0xFFFFFF88, icon_color & 0xFFFFFF88, text_color & 0xFFFFFF88
    end
    if C.DragDropManager:isDragging() and C.DragDropManager:getDragSource() and C.DragDropManager:getDragSource().instance_id == button.instance_id then
        return bg_color & 0xFFFFFF88, border_color & 0xFFFFFF88, icon_color & 0xFFFFFF88, text_color & 0xFFFFFF88
    end
    return bg_color, border_color, icon_color, text_color
end

function Main:applyGhostTint(color)
    if not color then
        return color
    end
    local a = color & 0xFF
    return (color & 0xFFFFFF00) | math.floor(a * 0.5)
end

-- Create render parameters object for button content
function Main:createButtonContentParams(ctx, button, rel_x, rel_y, coords, draw_list, editing_mode, layout, is_vertical, state_key, mouse_key, clicked, is_hovered, is_clicked, ghost_mode)
    local bg_color, border_color, icon_color, text_color = COLOR_UTILS.getButtonColors(button, state_key, mouse_key)

    if ghost_mode then
        bg_color = self:applyGhostTint(bg_color)
        border_color = self:applyGhostTint(border_color)
        icon_color = self:applyGhostTint(icon_color)
        text_color = self:applyGhostTint(text_color)
    else
        bg_color, border_color, icon_color, text_color = self:applyDragPreviewColors(bg_color, border_color, icon_color, text_color, button)
    end

    return {
        ctx = ctx,
        button = button,
        position = {x = rel_x, y = rel_y},
        coords = coords,
        draw_list = draw_list,
        editing_mode = editing_mode,
        layout = layout,
        is_vertical = is_vertical,
        ghost_mode = ghost_mode == true,
        colors = {
            bg = bg_color,
            border = border_color,
            icon = icon_color,
            text = text_color
        },
        interaction = {
            clicked = clicked,
            hovered = is_hovered,
            clicked_state = is_clicked
        }
    }
end

-- Render button content (shadow, background, icon, text, widget)
function Main:renderButtonContent(ctx, button, rel_x, rel_y, coords, draw_list, editing_mode, layout, is_vertical, state_key, mouse_key, clicked, is_hovered, is_clicked, ghost_mode)
    local params = self:createButtonContentParams(ctx, button, rel_x, rel_y, coords, draw_list, editing_mode, layout, is_vertical, state_key, mouse_key, clicked, is_hovered, is_clicked, ghost_mode)
    return self:renderButtonContentWithParams(params)
end

-- Render button content (using params object)
function Main:renderButtonContentWithParams(params)
    -- Render shadow
    if CONFIG.SIZES.DEPTH > 0 and params.ghost_mode ~= true then
        local flags = self:getRoundingFlags(params.button, params.is_vertical)
        self:renderShadow(params.draw_list, params.position.x, params.position.y, params.layout.width, params.layout.height, flags, params.coords)
    end

    -- Render background
    self:renderBackground(params.draw_list, params.button, params.position.x, params.position.y, params.layout.width, params.colors.bg, params.colors.border, params.coords, params.is_vertical)

    -- Render widget if present (in normal mode)
    if BUTTON_UTILS.hasWidget(params.button) and not params.editing_mode and params.ghost_mode ~= true then
        local handled, width = C.WidgetRenderer:renderWidget(
            params.ctx,
            params.button,
            params.position.x,
            params.position.y,
            params.coords,
            params.draw_list,
            params.layout,
            params.interaction.clicked,
            params.interaction.hovered,
            params.interaction.clicked_state
        )
        if handled then
            return width
        end
    end

    -- Render icon and text (or edit mode overlay)
    if params.editing_mode and params.interaction.hovered and not C.DragDropManager:isDragging() and
        not params.button.is_empty_toolbar_placeholder and params.ghost_mode ~= true then
        self:renderEditMode(params.ctx, params.position.x, params.position.y, params.layout.width, params.colors.text)
    else
        local extra_padding = BUTTON_UTILS.getExtraPadding(params.button)
        local icon_params = C.ButtonContent:createIconParams(
            params.ctx,
            params.button,
            params.position.x,
            params.position.y,
            C.IconSelector,
            params.colors.icon,
            params.layout.width,
            extra_padding,
            params.coords,
            params.draw_list
        )
        local icon_width = C.ButtonContent:renderIconWithParams(icon_params)

        local text_params = C.ButtonContent:createTextParams(
            params.ctx,
            params.button,
            params.position.x,
            params.position.y,
            params.colors.text,
            params.layout.width,
            icon_width,
            extra_padding,
            params.editing_mode,
            params.coords,
            params.draw_list
        )
        C.ButtonContent:renderTextWithParams(text_params)
    end

    return params.layout.width
end

-- Main button rendering function (orchestration)
function Main:renderButton(ctx, button, rel_x, rel_y, coords, draw_list, editing_mode, layout, render_options)
    render_options = render_options or {}
    local ghost_mode = render_options.ghost_mode
    local is_vertical = layout and layout.is_vertical

    if ghost_mode then
        if button:isSeparator() then
            return self:renderSeparator(ctx, button, rel_x, rel_y, layout.width, coords, draw_list, editing_mode, "SEPARATOR", "NORMAL", is_vertical, render_options)
        end
        return self:renderButtonContent(
            ctx,
            button,
            rel_x,
            rel_y,
            coords,
            draw_list,
            editing_mode,
            layout,
            is_vertical,
            "NORMAL",
            "NORMAL",
            false,
            false,
            false,
            true
        )
    end

    -- Setup interaction area
    local clicked, is_hovered, is_clicked = C.Interactions:setupInteractionArea(ctx, rel_x, rel_y, layout.width, layout.height, button.instance_id)

    -- Hide source button/group once a drop target is active (ghost shows the preview).
    if editing_mode and C.DragDropManager:isDragging() and C.DragDropManager:hasPotentialDropTarget() then
        local hide = false
        if C.DragDropManager:isGroupDrag() and C.DragDropManager:getDragSourceGroup() and button.parent_group == C.DragDropManager:getDragSourceGroup() then
            hide = true
        elseif not C.DragDropManager:isGroupDrag() and C.DragDropManager:getDragSource() and C.DragDropManager:getDragSource().instance_id == button.instance_id then
            hide = true
        end
        if hide then
            if editing_mode then
                self:handleEditingMode(ctx, button, rel_x, rel_y, layout.width, coords, draw_list, is_hovered, is_vertical, layout.height)
            end
            self:handleButtonInteractions(ctx, button, clicked, is_hovered, is_clicked, editing_mode)
            button:markLayoutClean()
            return layout.width
        end
    end

    -- Handle editing mode specific logic
    if editing_mode then
        self:handleEditingMode(ctx, button, rel_x, rel_y, layout.width, coords, draw_list, is_hovered, is_vertical, layout.height)
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
    local width = self:renderButtonContent(ctx, button, rel_x, rel_y, coords, draw_list, editing_mode, layout, is_vertical, state_key, mouse_key, clicked, is_hovered, is_clicked, false)

    button:markLayoutClean()
    return width
end

function Main:ensureDragState(button, include_drag_start_time)
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

function Main:handleSeparatorDragDrop(ctx, button, is_hovered)
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
        if BUTTON_UTILS.canStartSeparatorDrag(drag_cache, mouse_dragging, current_time) then
            if C.DragDropManager:startDrag(ctx, button) then
                local item_type = "separator"
            end
            drag_cache.drag_start_time = nil
        end
    end

    drag_cache.was_dragging_last_frame = mouse_dragging
end

function Main:handleButtonDragDrop(ctx, button, is_hovered)
    if button.is_empty_toolbar_placeholder then
        return
    end
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
    if BUTTON_UTILS.canStartDrag(drag_cache, mouse_dragging) then
        if C.DragDropManager:startDrag(ctx, button) then
            local item_type = button:isSeparator() and "separator" or "button"
        end
    end

    drag_cache.was_dragging_last_frame = mouse_dragging
end

function Main:renderShadow(draw_list, rel_x, rel_y, width, height, flags, coords)
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

function Main:renderEditMode(ctx, rel_x, rel_y, width, text_color)
    local alt_down = reaper.ImGui_Mod_Alt and (reaper.ImGui_GetKeyMods(ctx) & reaper.ImGui_Mod_Alt()) ~= 0
    local edit_text = alt_down and "DELETE" or "Edit"
    local display_color = alt_down and 0xFF4444FF or text_color
    local text_width = reaper.ImGui_CalcTextSize(ctx, edit_text)
    local text_x = rel_x + (width - text_width) / 2
    local text_y = rel_y + (CONFIG.SIZES.HEIGHT - reaper.ImGui_GetTextLineHeight(ctx)) / 2

    reaper.ImGui_SetCursorPos(ctx, text_x, text_y)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), display_color)
    reaper.ImGui_Text(ctx, edit_text)
    reaper.ImGui_PopStyleColor(ctx)
end

return Main
