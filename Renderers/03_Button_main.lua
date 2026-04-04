-- Renderers/03_Button_main.lua
-- Geometry, borders, colors, drag/drop, and main button render path; loaded into ButtonRenderer by 03_Button.lua

local EDIT_CHIP_INSET_H = 5
local EDIT_CHIP_INSET_V = 3
local EDIT_CHIP_ROUND = 3

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

function ButtonRenderer:renderBackground(draw_list, button, rel_x, rel_y, width, bg_color, border_color, coords, is_vertical, content_height)
    local flags = self:getRoundingFlags(button, is_vertical)
    local h = content_height or CONFIG.SIZES.HEIGHT

    local x1, y1 = coords:relativeToDrawList(rel_x, rel_y)
    local x2, y2 = coords:relativeToDrawList(rel_x + width, rel_y + h)

    reaper.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, bg_color, CONFIG.SIZES.ROUNDING, flags)
    reaper.ImGui_DrawList_AddRect(draw_list, x1, y1, x2, y2, border_color, CONFIG.SIZES.ROUNDING, flags)
end

function ButtonRenderer:copyColorProperties(source_button, target_button)
    C.ButtonDefinition.copyCustomColorProperties(source_button, target_button)
end

function ButtonRenderer:getInsertionColorSource(target_button, exclude_instance_id)
    if not target_button then
        return nil
    end

    local function allow(group_button)
        return group_button
            and group_button.instance_id ~= target_button.instance_id
            and (not exclude_instance_id or group_button.instance_id ~= exclude_instance_id)
            and not group_button:isSeparator()
    end

    local parent_group = target_button.parent_group
    if parent_group and parent_group.buttons then
        -- Prefer a sibling with real stored colors (empty custom_color {} is truthy but useless).
        for _, group_button in ipairs(parent_group.buttons) do
            if allow(group_button) and BUTTON_UTILS.hasInheritedStyleSource(group_button) then
                return group_button
            end
        end

        -- Fallback to any normal button in the group.
        for _, group_button in ipairs(parent_group.buttons) do
            if allow(group_button) then
                return group_button
            end
        end
    end

    -- Last fallback: original target button behavior.
    return target_button
end

function ButtonRenderer:handleAddButton(target_button)
    local new_button = C.ButtonDefinition.createNoopButton()
    new_button.parent_toolbar = target_button.parent_toolbar

    local source_button = self:getInsertionColorSource(target_button)
    
    -- Copy color properties from the neighboring button
    if source_button then
        self:copyColorProperties(source_button, new_button)
    end

    C.IniManager:insertButton(target_button, new_button, "before")
end

function ButtonRenderer:handleAddSeparator(target_button)
    local separator = C.ButtonDefinition.createButton("-1", "SEPARATOR")
    separator.parent_toolbar = target_button.parent_toolbar

    C.IniManager:insertButton(target_button, separator, "before")
end

function ButtonRenderer:handleDeleteSeparator(separator_button)
    C.IniManager:deleteButton(separator_button)
end

-- Handle editing mode specific interactions (insertion controls, drag-drop)
function ButtonRenderer:handleEditingMode(ctx, button, rel_x, rel_y, width, coords, draw_list, is_hovered, is_clicked, is_vertical, button_height, render_options)
    if button.is_empty_toolbar_placeholder then
        return
    end

    if not self.pending_insertion_controls then
        self.pending_insertion_controls = {}
    end

    -- Get SCREEN mouse position for insertion controls (not relative)
    local mouse_screen_x, mouse_screen_y = reaper.ImGui_GetMousePos(ctx)

    local preset_browser_open = C.Interactions and C.Interactions.isPresetBrowserOpen and C.Interactions:isPresetBrowserOpen()
    if not C.DragDropManager:isDragging() and not preset_browser_open then
        CACHE_UTILS.ensureButtonCache(button)
        local state_key = C.Interactions:determineStateKey(button)
        local mouse_key = C.Interactions:determineMouseKey(is_hovered, is_clicked)
        local color_mouse_key = BUTTON_UTILS.colorMouseKeyForButton(button, mouse_key)
        local _, _, _, insertion_glyph_outer = COLOR_UTILS.getButtonColors(button, state_key, color_mouse_key)
        insertion_glyph_outer = (insertion_glyph_outer & 0xFFFFFF00) | 0xFF

        local clicked_insert_menu, clicked_add_separator, clicked_delete_separator = self:renderInsertionControls(
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
            button_height,
            insertion_glyph_outer,
            render_options
        )

        if clicked_insert_menu then
            C.Interactions:openInsertMenu(ctx, button)
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

    if button.is_empty_toolbar_placeholder then
        if clicked and not C.DragDropManager:isDragging() then
            local new_button = C.ButtonDefinition.createNoopButton()
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
        if clicked and not BUTTON_UTILS.isWidgetSlider(button) and not BUTTON_UTILS.isWidgetDropdown(button)
            and not BUTTON_UTILS.isWidgetColourSwatch(button) then
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
function ButtonRenderer:applyDragPreviewColors(bg_color, border_color, icon_color, text_color, button)
    if C.DragDropManager:isGroupDrag() and C.DragDropManager:getDragSourceGroup() and button.parent_group == C.DragDropManager:getDragSourceGroup() then
        return bg_color & 0xFFFFFF88, border_color & 0xFFFFFF88, icon_color & 0xFFFFFF88, text_color & 0xFFFFFF88
    end
    if C.DragDropManager:isDragging() and C.DragDropManager:getDragSource() and C.DragDropManager:getDragSource().instance_id == button.instance_id then
        return bg_color & 0xFFFFFF88, border_color & 0xFFFFFF88, icon_color & 0xFFFFFF88, text_color & 0xFFFFFF88
    end
    return bg_color, border_color, icon_color, text_color
end

function ButtonRenderer:applyGhostTint(color)
    if not color then
        return color
    end
    local a = color & 0xFF
    return (color & 0xFFFFFF00) | math.floor(a * 0.5)
end

-- Create render parameters object for button content
function ButtonRenderer:createButtonContentParams(ctx, button, rel_x, rel_y, coords, draw_list, editing_mode, layout, is_vertical, state_key, mouse_key, clicked, is_hovered, is_clicked, ghost_mode)
    local color_mouse_key = BUTTON_UTILS.colorMouseKeyForButton(button, mouse_key)
    local bg_color, border_color, icon_color, text_color = COLOR_UTILS.getButtonColors(button, state_key, color_mouse_key)

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
function ButtonRenderer:renderButtonContent(ctx, button, rel_x, rel_y, coords, draw_list, editing_mode, layout, is_vertical, state_key, mouse_key, clicked, is_hovered, is_clicked, ghost_mode)
    local params = self:createButtonContentParams(ctx, button, rel_x, rel_y, coords, draw_list, editing_mode, layout, is_vertical, state_key, mouse_key, clicked, is_hovered, is_clicked, ghost_mode)
    return self:renderButtonContentWithParams(params)
end

-- Render button content (using params object)
function ButtonRenderer:renderButtonContentWithParams(params)
    -- Render shadow
    if CONFIG.SIZES.DEPTH > 0 and params.ghost_mode ~= true then
        local flags = self:getRoundingFlags(params.button, params.is_vertical)
        self:renderShadow(params.draw_list, params.position.x, params.position.y, params.layout.width, params.layout.height, flags, params.coords)
    end

    -- Render background
    self:renderBackground(
        params.draw_list,
        params.button,
        params.position.x,
        params.position.y,
        params.layout.width,
        params.colors.bg,
        params.colors.border,
        params.coords,
        params.is_vertical,
        params.layout.height
    )

    -- Render widgets in edit mode too; only swap to edit chips while hovered.
    if BUTTON_UTILS.hasWidget(params.button)
        and params.ghost_mode ~= true
        and (not params.editing_mode or not params.interaction.hovered or C.DragDropManager:isDragging()) then
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
        self:renderEditMode(
            params.ctx,
            params.position.x,
            params.position.y,
            params.layout.width,
            params.coords,
            params.draw_list,
            params.colors.bg,
            params.colors.text
        )
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
function ButtonRenderer:renderButton(ctx, button, rel_x, rel_y, coords, draw_list, editing_mode, layout, render_options)
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

    -- Handle editing mode specific logic
    if editing_mode then
        self:handleEditingMode(ctx, button, rel_x, rel_y, layout.width, coords, draw_list, is_hovered, is_clicked, is_vertical, layout.height, render_options)
    end

    -- Handle button interactions
    self:handleButtonInteractions(ctx, button, clicked, is_hovered, is_clicked, editing_mode)

    if C.DragDropManager:shouldOmitDragSourceVisual(button) then
        return layout.width
    end

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
        if BUTTON_UTILS.canStartSeparatorDrag(drag_cache, mouse_dragging, current_time) then
            if C.DragDropManager:startDrag(ctx, button) then
                local item_type = "separator"
            end
            drag_cache.drag_start_time = nil
        end
    end

    drag_cache.was_dragging_last_frame = mouse_dragging
end

function ButtonRenderer:handleButtonDragDrop(ctx, button, is_hovered)
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

function ButtonRenderer:renderEditMode(ctx, rel_x, rel_y, width, coords, draw_list, button_bg_color, button_text_color)
    local alt_down = reaper.ImGui_Mod_Alt and (reaper.ImGui_GetKeyMods(ctx) & reaper.ImGui_Mod_Alt()) ~= 0
    local label = alt_down and "Delete" or "Edit"
    local chip_bg_color, chip_text_color = COLOR_UTILS.widgetPillColors(
        button_text_color or 0xFFFFFFFF,
        button_bg_color or 0x000000FF,
        {}
    )
    if alt_down then
        chip_text_color = 0xD94B4BFF
    end

    local _, _, chip_w, chip_h = DRAWING.getTextChipMetrics(ctx, label, EDIT_CHIP_INSET_H, EDIT_CHIP_INSET_V)
    local chip_x = rel_x + (width - chip_w) / 2
    local chip_y = rel_y + (CONFIG.SIZES.HEIGHT - chip_h) / 2

    DRAWING.drawTextChip(
        ctx,
        coords,
        draw_list,
        chip_x,
        chip_y,
        chip_w,
        chip_h,
        label,
        {
            bg_color = chip_bg_color,
            text_color = chip_text_color,
            rounding = EDIT_CHIP_ROUND
        }
    )
end
