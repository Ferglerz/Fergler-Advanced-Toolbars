-- Utils/Core/color/theme.lua

local convert = require("Utils.Core.color.convert")

local M = {}

function M.getCachedColor(state_key, color_type, mouse_key)
    if CONFIG_MANAGER then
        local cached = CONFIG_MANAGER:getCachedColorSafe(state_key, color_type, mouse_key)
        if cached then
            return cached
        end
    end

    return convert.toImGuiColor(CONFIG.COLORS[state_key][color_type][mouse_key])
end

function M.applyUserColors(baseColors, userColors)
    local result = {}
    for key, value in pairs(baseColors) do
        result[key] = value
    end

    for key, value in pairs(userColors) do
        if key == "background" or key == "border" or key == "icon" or key == "text" then
            result[key] = value
        end
    end

    return result
end

function M.applyHSVOffset(baseColor, saturationOffset, valueOffset)
    local hsv = convert.toHSV(baseColor)

    hsv.s = math.max(0, math.min(1, hsv.s + saturationOffset))
    hsv.v = math.max(0, math.min(1, hsv.v + valueOffset))

    return convert.toHex(convert.toImGuiColor(convert.fromHSV(hsv)))
end

function M.calculateBorderFromBackground(backgroundColor, borderOffset)
    return M.applyHSVOffset(backgroundColor, borderOffset.saturation, borderOffset.value)
end

function M.calculateHSVOffset(baseColor, targetColor)
    local baseHSV = convert.toHSV(baseColor)
    local targetHSV = convert.toHSV(targetColor)

    return {
        saturation = targetHSV.s - baseHSV.s,
        value = targetHSV.v - baseHSV.v
    }
end

function M.getDerivedColors(baseColor, configBaseColor, configHoverColor, configClickedColor)
    local baseHSV = convert.toHSV(baseColor)
    local configBaseHSV = convert.toHSV(configBaseColor)
    local configHoverHSV = convert.toHSV(configHoverColor)
    local configClickedHSV = convert.toHSV(configClickedColor)

    local hoverValueDiff = configHoverHSV.v - configBaseHSV.v
    local clickedValueDiff = configClickedHSV.v - configBaseHSV.v

    local hoverHSV = {
        h = baseHSV.h,
        s = baseHSV.s,
        v = math.max(0, math.min(1, baseHSV.v + hoverValueDiff))
    }

    local clickedHSV = {
        h = baseHSV.h,
        s = baseHSV.s,
        v = math.max(0, math.min(1, baseHSV.v + clickedValueDiff))
    }

    local hoverColor = convert.toHex(convert.toImGuiColor(convert.fromHSV(hoverHSV)))
    local clickedColor = convert.toHex(convert.toImGuiColor(convert.fromHSV(clickedHSV)))

    return hoverColor, clickedColor
end

function M.getButtonColors(button, state_key, mouse_key)
    local mouse_key_lower = mouse_key:lower()

    if not button.cache.colors then
        button.cache.colors = {}
    end

    local cache_key = state_key .. "_" .. mouse_key_lower

    if button.cache.colors[cache_key] then
        return button.cache.colors[cache_key].background,
               button.cache.colors[cache_key].border,
               button.cache.colors[cache_key].icon,
               button.cache.colors[cache_key].text
    end

    local colors = {
        background = CONFIG.COLORS[state_key].BG[mouse_key],
        border = CONFIG.COLORS[state_key].BORDER[mouse_key],
        icon = CONFIG.COLORS[state_key].ICON[mouse_key],
        text = CONFIG.COLORS[state_key].TEXT[mouse_key]
    }

    if not button.custom_color and button.user_colors then
        if button.user_colors[mouse_key_lower] then
            colors = M.applyUserColors(colors, button.user_colors[mouse_key_lower])
        end

        if button.user_colors.all then
            colors = M.applyUserColors(colors, button.user_colors.all)
        end
    end

    if button.custom_color and state_key == "NORMAL" then
        if button.custom_color.background and button.custom_color.background.normal then
            colors.background = button.custom_color.background.normal
        end
        if button.custom_color.border and button.custom_color.border.normal then
            colors.border = button.custom_color.border.normal
        end
        if button.custom_color.icon and button.custom_color.icon.normal then
            colors.icon = button.custom_color.icon.normal
        end
        if button.custom_color.text and button.custom_color.text.normal then
            colors.text = button.custom_color.text.normal
        end

        if mouse_key_lower == "hover" and button.custom_color.hover then
            if button.custom_color.hover.background then
                colors.background = button.custom_color.hover.background
            end
            if button.custom_color.hover.border then
                colors.border = button.custom_color.hover.border
            end
        elseif mouse_key_lower == "clicked" and button.custom_color.active then
            if button.custom_color.active.background then
                colors.background = button.custom_color.active.background
            end
            if button.custom_color.active.border then
                colors.border = button.custom_color.active.border
            end
        end
    end

    if CONFIG.COLOR_SETTINGS and CONFIG.COLOR_SETTINGS.LINK_BG_BORDER and button.border_offset then
        if button.border_offset.saturation ~= 0 or button.border_offset.value ~= 0 then
            colors.border = M.applyHSVOffset(colors.background, button.border_offset.saturation, button.border_offset.value)
        end
    end

    local bg_color, border_color, icon_color, text_color

    if not button.custom_color and not button.user_colors and
       (not button.border_offset or (button.border_offset.saturation == 0 and button.border_offset.value == 0)) then
        bg_color = M.getCachedColor(state_key, "BG", mouse_key)
        border_color = M.getCachedColor(state_key, "BORDER", mouse_key)
        icon_color = M.getCachedColor(state_key, "ICON", mouse_key)
        text_color = M.getCachedColor(state_key, "TEXT", mouse_key)
    else
        bg_color = convert.toImGuiColor(colors.background)
        border_color = convert.toImGuiColor(colors.border)
        icon_color = convert.toImGuiColor(colors.icon)
        text_color = convert.toImGuiColor(colors.text)
    end

    button.cache.colors[cache_key] = {
        background = bg_color,
        border = border_color,
        icon = icon_color,
        text = text_color
    }

    return bg_color, border_color, icon_color, text_color
end

function M.dimmedText(base_color, alpha)
    return convert.setAlpha(base_color, alpha or 0x80)
end

function M.groupLabelColor()
    return convert.toImGuiColor(CONFIG.COLORS.GROUP.LABEL)
end

function M.applyAlphaFactor(color, factor)
    return convert.modulateAlpha(color, factor)
end

return M
