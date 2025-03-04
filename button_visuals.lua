-- button_visuals.lua

local function getButtonColors(button, is_hovered, is_clicked, helpers)
    local use_state = button.is_toggled and "TOGGLED" 
        or button.is_flashing and "ARMED_FLASH"
        or button.is_armed and "ARMED"
        or "NORMAL"

    local mouse_state = is_clicked and "CLICKED"
        or is_hovered and "HOVER"
        or "NORMAL"

    -- Default colors from config
    local bg_color = CONFIG.COLORS[use_state].BG[mouse_state]
    local border_color = CONFIG.COLORS[use_state].BORDER[mouse_state]
    local icon_color = CONFIG.COLORS[use_state].ICON[mouse_state]
    local text_color = CONFIG.COLORS[use_state].TEXT[mouse_state]

    -- Apply custom colors if button is not toggled or armed
    if not (button.is_toggled or button.is_armed) and button.custom_color then
        -- Apply background color if defined
        if button.custom_color.background then
            bg_color =
                is_clicked and button.custom_color.background.clicked or 
                is_hovered and button.custom_color.background.hover or
                button.custom_color.background.normal
        end
        
        -- Apply border color if defined
        if button.custom_color.border then
            border_color =
                is_clicked and button.custom_color.border.clicked or 
                is_hovered and button.custom_color.border.hover or
                button.custom_color.border.normal
        end
        
        -- Apply text color if defined
        if button.custom_color.text then
            text_color =
                is_clicked and button.custom_color.text.clicked or 
                is_hovered and button.custom_color.text.hover or
                button.custom_color.text.normal
        end
        
        -- Apply icon color if defined
        if button.custom_color.icon then
            icon_color =
                is_clicked and button.custom_color.icon.clicked or 
                is_hovered and button.custom_color.icon.hover or
                button.custom_color.icon.normal
        end
    end

    return 
        helpers.hexToImGuiColor(bg_color),
        helpers.hexToImGuiColor(border_color),
        helpers.hexToImGuiColor(icon_color),
        helpers.hexToImGuiColor(text_color)
end

local function getRoundingFlags(r, button, group)
    if not CONFIG.UI.USE_GROUPING or button.is_alone then
        return r.ImGui_DrawFlags_RoundCornersAll()
    elseif button.is_section_start then
        return r.ImGui_DrawFlags_RoundCornersLeft()
    elseif button.is_section_end then
        return r.ImGui_DrawFlags_RoundCornersRight()
    end
    return r.ImGui_DrawFlags_RoundCornersNone()
end

local function renderBackground(r, draw_list, button, pos_x, pos_y, width, bg_color, border_color, window_pos, group, helpers)
    if not window_pos then
        return
    end

    local flags = getRoundingFlags(r, button, group)
    local x1 = window_pos.x + pos_x
    local y1 = window_pos.y + pos_y
    local x2 = x1 + width
    local y2 = y1 + CONFIG.SIZES.HEIGHT

    if CONFIG.SIZES.DEPTH > 0 then
        r.ImGui_DrawList_AddRectFilled(
            draw_list,
            x1 + CONFIG.SIZES.DEPTH,
            y1 + CONFIG.SIZES.DEPTH,
            x2 + CONFIG.SIZES.DEPTH,
            y2 + CONFIG.SIZES.DEPTH,
            helpers.hexToImGuiColor(CONFIG.COLORS.SHADOW),
            CONFIG.SIZES.ROUNDING,
            flags
        )
    end

    r.ImGui_DrawList_AddRectFilled(
        draw_list,
        x1,
        y1,
        x2,
        y2,
        bg_color,
        CONFIG.SIZES.ROUNDING,
        flags
    )

    r.ImGui_DrawList_AddRect(
        draw_list,
        x1,
        y1,
        x2,
        y2,
        border_color,
        CONFIG.SIZES.ROUNDING,
        flags
    )
end

local function renderTooltip(ctx, r, button, hover_time, button_manager)
    if hover_time <= CONFIG.UI.HOVER_DELAY then
        return
    end

    local fade_progress = math.min((hover_time - CONFIG.UI.HOVER_DELAY) / 0.5, 1)
    local action_name = r.CF_GetCommandText(0, button_manager:getCommandID(button.id))

    if action_name then
        r.ImGui_BeginTooltip(ctx)
        r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_Alpha(), fade_progress)
        r.ImGui_Text(ctx, action_name)
        r.ImGui_PopStyleVar(ctx)
        r.ImGui_EndTooltip(ctx)
    end
end

local function renderSeparator(ctx, r, pos_x, pos_y, width, window_pos, draw_list, helpers)
    local handle_height = CONFIG.SIZES.HEIGHT * 0.5
    local handle_y = pos_y + (CONFIG.SIZES.HEIGHT - handle_height) / 2
    local handle_color = helpers.hexToImGuiColor(CONFIG.COLORS.BORDER)

    r.ImGui_DrawList_AddRectFilled(
        draw_list,
        window_pos.x + pos_x + 2,
        window_pos.y + handle_y,
        window_pos.x + pos_x + width - 2,
        window_pos.y + handle_y + handle_height,
        handle_color
    )

    r.ImGui_SetCursorPos(ctx, pos_x, pos_y)
    return r.ImGui_InvisibleButton(ctx, "##separator", width, CONFIG.SIZES.HEIGHT)
end

return {
    renderTooltip = renderTooltip,
    renderSeparator = renderSeparator,
    getButtonColors = getButtonColors,
    renderBackground = renderBackground
}