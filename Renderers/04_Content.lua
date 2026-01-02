-- Renderers/04_Content.lua
local ButtonContent = {}
ButtonContent.__index = ButtonContent

function ButtonContent.new()
    local self = setmetatable({}, ButtonContent)

    return self
end

function ButtonContent:calculateIconX(pos_x, show_text, max_text_width, total_width, extra_padding, icon_width, padding, pos_adjustment)
    if show_text and max_text_width > 0 then
        return pos_x + math.max((total_width - extra_padding - (icon_width + padding + max_text_width)) / 2, padding)
    end
    return pos_x + (total_width - extra_padding - icon_width) / 2 + pos_adjustment
end

function ButtonContent:calculateTextX(base_x, text_width, available_width, alignment)
    if text_width >= available_width then return base_x end
    
    local offset = available_width - text_width
    if alignment == "center" then
        return base_x + (offset / 2)
    elseif alignment == "right" then
        return base_x + offset
    end
    return base_x
end

function ButtonContent:splitTextIntoLines(text)
    local lines = {}
    for line in text:gmatch("[^\n]+") do
        table.insert(lines, line)
    end
    return lines
end

function ButtonContent:ensureTextCache(button)
    -- Ensure button has cache table
    CACHE_UTILS.ensureButtonCache(button)
    
    -- Ensure text cache exists and return it
    return CACHE_UTILS.ensureButtonCacheSubtable(button, "text")
end

function ButtonContent:loadIconFont(font_path_or_index)
    local font = nil
    
    if type(font_path_or_index) == "number" then
        font = ICON_FONTS[font_path_or_index].font
    else
        for i = 1, #ICON_FONTS do
            local base_name = UTILS.getBaseFontName(font_path_or_index)
            if UTILS.getBaseFontName(ICON_FONTS[i].path) == base_name  then
                font = ICON_FONTS[i].font
                break
            end
        end
    end

    return font
end

function ButtonContent:calculateTextWidth(ctx, text, font)
    local max_width = 0
    
    if not text then
        return 0  
    end
    
    local pushed_font = false
    if font then
        reaper.ImGui_PushFont(ctx, font, CONFIG.SIZES.TEXT)
        pushed_font = true
    else
        -- No specific font provided, but we need button text size for accurate calculations
        -- Get the current font and push it with button text size
        local current_font = reaper.ImGui_GetFont(ctx)
        if current_font then
            reaper.ImGui_PushFont(ctx, current_font, CONFIG.SIZES.TEXT)
            pushed_font = true
        end
    end
    
    -- Split and cache the lines
    local lines = {}
    for line in text:gmatch("[^\n]+") do
        local line_width = reaper.ImGui_CalcTextSize(ctx, line)
        table.insert(lines, {text = line, width = line_width})
        max_width = math.max(max_width, line_width)
    end
    
    if pushed_font then
        reaper.ImGui_PopFont(ctx)
    end
    
    return max_width, lines
end

-- Create render parameters object for icon
function ButtonContent:createIconParams(ctx, button, pos_x, pos_y, icon_font_selector, icon_color, total_width, extra_padding, coords, draw_list)
    return {
        ctx = ctx,
        button = button,
        position = {x = pos_x, y = pos_y},
        icon_font_selector = icon_font_selector,
        icon_color = icon_color,
        total_width = total_width,
        extra_padding = extra_padding,
        coords = coords,
        draw_list = draw_list,
        show_text = BUTTON_UTILS.shouldShowText(button)
    }
end

function ButtonContent:renderIcon(ctx, button, pos_x, pos_y, icon_font_selector, icon_color, total_width, extra_padding, coords, draw_list)
    local params = self:createIconParams(ctx, button, pos_x, pos_y, icon_font_selector, icon_color, total_width, extra_padding, coords, draw_list)
    return self:renderIconWithParams(params)
end

-- Render icon (using params object)
function ButtonContent:renderIconWithParams(params)
    local icon_width = 0
    
    -- Initialize and get text cache in one operation
    local text_cache = self:ensureTextCache(params.button)
    
    -- Calculate or get cached text width
    if text_cache.width == nil then
        text_cache.width = params.show_text and self:calculateTextWidth(params.ctx, params.button.display_text) or 0
    end
    local max_text_width = text_cache.width
    
    local pos_adjustment = params.extra_padding > 0 and (not params.show_text or max_text_width <= 0) and params.extra_padding / 2 or 0

    if params.button.icon_char then
        -- Check cache first, then load if needed
        if not params.button.cache.icon_font or params.button.cache.icon_font.path ~= params.button.icon_font then
            params.button.cache.icon_font = {
                path = params.button.icon_font,
                font = self:loadIconFont(params.button.icon_font)
            }
        end
        local icon_font = params.button.cache.icon_font.font
        
        if icon_font then
            reaper.ImGui_PushFont(params.ctx, icon_font, CONFIG.ICON_FONT.SIZE)
            local char_width = reaper.ImGui_CalcTextSize(params.ctx, params.button.icon_char)
            local icon_x = self:calculateIconX(params.position.x, params.show_text, max_text_width, params.total_width, params.extra_padding, char_width, CONFIG.ICON_FONT.PADDING, pos_adjustment)
            local icon_y = (params.position.y + CONFIG.SIZES.HEIGHT/ 2 ) - CONFIG.ICON_FONT.SIZE / 4

            local draw_x, draw_y = params.coords:relativeToDrawList(icon_x, icon_y)
            reaper.ImGui_DrawList_AddText(params.draw_list, draw_x, draw_y, params.icon_color, params.button.icon_char)
            reaper.ImGui_PopFont(params.ctx)

            icon_width = char_width + (params.show_text and max_text_width > 0 and CONFIG.ICON_FONT.PADDING or 0)
        end
    elseif params.button.icon_path then
        -- Ensure icon is loaded and cached
        C.IconManager:loadButtonIcon(params.button)
        
        -- Get icon from cache
        if params.button.cache.icon and params.button.cache.icon.texture and params.button.cache.icon.dimensions then
            local dims = params.button.cache.icon.dimensions
            local icon_x = self:calculateIconX(params.position.x, params.show_text, max_text_width, params.total_width, params.extra_padding, dims.width, CONFIG.ICON_FONT.PADDING, pos_adjustment)
            local icon_y = params.position.y + (CONFIG.SIZES.HEIGHT - dims.height) / 2

            reaper.ImGui_SetCursorPos(params.ctx, icon_x, icon_y)
            reaper.ImGui_Image(params.ctx, params.button.cache.icon.texture, dims.width, dims.height)

            icon_width = dims.width + (params.show_text and max_text_width > 0 and CONFIG.ICON_FONT.PADDING or 0)
        end
    end

    return icon_width
end

-- Create render parameters object for text
function ButtonContent:createTextParams(ctx, button, pos_x, pos_y, text_color, width, icon_width, extra_padding, editing_mode, coords, draw_list)
    return {
        ctx = ctx,
        button = button,
        position = {x = pos_x, y = pos_y},
        text_color = text_color,
        width = width,
        icon_width = icon_width,
        extra_padding = extra_padding,
        editing_mode = editing_mode,
        coords = coords,
        draw_list = draw_list
    }
end

function ButtonContent:renderText(ctx, button, pos_x, pos_y, text_color, width, icon_width, extra_padding, editing_mode, coords, draw_list)
    local params = self:createTextParams(ctx, button, pos_x, pos_y, text_color, width, icon_width, extra_padding, editing_mode, coords, draw_list)
    self:renderTextWithParams(params)
end

-- Render text (using params object)
function ButtonContent:renderTextWithParams(params)
    if not BUTTON_UTILS.shouldShowText(params.button) then return end

    -- Initialize text cache
    local text_cache = self:ensureTextCache(params.button)
    
    -- Determine what text to display
    local display_text = params.button.display_text
    if params.editing_mode and BUTTON_UTILS.hasWidgetName(params.button) then
        display_text = params.button.widget.name
    end
    
    -- Calculate lines for the current text (don't cache in edit mode since text changes)
    local lines = {}
    if params.editing_mode and BUTTON_UTILS.hasWidgetName(params.button) then
        -- Use widget name, calculate fresh
        local split_text = display_text:gsub("\\n", "\n")
        local _, calculated_lines = self:calculateTextWidth(params.ctx, split_text)
        lines = calculated_lines or {}
    else
        -- Use cached lines or calculate them for normal display
        if not text_cache.lines then
            local split_text = params.button.display_text:gsub("\\n", "\n")
            local _, calculated_lines = self:calculateTextWidth(params.ctx, split_text )
            text_cache.lines = calculated_lines or {}
        end
        lines = text_cache.lines
    end
    
    local line_height = reaper.ImGui_GetTextLineHeight(params.ctx)
    local text_start_y = params.position.y + (CONFIG.SIZES.HEIGHT - line_height * #lines) / 2
    local available_width = params.width - (params.extra_padding or 0) - (CONFIG.ICON_FONT.PADDING * 2) - (params.icon_width or 0)
    local base_x = params.position.x + CONFIG.ICON_FONT.PADDING + (params.icon_width or 0)

    for i, line in ipairs(lines) do
        local text_x = self:calculateTextX(base_x, line.width, available_width, params.button.alignment)
        local draw_x, draw_y = params.coords:relativeToDrawList(text_x, text_start_y + (i - 1) * line_height)
        reaper.ImGui_DrawList_AddText(params.draw_list, draw_x, draw_y, params.text_color, line.text)
    end
end

return ButtonContent