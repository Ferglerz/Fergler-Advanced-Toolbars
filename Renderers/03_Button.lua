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

    -- Apply scroll offset to match widget positioning
    x1, y1 = UTILS.applyScrollOffset(self.ctx, x1, y1)
    x2, y2 = UTILS.applyScrollOffset(self.ctx, x2, y2)

    -- Render button background and border
    reaper.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, bg_color, CONFIG.SIZES.ROUNDING, flags)
    reaper.ImGui_DrawList_AddRect(draw_list, x1, y1, x2, y2, border_color, CONFIG.SIZES.ROUNDING, flags)
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

    C.Interactions:handleRightClick(ctx, button, is_hovered, editing_mode)

    -- Reset right-clicked state when mouse button is released
    if button.is_right_clicked and reaper.ImGui_IsMouseReleased(ctx, 1) then
        button.is_right_clicked = false
    end

    -- Get colors based on state
    local state_key = C.Interactions:determineStateKey(button)
    local mouse_key = C.Interactions:determineMouseKey(is_hovered, is_clicked)
    local bg_color, border_color, icon_color, text_color = COLOR_UTILS.getButtonColors(button, state_key, mouse_key)

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
    if editing_mode and is_hovered then
        -- Render edit mode indicator
        self:renderEditMode(ctx, pos_x, pos_y, layout.width, text_color)
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

function ButtonRenderer:renderShadow(draw_list, x1, y1, x2, y2, flags)
    if CONFIG.SIZES.DEPTH > 0 then
        local sx1, sy1 = UTILS.applyScrollOffset(self.ctx, x1, y1)
        local sx2, sy2 = UTILS.applyScrollOffset(self.ctx, x2, y2)

        reaper.ImGui_DrawList_AddRectFilled(
            draw_list,
            sx1 + CONFIG.SIZES.DEPTH,
            sy1 + CONFIG.SIZES.DEPTH,
            sx2 + CONFIG.SIZES.DEPTH,
            sy2 + CONFIG.SIZES.DEPTH,
            COLOR_UTILS.toImGuiColor(CONFIG.COLORS.SHADOW),
            CONFIG.SIZES.ROUNDING,
            flags
        )
    end
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
