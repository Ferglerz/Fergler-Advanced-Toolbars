-- Renderers/03_Button_separator.lua
-- Separator rendering; merged onto ButtonRenderer by 03_Button.lua

local Separator = {}

-- Get separator line color with caching
function Separator:getSeparatorLineColor(button, mouse_key, bg_color)
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
function Separator:renderSeparatorLine(draw_list, coords, button, rel_x, rel_y, width, line_color, is_vertical, is_dashed)
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

-- Create render parameters object for separator editing mode
function Separator:createSeparatorEditingParams(ctx, button, rel_x, rel_y, width, coords, draw_list, bg_color, border_color, icon_color, text_color, line_color, is_vertical)
    return {
        ctx = ctx,
        button = button,
        position = {x = rel_x, y = rel_y},
        width = width,
        coords = coords,
        draw_list = draw_list,
        colors = {
            bg = bg_color,
            border = border_color,
            icon = icon_color,
            text = text_color,
            line = line_color
        },
        is_vertical = is_vertical
    }
end

-- Render separator in editing mode
function Separator:renderSeparatorEditingMode(ctx, button, rel_x, rel_y, width, coords, draw_list, bg_color, border_color, icon_color, text_color, line_color, is_vertical)
    local params = self:createSeparatorEditingParams(ctx, button, rel_x, rel_y, width, coords, draw_list, bg_color, border_color, icon_color, text_color, line_color, is_vertical)
    self:renderSeparatorEditingModeWithParams(params)
end

-- Render separator in editing mode (using params object)
function Separator:renderSeparatorEditingModeWithParams(params)
    -- Render background if not transparent
    if BUTTON_UTILS.hasAlpha(params.colors.bg) then  -- Check alpha channel
        local separator_height = params.is_vertical and BUTTON_UTILS.getSeparatorHeight(params.button, true) or CONFIG.SIZES.HEIGHT
        local x1, y1 = params.coords:relativeToDrawList(params.position.x, params.position.y)
        local x2, y2 = params.coords:relativeToDrawList(params.position.x + params.width, params.position.y + separator_height)
        reaper.ImGui_DrawList_AddRectFilled(params.draw_list, x1, y1, x2, y2, params.colors.bg, CONFIG.SIZES.ROUNDING)
        
        -- Render border if not transparent
        if BUTTON_UTILS.hasAlpha(params.colors.border) then
            reaper.ImGui_DrawList_AddRect(params.draw_list, x1, y1, x2, y2, params.colors.border, CONFIG.SIZES.ROUNDING)
        end
    end
    
    -- Render dashed line
    self:renderSeparatorLine(params.draw_list, params.coords, params.button, params.position.x, params.position.y, params.width, params.colors.line, params.is_vertical, true)
    
    -- Render text if not hidden and not default
    if BUTTON_UTILS.shouldDisplayText(params.button) then
        local text_params = C.ButtonContent:createTextParams(
            params.ctx,
            params.button,
            params.position.x,
            params.position.y,
            params.colors.text,
            params.width,
            0, -- no icon width
            0, -- no extra padding
            true, -- editing_mode
            params.coords,
            params.draw_list
        )
        C.ButtonContent:renderTextWithParams(text_params)
    end
    
    -- Render icon if present
    if BUTTON_UTILS.hasIcon(params.button) then
        local icon_params = C.ButtonContent:createIconParams(
            params.ctx,
            params.button,
            params.position.x,
            params.position.y,
            C.IconSelector,
            params.colors.icon,
            params.width,
            0,  -- no extra padding
            params.coords,
            params.draw_list
        )
        C.ButtonContent:renderIconWithParams(icon_params)
    end
end

-- Create render parameters object for separator normal mode
function Separator:createSeparatorNormalParams(ctx, button, rel_x, rel_y, width, coords, draw_list, text_color, line_color, is_vertical)
    return {
        ctx = ctx,
        button = button,
        position = {x = rel_x, y = rel_y},
        width = width,
        coords = coords,
        draw_list = draw_list,
        colors = {
            text = text_color,
            line = line_color
        },
        is_vertical = is_vertical
    }
end

-- Render separator in normal mode
function Separator:renderSeparatorNormalMode(ctx, button, rel_x, rel_y, width, coords, draw_list, text_color, line_color, is_vertical)
    local params = self:createSeparatorNormalParams(ctx, button, rel_x, rel_y, width, coords, draw_list, text_color, line_color, is_vertical)
    self:renderSeparatorNormalModeWithParams(params)
end

-- Render separator in normal mode (using params object)
function Separator:renderSeparatorNormalModeWithParams(params)
    -- Render solid line
    self:renderSeparatorLine(params.draw_list, params.coords, params.button, params.position.x, params.position.y, params.width, params.colors.line, params.is_vertical, false)
    
    -- Render text if not hidden and not default
    if BUTTON_UTILS.shouldDisplayText(params.button) then
        local text_params = C.ButtonContent:createTextParams(
            params.ctx,
            params.button,
            params.position.x,
            params.position.y,
            params.colors.text,
            params.width,
            0, -- no icon width
            0, -- no extra padding
            false, -- editing_mode
            params.coords,
            params.draw_list
        )
        C.ButtonContent:renderTextWithParams(text_params)
    end
end

-- Main separator rendering function (orchestration)
function Separator:renderSeparator(ctx, button, rel_x, rel_y, width, coords, draw_list, editing_mode, state_key, mouse_key, is_vertical, render_options)
    render_options = render_options or {}

    -- Get colors for separator
    local bg_color, border_color, icon_color, text_color = COLOR_UTILS.getButtonColors(button, state_key, mouse_key)

    -- Get special line color for separators with caching
    local line_color = self:getSeparatorLineColor(button, mouse_key, bg_color)

    if render_options.ghost_mode and self.applyGhostTint then
        bg_color = self:applyGhostTint(bg_color)
        border_color = self:applyGhostTint(border_color)
        icon_color = self:applyGhostTint(icon_color)
        text_color = self:applyGhostTint(text_color)
        line_color = self:applyGhostTint(line_color)
    end

    if editing_mode then
        self:renderSeparatorEditingMode(ctx, button, rel_x, rel_y, width, coords, draw_list, bg_color, border_color, icon_color, text_color, line_color, is_vertical)
    else
        self:renderSeparatorNormalMode(ctx, button, rel_x, rel_y, width, coords, draw_list, text_color, line_color, is_vertical)
    end
    
    return width
end

return Separator
