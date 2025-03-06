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
    local state_key = determineStateKey(button)
    local mouse_key = determineMouseKey(is_hovered, is_clicked)
    local mouse_key_lower = mouse_key:lower()
    
    local colors = {
        background = CONFIG.COLORS[state_key].BG[mouse_key],
        border = CONFIG.COLORS[state_key].BORDER[mouse_key],
        icon = CONFIG.COLORS[state_key].ICON[mouse_key],
        text = CONFIG.COLORS[state_key].TEXT[mouse_key]
    }
    
    if button.custom_color and state_key == "NORMAL" then
        for key, value in pairs(button.custom_color) do
            colors[key] = value[mouse_key_lower] or value.normal
        end
    end
    
    return
        ColorUtils.hexToImGuiColor(colors.background),
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
    
    -- Use cached position coordinates if they're valid
    local screen_coords = button.screen_coords
    local recalculate = not screen_coords or 
                        screen_coords.window_x ~= window_pos.x or 
                        screen_coords.window_y ~= window_pos.y or
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
    
    local x1, y1, x2, y2 = screen_coords.x1, screen_coords.y1, screen_coords.x2, screen_coords.y2
    
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