-- Renderers/04_Content.lua
local ButtonContent = {}
ButtonContent.__index = ButtonContent

function ButtonContent.new()
    local self = setmetatable({}, ButtonContent)

    self.icon_font_cache = {}

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

function ButtonContent:loadIconFont(font_path_or_index)
    -- Check cache first
    local cache_key = tostring(font_path_or_index)
    if self.icon_font_cache[cache_key] then
        return self.icon_font_cache[cache_key]
    end
    
    local font = nil
    
    if type(font_path_or_index) == "number" then
        font = ICON_FONTS[font_path_or_index] and ICON_FONTS[font_path_or_index].font
    else
        -- Convert path to base name for matching
        local font_base_name = UTILS.getBaseFontName(font_path_or_index)
        
        -- Check if we already have a match for this base name in the cache
        for cached_key, cached_font in pairs(self.icon_font_cache) do
            local cached_base_name = UTILS.getBaseFontName(cached_key)
            if cached_base_name == font_base_name then
                self.icon_font_cache[cache_key] = cached_font -- Add alias to cache
                return cached_font
            end
        end
        
        -- No cache hit, look through all fonts
        for i = 1, #ICON_FONTS do
            if UTILS.getBaseFontName(ICON_FONTS[i].path) == font_base_name then
                font = ICON_FONTS[i].font
                break
            end
        end
    end
    
    -- Save to cache
    self.icon_font_cache[cache_key] = font
    
    return font
end

function ButtonContent:calculateTextWidth(ctx, text, font)
    local max_width = 0
    
    -- Add nil check for text parameter
    if not text then
        return 0  -- Return 0 width if text is nil
    end
    
    if font then
        reaper.ImGui_PushFont(ctx, font)
    end
    
    for line in text:gmatch("[^\n]+") do
        local line_width = reaper.ImGui_CalcTextSize(ctx, line)
        max_width = math.max(max_width, line_width)
    end
    
    if font then
        reaper.ImGui_PopFont(ctx)
    end
    
    return max_width
end

function ButtonContent:renderIcon(ctx, button, pos_x, pos_y, icon_color, total_width, extra_padding)
    local icon_width = 0
    local show_text = not (button.hide_label or CONFIG.UI.HIDE_ALL_LABELS)
    
    -- Cache text width calculation
    if not button.cache.text_width and button.display_text then
        button.cache.text_width = show_text and self.calculateTextWidth(ctx, button.display_text, nil) or 0
    end
    
    local max_text_width = button.cache.text_width or 0
    local pos_adjustment = extra_padding > 0 and (not show_text or max_text_width <= 0) and extra_padding / 2 or 0

    if button.icon_char then
        -- Use the already cached font (should be prepared before rendering)
        local icon_font = button.cache.icon.font
        
        if icon_font then
            reaper.ImGui_PushFont(ctx, icon_font)
            
            -- Cache the character width in icon_dimensions if needed
            if not button.cache.icon.dimensions then
                local char_width = reaper.ImGui_CalcTextSize(ctx, button.icon_char)
                button.cache.icon.dimensions = {
                    width = char_width,
                    height = reaper.ImGui_GetTextLineHeight(ctx)
                }
            end
            
            local char_width = button.cache.icon.dimensions.width
            local icon_x = self:calculateIconX(pos_x, show_text, max_text_width, total_width, extra_padding, char_width, CONFIG.ICON_FONT.PADDING, pos_adjustment)
            local icon_y = pos_y + (CONFIG.SIZES.HEIGHT / 2) - (button.cache.icon.dimensions.height / 2)

            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), icon_color)
            reaper.ImGui_SetCursorPos(ctx, icon_x, icon_y)
            reaper.ImGui_Text(ctx, button.icon_char)
            reaper.ImGui_PopStyleColor(ctx)
            reaper.ImGui_PopFont(ctx)

            icon_width = char_width + (show_text and max_text_width > 0 and CONFIG.ICON_FONT.PADDING or 0)
        end
    elseif button.icon_path then
        -- Icon texture should already be loaded by the preparation step
        if button.cache.icon and button.cache.icon.texture and button.cache.icon.dimensions then
            local dims = button.cache.icon.dimensions
            local icon_x = self:calculateIconX(pos_x, show_text, max_text_width, total_width, extra_padding, dims.width, CONFIG.ICON_FONT.PADDING, pos_adjustment)
            local icon_y = pos_y + (CONFIG.SIZES.HEIGHT - dims.height) / 2

            reaper.ImGui_SetCursorPos(ctx, icon_x, icon_y)
            reaper.ImGui_Image(ctx, button.cache.icon.texture, dims.width, dims.height)

            icon_width = dims.width + (show_text and max_text_width > 0 and CONFIG.ICON_FONT.PADDING or 0)
        end
    end

    return icon_width
end

function ButtonContent:renderText(ctx, button, pos_x, pos_y, text_color, width, icon_width, extra_padding)
    if button.hide_label or CONFIG.UI.HIDE_ALL_LABELS then return end
    
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), text_color)
    
    -- Cache the split lines to avoid recalculating
    if not button.cache.lines or button.cache.lines.source_text ~= button.display_text then
        button.cache.lines = {
            source_text = button.display_text,
            lines = self:splitTextIntoLines(button.display_text:gsub("\\n", "\n"))
        }
    end
    
    local lines = button.cache.lines.lines
    local line_height = reaper.ImGui_GetTextLineHeight(ctx)
    local text_start_y = pos_y + (CONFIG.SIZES.HEIGHT - line_height * #lines) / 2
    local available_width = width - extra_padding - (CONFIG.ICON_FONT.PADDING * 2) - (icon_width or 0)
    local base_x = pos_x + CONFIG.ICON_FONT.PADDING + (icon_width or 0)
    
    -- Cache the line widths to avoid recalculating them
    if not button.cache.line_widths then
        button.cache.line_widths = {}
        for i, line in ipairs(lines) do
            button.cache.line_widths[i] = reaper.ImGui_CalcTextSize(ctx, line)
        end
    end
    
    for i, line in ipairs(lines) do
        local text_width = button.cache.line_widths[i]
        local text_x = self:calculateTextX(base_x, text_width, available_width, button.alignment)
        reaper.ImGui_SetCursorPos(ctx, text_x, text_start_y + (i - 1) * line_height)
        reaper.ImGui_Text(ctx, line)
    end
    
    reaper.ImGui_PopStyleColor(ctx)
end

return ButtonContent