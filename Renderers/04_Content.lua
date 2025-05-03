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

function ButtonContent:renderIcon(ctx, button, pos_x, pos_y, icon_font_selector, icon_color, total_width, extra_padding)
    local icon_width = 0
    local show_text = not (button.hide_label or CONFIG.UI.HIDE_ALL_LABELS)
    local max_text_width = show_text and DIM_UTILS.calculateTextWidth(ctx, button.display_text, nil) or 0
    local pos_adjustment = extra_padding > 0 and (not show_text or max_text_width <= 0) and extra_padding / 2 or 0

    if button.icon_char then
        -- Get the correct icon font for this button
        local icon_font = self:loadIconFont(button.icon_font)
        
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
        end
    elseif button.icon_path then
        C.IconManager:loadButtonIcon(button)
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