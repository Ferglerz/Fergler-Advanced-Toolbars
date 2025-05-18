-- Renderers/03_Button.lua

local ButtonRenderer = {}
ButtonRenderer.__index = ButtonRenderer

function ButtonRenderer.new()
    local self = setmetatable({}, ButtonRenderer)
    self.ctx = nil
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
    -- Use cached position coordinates if they're valid
    local screen_coords = button.cache.screen_coords
    local recalculate =
        not screen_coords or screen_coords.window_x ~= window_pos.x or screen_coords.window_y ~= window_pos.y or
        screen_coords.pos_x ~= pos_x or
        screen_coords.pos_y ~= pos_y or
        screen_coords.width ~= width

    if recalculate then
        -- Store the coordinates in a new table to avoid creating garbage each frame
        if not screen_coords then
            screen_coords = {}
        end

        screen_coords.window_x = window_pos.x
        screen_coords.window_y = window_pos.y
        screen_coords.pos_x = pos_x
        screen_coords.pos_y = pos_y
        screen_coords.width = width

        screen_coords.x1 = window_pos.x + pos_x
        screen_coords.y1 = window_pos.y + pos_y
        screen_coords.x2 = screen_coords.x1 + width
        screen_coords.y2 = screen_coords.y1 + CONFIG.SIZES.HEIGHT

        button.cache.screen_coords = screen_coords
    end

    return screen_coords
end

-- Render the button background (fill and border)
function ButtonRenderer:renderBackground(draw_list, button, pos_x, pos_y, width, bg_color, border_color, window_pos)
    if not window_pos then
        return
    end

    local flags = self:getRoundingFlags(button)
    local screen_coords = self:calculateButtonCoordinates(button, pos_x, pos_y, width, window_pos)

    local x1, y1, x2, y2 = screen_coords.x1, screen_coords.y1, screen_coords.x2, screen_coords.y2
    -- Apply scroll offset
    local current_scroll_x = reaper.ImGui_GetScrollX(self.ctx)
    local current_scroll_y = reaper.ImGui_GetScrollY(self.ctx)

    -- Check if scroll position has changed
    if
        not screen_coords.scroll_adjusted or screen_coords.last_scroll_x ~= current_scroll_x or
            screen_coords.last_scroll_y ~= current_scroll_y
     then
        -- Update scroll values
        screen_coords.last_scroll_x = current_scroll_x
        screen_coords.last_scroll_y = current_scroll_y

        -- Calculate adjusted coordinates
        screen_coords.sx1 = x1 - current_scroll_x
        screen_coords.sy1 = y1 - current_scroll_y
        screen_coords.sx2 = x2 - current_scroll_x
        screen_coords.sy2 = y2 - current_scroll_y

        screen_coords.scroll_adjusted = true
    end

    -- Render button background and border
    reaper.ImGui_DrawList_AddRectFilled(
        draw_list,
        screen_coords.sx1,
        screen_coords.sy1,
        screen_coords.sx2,
        screen_coords.sy2,
        bg_color,
        CONFIG.SIZES.ROUNDING,
        flags
    )

    reaper.ImGui_DrawList_AddRect(
        draw_list,
        screen_coords.sx1,
        screen_coords.sy1,
        screen_coords.sx2,
        screen_coords.sy2,
        border_color,
        CONFIG.SIZES.ROUNDING,
        flags
    )
end

function ButtonRenderer:renderSeparatorInEditMode(ctx, button, pos_x, pos_y, width, window_pos, draw_list)
    -- Make separator interactive in edit mode
    local _, is_hovered, _ =
        C.Interactions:setupInteractionArea(ctx, pos_x, pos_y, width, CONFIG.SIZES.HEIGHT, button.id)

    -- Get colors based on interaction state
    local separator_color = COLOR_UTILS.toImGuiColor(CONFIG.COLORS.GROUP.DECORATION)
    local hover_color = COLOR_UTILS.toImGuiColor(CONFIG.COLORS.GROUP.LABEL)

    -- Use hover color if hovered
    local line_color = is_hovered and hover_color or separator_color

    -- Calculate separator position - use directly from parameters
    local separator_x = window_pos.x + pos_x + width / 2
    local y1 = window_pos.y + pos_y + 4
    local y2 = window_pos.y + pos_y + CONFIG.SIZES.HEIGHT + CONFIG.SIZES.DEPTH

    -- Draw dashed line
    local dash_length = CONFIG.SIZES.HEIGHT / 16
    local gap_length = 3
    local current_y = y1

    while current_y < y2 do
        local end_y = math.min(current_y + dash_length, y2)
        reaper.ImGui_DrawList_AddLine(draw_list, separator_x, current_y, separator_x, end_y, line_color, 2.0)
        current_y = end_y + gap_length
    end

    -- Add drag source for separator in edit mode
    if is_hovered and reaper.ImGui_IsMouseDragging(ctx, 0, 5.0) then
        if reaper.ImGui_BeginDragDropSource(ctx, reaper.ImGui_DragDropFlags_None()) then
            -- Find the button's index in the toolbar
            local button_index = 0
            local current_toolbar = button.parent_toolbar

            if current_toolbar then
                for i, b in ipairs(current_toolbar.buttons) do
                    if b == button then
                        button_index = i
                        break
                    end
                end
            end

            -- Set drag data (button index)
            local drag_data = tostring(button_index)
            reaper.ImGui_SetDragDropPayload(ctx, "TOOLBAR_BUTTON", drag_data, #drag_data)

            -- Show preview of separator
            reaper.ImGui_Text(ctx, "Move Separator")

            reaper.ImGui_EndDragDropSource()
        end
    end

    -- Accept drop on separator
    if reaper.ImGui_BeginDragDropTarget(ctx) then
        local payload = reaper.ImGui_AcceptDragDropPayload(ctx, "TOOLBAR_BUTTON")
        if payload then
            -- Get source button index
            local source_idx = tonumber(reaper.ImGui_GetDragDropPayload(ctx))

            -- Get target button index
            local target_idx = 0
            local current_toolbar = button.parent_toolbar

            if current_toolbar then
                for i, b in ipairs(current_toolbar.buttons) do
                    if b == button then
                        target_idx = i
                        break
                    end
                end
            end

            -- Handle reordering
            if C.ToolbarController and source_idx and target_idx then
                C.ToolbarController:handleButtonOrderChange(source_idx, target_idx)
            end
        end

        reaper.ImGui_EndDragDropTarget(ctx)
    end

    -- Return the width so layout calculations work correctly
    return width
end

function ButtonRenderer:renderButton(ctx, button, pos_x, pos_y, window_pos, draw_list, editing_mode, layout)
    self.ctx = ctx

    -- Set up invisible button for interaction
    local clicked, is_hovered, is_clicked =
        C.Interactions:setupInteractionArea(ctx, pos_x, pos_y, layout.width, layout.height, button.id)

    -- Track hover and interactions
    C.Interactions:handleHover(ctx, button, is_hovered, editing_mode)

    -- Handle drag and drop for buttons in editing mode
    if editing_mode then
        -- Start drag operation when mouse is dragged
        if is_hovered and reaper.ImGui_IsMouseDragging(ctx, 0, 5.0) then
            if reaper.ImGui_BeginDragDropSource(ctx, reaper.ImGui_DragDropFlags_None()) then
                -- Find the button's index in the toolbar
                local button_index = 0
                local current_toolbar = button.parent_toolbar

                if current_toolbar then
                    for i, b in ipairs(current_toolbar.buttons) do
                        if b == button then
                            button_index = i
                            break
                        end
                    end
                end

                -- Set drag data (button index)
                local drag_data = tostring(button_index)
                reaper.ImGui_SetDragDropPayload(ctx, "TOOLBAR_BUTTON", drag_data, #drag_data)

                -- Show preview
                if button.is_separator then
                    reaper.ImGui_Text(ctx, "Move Separator")
                else
                    reaper.ImGui_Text(ctx, "Move: " .. UTILS.stripNewLines(button.display_text))
                end

                reaper.ImGui_EndDragDropSource(ctx)
            end
        end

        -- Accept drop
        if reaper.ImGui_BeginDragDropTarget(ctx) then
            local payload = reaper.ImGui_AcceptDragDropPayload(ctx, "TOOLBAR_BUTTON")
            if payload then
                -- Get source button index
                local _, _, source_idx = reaper.ImGui_GetDragDropPayload(ctx)

                -- Get target button index
                local target_idx = 0
                local current_toolbar = button.parent_toolbar

                if current_toolbar then
                    for i, b in ipairs(current_toolbar.buttons) do
                        if b == button then
                            target_idx = i
                            break
                        end
                    end
                end

                -- Handle reordering
                if C.ToolbarController and source_idx and target_idx then
                    C.ToolbarController:handleButtonOrderChange(source_idx, target_idx)
                end
            end

            reaper.ImGui_EndDragDropTarget(ctx)
        end
    end

    -- Handle drag and drop for buttons in editing mode
    if editing_mode then
        -- Start drag operation when mouse is dragged
        if is_hovered and reaper.ImGui_IsMouseDragging(ctx, 0, 5.0) then
            if reaper.ImGui_BeginDragDropSource(ctx, reaper.ImGui_DragDropFlags_None()) then
                -- Find the button's index in the toolbar
                local button_index = 0
                local current_toolbar = button.parent_toolbar

                if current_toolbar then
                    for i, b in ipairs(current_toolbar.buttons) do
                        if b == button then
                            button_index = i
                            break
                        end
                    end
                end

                -- Set drag data (button index)
                local drag_data = tostring(button_index)
                reaper.ImGui_SetDragDropPayload(ctx, "TOOLBAR_BUTTON", drag_data, #drag_data)

                -- Show preview
                if button.is_separator then
                    reaper.ImGui_Text(ctx, "Move Separator")
                else
                    reaper.ImGui_Text(ctx, "Move: " .. UTILS.stripNewLines(button.display_text))
                end

                reaper.ImGui_EndDragDropSource(ctx)
            end
        end

        -- Accept drop
        if reaper.ImGui_BeginDragDropTarget(ctx) then
            local payload = reaper.ImGui_AcceptDragDropPayload(ctx, "TOOLBAR_BUTTON")
            if payload then
                -- Get source button index
                local _, _, source_idx = reaper.ImGui_GetDragDropPayload(ctx)

                -- Get target button index
                local target_idx = 0
                local current_toolbar = button.parent_toolbar

                if current_toolbar then
                    for i, b in ipairs(current_toolbar.buttons) do
                        if b == button then
                            target_idx = i
                            break
                        end
                    end
                end

                -- Handle reordering
                if C.ToolbarController and source_idx and target_idx then
                    C.ToolbarController:handleButtonOrderChange(source_idx, target_idx)
                end
            end

            reaper.ImGui_EndDragDropTarget(ctx)
        end
    end

    if clicked and not (button.widget and button.widget.type == "slider") then
        if editing_mode then
            -- Open context menu in editing mode
            C.Interactions:showButtonSettings(button, button.parent_group)
            reaper.ImGui_OpenPopup(ctx, "button_settings_menu_" .. button.id)
        else
            -- Execute button command for normal clicks
            C.ButtonManager:executeButtonCommand(button)
        end
    end

    C.Interactions:handleRightClick(ctx, button, is_hovered, editing_mode)

    -- Reset right-clicked state when mouse button is released
    if button.is_right_clicked and reaper.ImGui_IsMouseReleased(ctx, 1) then
        button.is_right_clicked = false
    end

    -- Get state and mouse keys for the button
    local state_key = C.Interactions:determineStateKey(button)
    local mouse_key = C.Interactions:determineMouseKey(is_hovered, is_clicked)

    -- Initialize cache if needed
    if not button.cache then
        button.cache = {colors = {}, icon = {}}
    elseif not button.cache.colors then
        button.cache.colors = {}
    end

    -- Check if we need to recalculate colors
    local need_colors_update =
        button.cache.colors.state_key ~= state_key or button.cache.colors.mouse_key ~= mouse_key or button.is_dirty or
        not button.cache.colors.bg_color

    -- For debugging - uncomment to see if caching is working
    -- reaper.ShowConsoleMsg("Need colors update: " .. tostring(need_colors_update) ..
    --                       " state_key: " .. tostring(state_key) ..
    --                       " cached: " .. tostring(button.cache.colors.state_key) .. "\n")

    local bg_color, border_color, icon_color, text_color

    if need_colors_update then
        -- Get colors based on state and cache them
        bg_color, border_color, icon_color, text_color = COLOR_UTILS.getButtonColors(button, state_key, mouse_key)

        -- Update the cache
        button.cache.colors.state_key = state_key
        button.cache.colors.mouse_key = mouse_key
        button.cache.colors.bg_color = bg_color
        button.cache.colors.border_color = border_color
        button.cache.colors.icon_color = icon_color
        button.cache.colors.text_color = text_color

        -- Clear the dirty flag since we've updated the colors
        button.is_dirty = false
    else
        -- Use cached colors
        bg_color = button.cache.colors.bg_color
        border_color = button.cache.colors.border_color
        icon_color = button.cache.colors.icon_color
        text_color = button.cache.colors.text_color
    end

    -- Apply shadow effect if needed
    if window_pos and CONFIG.SIZES.DEPTH > 0 then
        local screen_coords = self:calculateButtonCoordinates(button, pos_x, pos_y, layout.width, window_pos)

        local flags = self:getRoundingFlags(button)

        -- Pre-compute shadow color if not cached
        if not button.cache.shadow_color then
            button.cache.shadow_color = COLOR_UTILS.toImGuiColor(CONFIG.COLORS.SHADOW)
        end

        self:renderShadow(
            draw_list,
            screen_coords.x1,
            screen_coords.y1,
            screen_coords.x2,
            screen_coords.y2,
            flags,
            button
        )
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
    if editing_mode and is_hovered then
        -- Render edit mode indicator
        self:renderEditMode(ctx, pos_x, pos_y, layout.width, text_color)
    else
        -- Render normal button content with updated parameter list (removed IconSelector)
        local icon_width =
            C.ButtonContent:renderIcon(
            ctx,
            button,
            pos_x,
            pos_y,
            icon_color,
            layout.width,
            button.cache.width and button.cache.width.extra_padding or 0
        )

        C.ButtonContent:renderText(
            ctx,
            button,
            pos_x,
            pos_y,
            text_color,
            layout.width,
            icon_width,
            button.cache.width and button.cache.width.extra_padding or 0
        )
    end

    button:markLayoutClean()

    return layout.width
end



function ButtonRenderer:renderShadow(draw_list, x1, y1, x2, y2, flags, button)
    if CONFIG.SIZES.DEPTH <= 0 then
        return
    end

    -- Use cached shadow color if available
    if not button.cache.shadow_color then
        button.cache.shadow_color = COLOR_UTILS.toImGuiColor(CONFIG.COLORS.SHADOW)
    end

    -- Get current scroll values
    local current_scroll_x = reaper.ImGui_GetScrollX(self.ctx)
    local current_scroll_y = reaper.ImGui_GetScrollY(self.ctx)

    -- Calculate scroll-adjusted coordinates
    local sx1 = x1 - current_scroll_x
    local sy1 = y1 - current_scroll_y
    local sx2 = x2 - current_scroll_x
    local sy2 = y2 - current_scroll_y

    reaper.ImGui_DrawList_AddRectFilled(
        draw_list,
        sx1 + CONFIG.SIZES.DEPTH,
        sy1 + CONFIG.SIZES.DEPTH,
        sx2 + CONFIG.SIZES.DEPTH,
        sy2 + CONFIG.SIZES.DEPTH,
        button.cache.shadow_color,
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
