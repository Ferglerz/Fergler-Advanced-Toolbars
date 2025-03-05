-- button_visuals.lua
local ColorUtils = require "color_utils"

local function determineStateKey(button)
    if button.is_toggled then 
        return "TOGGLED"
    elseif button.is_armed then
        return button.is_flashing and "ARMED_FLASH" or "ARMED"
    else
        return "NORMAL"
    end
end

local function determineMouseKey(is_hovered, is_clicked)
    if is_clicked then
        return "CLICKED"
    elseif is_hovered then
        return "HOVER"
    else
        return "NORMAL"
    end
end

local function renderShadow(r, draw_list, x1, y1, x2, y2, flags)
    if CONFIG.SIZES.DEPTH > 0 then
        r.ImGui_DrawList_AddRectFilled(
            draw_list,
            x1 + CONFIG.SIZES.DEPTH,
            y1 + CONFIG.SIZES.DEPTH,
            x2 + CONFIG.SIZES.DEPTH,
            y2 + CONFIG.SIZES.DEPTH,
            ColorUtils.hexToImGuiColor(CONFIG.COLORS.SHADOW),
            CONFIG.SIZES.ROUNDING,
            flags
        )
    end
end

local function getButtonColors(button, is_hovered, is_clicked, helpers)
    -- Determine state based on button properties
    local state_key = determineStateKey(button)
    
    -- Determine interaction state    
    local mouse_key = determineMouseKey(is_hovered, is_clicked)
    
    -- Get default colors from config
    local colors = {
        bg = CONFIG.COLORS[state_key].BG[mouse_key],
        border = CONFIG.COLORS[state_key].BORDER[mouse_key],
        icon = CONFIG.COLORS[state_key].ICON[mouse_key],
        text = CONFIG.COLORS[state_key].TEXT[mouse_key]
    }
    
    -- Always apply custom colors if they exist
    if button.custom_color then
        local mouse_key_lower = mouse_key:lower()
        
        -- Apply custom background color if it exists
        if button.custom_color.background then
            colors.bg = button.custom_color.background[mouse_key_lower] or button.custom_color.background.normal
        end
        
        -- Apply custom border color if it exists
        if button.custom_color.border then
            colors.border = button.custom_color.border[mouse_key_lower] or button.custom_color.border.normal
        end
        
        -- Apply custom text color if it exists
        if button.custom_color.text then
            colors.text = button.custom_color.text[mouse_key_lower] or button.custom_color.text.normal
        end
        
        -- Apply custom icon color if it exists
        if button.custom_color.icon then
            colors.icon = button.custom_color.icon[mouse_key_lower] or button.custom_color.icon.normal
        end
    end
    
    -- Convert all to ImGui colors
    return 
        ColorUtils.hexToImGuiColor(colors.bg),
        ColorUtils.hexToImGuiColor(colors.border),
        ColorUtils.hexToImGuiColor(colors.icon),
        ColorUtils.hexToImGuiColor(colors.text)
end

local function getRoundingFlags(r, button)
    if not CONFIG.UI.USE_GROUPING or button.is_alone then
        return r.ImGui_DrawFlags_RoundCornersAll()
    elseif button.is_section_start then
        return r.ImGui_DrawFlags_RoundCornersLeft()
    elseif button.is_section_end then
        return r.ImGui_DrawFlags_RoundCornersRight()
    end
    return r.ImGui_DrawFlags_RoundCornersNone()
end

local function renderBackground(r, draw_list, button, pos_x, pos_y, width, bg_color, border_color, window_pos)
    if not window_pos then
        return
    end

    local flags = getRoundingFlags(r, button)
    local x1 = window_pos.x + pos_x
    local y1 = window_pos.y + pos_y
    local x2 = x1 + width
    local y2 = y1 + CONFIG.SIZES.HEIGHT

    renderShadow(r, draw_list, x1, y1, x2, y2, flags)
    
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

local function renderTooltip(ctx, r, button, hover_time, button_state)
    if hover_time <= CONFIG.UI.HOVER_DELAY then
        return
    end

    local fade_progress = math.min((hover_time - CONFIG.UI.HOVER_DELAY) / 0.5, 1)
    local command_id = button_state:getCommandID(button.id)
    local action_name = command_id and r.CF_GetCommandText(0, command_id)

    if action_name and action_name ~= "" then
        r.ImGui_BeginTooltip(ctx)
        r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_Alpha(), fade_progress)
        r.ImGui_Text(ctx, action_name)
        r.ImGui_PopStyleVar(ctx)
        r.ImGui_EndTooltip(ctx)
    end
end

local function renderSeparator(ctx, r, pos_x, pos_y, width, window_pos, draw_list)
    if not window_pos then
        return width
    end

    local handle_height = CONFIG.SIZES.HEIGHT * 0.5
    local handle_y = pos_y + (CONFIG.SIZES.HEIGHT - handle_height) / 2
    local handle_color = ColorUtils.hexToImGuiColor(CONFIG.COLORS.BORDER)

    r.ImGui_DrawList_AddRectFilled(
        draw_list,
        window_pos.x + pos_x + 2,
        window_pos.y + handle_y,
        window_pos.x + pos_x + width - 2,
        window_pos.y + handle_y + handle_height,
        handle_color
    )

    r.ImGui_SetCursorPos(ctx, pos_x, pos_y)
    r.ImGui_InvisibleButton(ctx, "##separator", width, CONFIG.SIZES.HEIGHT)
    
    return width
end

return {
    renderTooltip = renderTooltip,
    renderSeparator = renderSeparator,
    getButtonColors = getButtonColors,
    renderBackground = renderBackground
}