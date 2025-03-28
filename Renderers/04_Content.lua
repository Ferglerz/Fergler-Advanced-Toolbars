-- Renderers/04_Content.lua
local ButtonContent = {}
ButtonContent.__index = ButtonContent

function ButtonContent.new()
    local self = setmetatable({}, ButtonContent)

    return self
end

function ButtonContent:calculateButtonWidth(ctx, button)

    -- Use cached width if available
    if button.cached_width then
        return button.cached_width.total, button.cached_width.extra_padding
    end

    -- Check if button has a widget with a width specified
    if button.widget and button.widget.width then
        local extra_padding = 0
        if button.is_section_end or button.is_alone then
            extra_padding = math.floor((CONFIG.SIZES.ROUNDING - 8) / 4)
        end
        
        -- Cache the calculated width with widget width
        button.cached_width = {
            total = button.widget.width + extra_padding,
            extra_padding = extra_padding
        }
        
        return button.cached_width.total, button.cached_width.extra_padding
    end

    local max_text_width = 0
    if not (button.hide_label or CONFIG.UI.HIDE_ALL_LABELS) then
        max_text_width = DIM_UTILS.calculateTextWidth(ctx, button.display_text, nil)
    end

    local icon_width = 0
    if button.icon_char and button.icon_font then
        icon_width = CONFIG.ICON_FONT.WIDTH
    elseif button.icon_texture and button.icon_dimensions then
        icon_width = button.icon_dimensions.width
    end

    local total_width = 0
    if icon_width > 0 and max_text_width > 0 then
        total_width = math.max(CONFIG.SIZES.MIN_WIDTH, icon_width + CONFIG.ICON_FONT.PADDING + max_text_width)
    elseif icon_width > 0 then
        total_width = icon_width
    else
        total_width = math.max(CONFIG.SIZES.MIN_WIDTH, max_text_width)
    end

    local extra_padding = 0
    if button.is_section_end or button.is_alone then
        extra_padding = math.floor((CONFIG.SIZES.ROUNDING - 8) / 4)
    end

    -- Cache the calculated width
    button.cached_width = {
        total = total_width + (CONFIG.ICON_FONT.PADDING * 2) + extra_padding,
        extra_padding = extra_padding
    }

    return button.cached_width.total, button.cached_width.extra_padding
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

function ButtonContent:getIconFont(ctx, button, icon_font_selector)
    -- If no icon character or button has an image icon, return nil
    if not button.icon_char or button.icon_path then
        return nil
    end
    
    -- If button doesn't have specified icon font, return nil
    if not button.icon_font then
        return nil
    end
    
    -- Load the custom font if we have an icon_font_selector
    if icon_font_selector then
        -- Find the font index based on the base name (ignoring numeric suffix)
        local base_font_name = UTILS.getBaseFontName(button.icon_font)
        local font_index = UTILS.matchFontByBaseName(base_font_name, icon_font_selector.font_maps)
        
        -- If we found a matching font, try to load it
        if font_index then
            local font = icon_font_selector:loadFont(ctx, font_index)
            -- If the font wasn't loaded yet, schedule it for loading
            if not font then
                icon_font_selector.pending_font_index = font_index
            end
            return font
        end
    end
    
    -- Return nil if icon_font_selector isn't available or font not found
    return nil
end

function ButtonContent:renderIcon(ctx, button, pos_x, pos_y, icon_font_selector, icon_color, total_width, button_manager, extra_padding)
    local icon_width = 0
    local show_text = not (button.hide_label or CONFIG.UI.HIDE_ALL_LABELS)
    local max_text_width = show_text and DIM_UTILS.calculateTextWidth(ctx, button.display_text, nil) or 0
    local pos_adjustment = extra_padding > 0 and (not show_text or max_text_width <= 0) and extra_padding / 2 or 0

    if button.icon_char then
        -- Get the correct icon font for this button
        local icon_font = self:getIconFont(ctx, button, icon_font_selector)
        
        if icon_font then
            reaper.ImGui_PushFont(ctx, icon_font)
            local char_width = reaper.ImGui_CalcTextSize(ctx, button.icon_char)
            local icon_x = self:calculateIconX(pos_x, show_text, max_text_width, total_width, extra_padding, char_width, CONFIG.ICON_FONT.PADDING, pos_adjustment)
            local icon_y = pos_y + (CONFIG.SIZES.HEIGHT / 2) - (reaper.ImGui_GetTextLineHeight(ctx) / 2)

            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), icon_color)
            reaper.ImGui_SetCursorPos(ctx, icon_x, icon_y)
            reaper.ImGui_Text(ctx, button.icon_char)
            reaper.ImGui_PopStyleColor(ctx)
            reaper.ImGui_PopFont(ctx)

            icon_width = char_width + (show_text and max_text_width > 0 and CONFIG.ICON_FONT.PADDING or 0)
        elseif button.icon_font and icon_font_selector then
            -- The custom font is not loaded yet, schedule it for loading
            -- Make sure we pass a pending_font_index to the font selector
            for i, font_map in ipairs(icon_font_selector.font_maps or {}) do
                if font_map.path == button.icon_font then
                    icon_font_selector.pending_font_index = i
                    break
                end
            end
        end
    elseif button.icon_path then
        -- Existing code for image icons
        button_manager:loadIcon(button)
        if button.icon_texture and button.icon_dimensions then
            local dims = button.icon_dimensions
            local icon_x = self:calculateIconX(pos_x, show_text, max_text_width, total_width, extra_padding, dims.width, CONFIG.ICON_FONT.PADDING, pos_adjustment)
            local icon_y = pos_y + (CONFIG.SIZES.HEIGHT - dims.height) / 2

            reaper.ImGui_SetCursorPos(ctx, icon_x, icon_y)
            reaper.ImGui_Image(ctx, button.icon_texture, dims.width, dims.height)

            icon_width = dims.width + (show_text and max_text_width > 0 and CONFIG.ICON_FONT.PADDING or 0)
        end
    end

    return icon_width
end

function ButtonContent:renderText(ctx, button, pos_x, pos_y, text_color, width, icon_width, extra_padding)
    if button.hide_label or CONFIG.UI.HIDE_ALL_LABELS then return end

    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), text_color)
    local lines = self:splitTextIntoLines(button.display_text:gsub("\\n", "\n"))
    local line_height = reaper.ImGui_GetTextLineHeight(ctx)
    local text_start_y = pos_y + (CONFIG.SIZES.HEIGHT - line_height * #lines) / 2
    local available_width = width - extra_padding - (CONFIG.ICON_FONT.PADDING * 2) - (icon_width or 0)
    local base_x = pos_x + CONFIG.ICON_FONT.PADDING + (icon_width or 0)

    for i, line in ipairs(lines) do
        local text_width = reaper.ImGui_CalcTextSize(ctx, line)
        local text_x = self:calculateTextX(base_x, text_width, available_width, button.alignment)
        reaper.ImGui_SetCursorPos(ctx, text_x, text_start_y + (i - 1) * line_height)
        reaper.ImGui_Text(ctx, line)
    end

    reaper.ImGui_PopStyleColor(ctx)
end

return ButtonContent