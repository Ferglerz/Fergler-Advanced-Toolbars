-- button_content.lua

local function calculateButtonWidth(ctx, button, icon_font, helpers)
    local max_text_width = 0
    if not (button.hide_label or CONFIG.UI.HIDE_ALL_LABELS) then
        max_text_width = helpers.calculateTextWidth(ctx, button.display_text, nil)
    end

    local icon_width = 0
    if button.icon_char and icon_font then
        icon_width = helpers.calculateTextWidth(ctx, button.icon_char, icon_font)
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

    return total_width + (CONFIG.ICON_FONT.PADDING * 2)
end

local function renderIcon(ctx, r, button, pos_x, pos_y, icon_font, icon_color, total_width, button_manager, helpers)
    local icon_width = 0
    local show_text = not (button.hide_label or CONFIG.UI.HIDE_ALL_LABELS)
    local max_text_width = show_text and helpers.calculateTextWidth(ctx, button.display_text, nil) or 0

    if button.icon_char and icon_font then
        r.ImGui_PushFont(ctx, icon_font)
        local char_width = r.ImGui_CalcTextSize(ctx, button.icon_char)
        local icon_x = pos_x + (show_text and max_text_width > 0 and
            math.max((total_width - (char_width + CONFIG.ICON_FONT.PADDING + max_text_width)) / 2, CONFIG.ICON_FONT.PADDING) or
            (total_width - char_width) / 2)
        local icon_y = pos_y + (CONFIG.SIZES.HEIGHT / 2)

        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), icon_color)
        r.ImGui_SetCursorPos(ctx, icon_x, icon_y)
        r.ImGui_Text(ctx, button.icon_char)
        r.ImGui_PopStyleColor(ctx)
        r.ImGui_PopFont(ctx)

        icon_width = char_width + (show_text and max_text_width > 0 and CONFIG.ICON_FONT.PADDING or 0)
    elseif button.icon_path then
        button_manager:loadIcon(button)
        if button.icon_texture and button.icon_dimensions then
            local dims = button.icon_dimensions
            local icon_x = pos_x + (show_text and max_text_width > 0 and
                math.max((total_width - (dims.width + CONFIG.ICON_FONT.PADDING + max_text_width)) / 2, CONFIG.ICON_FONT.PADDING) or
                (total_width - dims.width) / 2)
            local icon_y = pos_y + (CONFIG.SIZES.HEIGHT - dims.height) / 2

            r.ImGui_SetCursorPos(ctx, icon_x, icon_y)
            r.ImGui_Image(ctx, button.icon_texture, dims.width, dims.height)

            icon_width = dims.width + (show_text and max_text_width > 0 and CONFIG.ICON_FONT.PADDING or 0)
        end
    end

    return icon_width
end

local function renderText(ctx, r, button, pos_x, pos_y, text_color, width, icon_width)
    if button.hide_label or CONFIG.UI.HIDE_ALL_LABELS then
        return
    end

    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), text_color)
    local text = button.display_text:gsub("\\n", "\n")
    local lines = {}
    for line in text:gmatch("[^\n]+") do
        table.insert(lines, line)
    end

    local line_height = r.ImGui_GetTextLineHeight(ctx)
    local text_start_y = pos_y + (CONFIG.SIZES.HEIGHT - line_height * #lines) / 2
    local available_width = width - (CONFIG.ICON_FONT.PADDING * 2) - (icon_width or 0)
    local base_x = pos_x + CONFIG.ICON_FONT.PADDING + (icon_width or 0)

    for i, line in ipairs(lines) do
        local text_width = r.ImGui_CalcTextSize(ctx, line)
        local text_x = base_x

        if text_width < available_width then
            local offset = available_width - text_width
            if button.alignment == "center" then
                text_x = text_x + (offset / 2)
            elseif button.alignment == "right" then
                text_x = text_x + offset
            end
        end

        r.ImGui_SetCursorPos(ctx, text_x, text_start_y + (i - 1) * line_height)
        r.ImGui_Text(ctx, line)
    end

    r.ImGui_PopStyleColor(ctx)
end

return {
    calculateButtonWidth = calculateButtonWidth,
    renderIcon = renderIcon,
    renderText = renderText
}