-- Renderers/03_Button.lua

local ButtonRenderer = {}
ButtonRenderer.__index = ButtonRenderer

function ButtonRenderer.new()
    local self = setmetatable({}, ButtonRenderer)
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
    local screen_coords = button.screen_coords
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

        button.screen_coords = screen_coords
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

    -- Render button background and border
    reaper.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, bg_color, CONFIG.SIZES.ROUNDING, flags)

    reaper.ImGui_DrawList_AddRect(draw_list, x1, y1, x2, y2, border_color, CONFIG.SIZES.ROUNDING, flags)
end

-- Render a separator instead of a button
function ButtonRenderer:renderSeparator(ctx, pos_x, pos_y, width, window_pos, draw_list, color_utils)
    if not window_pos then
        return width
    end

    local handle_height = CONFIG.SIZES.HEIGHT * 0.5
    local handle_y = pos_y + (CONFIG.SIZES.HEIGHT - handle_height) / 2
    local handle_color = color_utils.hexToImGuiColor(CONFIG.COLORS.BORDER)

    reaper.ImGui_DrawList_AddRectFilled(
        draw_list,
        window_pos.x + pos_x + 2,
        window_pos.y + handle_y,
        window_pos.x + pos_x + width - 2,
        window_pos.y + handle_y + handle_height,
        handle_color
    )

    reaper.ImGui_SetCursorPos(ctx, pos_x, pos_y)
    reaper.ImGui_InvisibleButton(ctx, "##separator", width, CONFIG.SIZES.HEIGHT)

    return width
end

function ButtonRenderer:renderButton(ctx, button, pos_x, pos_y, icon_font, window_pos, draw_list, editing_mode)
    -- Handle separators
    if button.is_separator then
        return self:renderSeparator(
            ctx,
            pos_x,
            pos_y,
            button.width or CONFIG.SIZES.SEPARATOR_WIDTH,
            window_pos,
            draw_list,
            COLOR_UTILS
        )
    end

    -- Calculate dimensions once
    local width, extra_padding = C.ButtonContent:calculateButtonWidth(ctx, button)

    -- Set up invisible button for interaction
    local clicked, is_hovered, is_clicked =
        C.Interactions:setupInteractionArea(ctx, pos_x, pos_y, width, CONFIG.SIZES.HEIGHT, button.id)

    -- Track hover and interactions
    local hover_changed = C.Interactions:handleHover(ctx, button, is_hovered, editing_mode)

    -- Handle left click
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

    -- Handle right click
    if is_hovered and reaper.ImGui_IsMouseClicked(ctx, 1) and not (button.widget and button.widget.type == "slider") then
        -- Check for command/ctrl modifier key
        local key_mods = reaper.ImGui_GetKeyMods(ctx)
        local is_cmd_down = (key_mods & reaper.ImGui_Mod_Ctrl()) ~= 0
    
        if is_cmd_down or editing_mode then
            -- Open settings menu on cmd+right click or in editing mode
            C.Interactions:showButtonSettings(button, button.parent_group)
            reaper.ImGui_OpenPopup(ctx, "button_settings_menu_" .. button.id)
        elseif button.right_click == "dropdown" then
            -- Show dropdown
            local x, y = reaper.ImGui_GetMousePos(ctx)
            C.Interactions:showDropdownMenu(ctx, button, {x = x, y = y})
        elseif button.right_click == "arm" then
            -- Toggle arm command
            C.ButtonManager:toggleArmCommand(button)
        end
    end

    -- Get colors based on state
    local state_key = C.Interactions:determineStateKey(button)
    local mouse_key = C.Interactions:determineMouseKey(is_hovered, is_clicked)
    local bg_color, border_color, icon_color, text_color = COLOR_UTILS.getButtonColors(button, state_key, mouse_key)

    -- Get button coordinates
    local screen_coords = self:calculateButtonCoordinates(button, pos_x, pos_y, width, window_pos)

    -- Apply shadow effect if needed
    if window_pos and CONFIG.SIZES.DEPTH > 0 then
        local flags = self:getRoundingFlags(button)
        self:renderShadow(draw_list, screen_coords.x1, screen_coords.y1, screen_coords.x2, screen_coords.y2, flags)
    end

    -- Render background
    self:renderBackground(draw_list, button, pos_x, pos_y, width, bg_color, border_color, window_pos)

    -- For widget buttons, delegate rendering to widgets module
    if button.widget and not editing_mode then
        local handled, width =
            C.WidgetRenderer:renderWidget(ctx, button, pos_x, pos_y, width, window_pos, draw_list)

        if handled then
            -- Only mark as clean if there's no hover transition happening
            if not hover_changed then
                button:markClean()
            else
                -- Keep button dirty during hover transitions
                button.is_dirty = true
            end

            return width
        end
    end

    -- Always render content based on mode
    if editing_mode and is_hovered then
        -- Render edit mode indicator
        self:renderEditMode(ctx, pos_x, pos_y, width, text_color)
    else
        -- Render normal button content
        local icon_width =
            C.ButtonContent:renderIcon(
            ctx,
            button,
            pos_x,
            pos_y,
            C.IconSelector,
            icon_color,
            width,
            extra_padding
        )

        C.ButtonContent:renderText(ctx, button, pos_x, pos_y, text_color, width, icon_width, extra_padding)
    end

    -- Only mark as clean if there's no hover transition happening
    if not hover_changed then
        button:markClean()
    else
        -- Keep button dirty during hover transitions
        button.is_dirty = true
    end

    return width
end

function ButtonRenderer:renderShadow(draw_list, x1, y1, x2, y2, flags)
    if CONFIG.SIZES.DEPTH > 0 then
        reaper.ImGui_DrawList_AddRectFilled(
            draw_list,
            x1 + CONFIG.SIZES.DEPTH,
            y1 + CONFIG.SIZES.DEPTH,
            x2 + CONFIG.SIZES.DEPTH,
            y2 + CONFIG.SIZES.DEPTH,
            COLOR_UTILS.hexToImGuiColor(CONFIG.COLORS.SHADOW),
            CONFIG.SIZES.ROUNDING,
            flags
        )
    end
end

-- Render edit mode indicator
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