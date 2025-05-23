-- Utils/color_utils.lua
local ColorUtils = {}

-- Core color conversion - all other conversions use this
function ColorUtils.toRGBA(color)
    -- Already in number format
    if type(color) == "number" then
        return {
            r = (color >> 24) & 0xFF,
            g = (color >> 16) & 0xFF,
            b = (color >> 8) & 0xFF,
            a = color & 0xFF
        }
    end
    
    -- Hex string format
    if type(color) == "string" then
        local hex = color:gsub("#", "")
        local r = tonumber(hex:sub(1, 2), 16)
        local g = tonumber(hex:sub(3, 4), 16)
        local b = tonumber(hex:sub(5, 6), 16)
        local a = tonumber(hex:sub(7, 8) or "FF", 16)
        
        if not r or not g or not b or not a then
            return {r = 255, g = 0, b = 0, a = 255} -- Default to red if parsing fails
        end
        
        return {r = r, g = g, b = b, a = a}
    end
    
    -- Table with RGBA components
    if type(color) == "table" and color.r and color.g and color.b then
        return {
            r = color.r,
            g = color.g,
            b = color.b,
            a = color.a or 255
        }
    end
    
    -- Default white
    return {r = 255, g = 255, b = 255, a = 255}
end

-- Convert from RGBA table to ImGui format (0xRRGGBBAA)
function ColorUtils.toImGuiColor(color)
    local rgba = ColorUtils.toRGBA(color)
    return (rgba.r << 24) | (rgba.g << 16) | (rgba.b << 8) | rgba.a
end

-- Convert from RGBA table to hex string
function ColorUtils.toHex(color)
    local rgba = ColorUtils.toRGBA(color)
    return string.format("#%02X%02X%02X%02X", rgba.r, rgba.g, rgba.b, rgba.a)
end

-- Convert REAPER's BGR format to RGBA table
function ColorUtils.reaperColorToRGBA(color)
    -- Extract RGB values assuming BGR format in REAPER
    local b = (color >> 16) & 0xFF
    local g = (color >> 8) & 0xFF
    local r = color & 0xFF
    
    return {r = r, g = g, b = b, a = 255}
end

-- Convert REAPER color to ImGui format
function ColorUtils.reaperColorToImGui(color)
    local rgba = ColorUtils.reaperColorToRGBA(color)
    -- Correct order for REAPER colors going to ImGui
    return (rgba.b << 24) | (rgba.g << 16) | (rgba.r << 8) | rgba.a
end

-- Convert RGBA to HSV
function ColorUtils.toHSV(color)
    local rgba = ColorUtils.toRGBA(color)
    local r, g, b = rgba.r / 255, rgba.g / 255, rgba.b / 255
    
    local max = math.max(r, g, b)
    local min = math.min(r, g, b) 
    local delta = max - min
    
    local h, s, v
    v = max
    
    if max == 0 then
        s = 0
    else
        s = delta / max
    end
    
    if delta == 0 then
        h = 0
    else
        if max == r then
            h = (g - b) / delta
            if g < b then
                h = h + 6
            end
        elseif max == g then
            h = (b - r) / delta + 2
        else
            h = (r - g) / delta + 4
        end
        h = h * 60
    end
    
    return {h = h, s = s, v = v}
end

-- Convert HSV to RGBA
function ColorUtils.fromHSV(hsv)
    if not hsv or not hsv.h or not hsv.s or not hsv.v then
        return {r = 255, g = 255, b = 255, a = 255}
    end
    
    local h, s, v = hsv.h, hsv.s, hsv.v
    local r, g, b
    
    if s == 0 then
        r, g, b = v, v, v
    else
        h = h / 60
        local i = math.floor(h)
        local f = h - i
        local p = v * (1 - s)
        local q = v * (1 - s * f)
        local t = v * (1 - s * (1 - f))
        
        if i == 0 then
            r, g, b = v, t, p
        elseif i == 1 then
            r, g, b = q, v, p
        elseif i == 2 then
            r, g, b = p, v, t
        elseif i == 3 then
            r, g, b = p, q, v
        elseif i == 4 then
            r, g, b = t, p, v
        else
            r, g, b = v, p, q
        end
    end
    
    return {
        r = math.floor(r * 255),
        g = math.floor(g * 255),
        b = math.floor(b * 255),
        a = 255
    }
end

-- Get button colors with consistent color handling
function ColorUtils.getButtonColors(button, state_key, mouse_key)
    local mouse_key_lower = mouse_key:lower()
    
    -- Initialize colors cache if needed
    if not button.cache.colors then
        button.cache.colors = {}
    end
    
    -- Create a composite cache key using both state and mouse state
    local cache_key = state_key .. "_" .. mouse_key_lower
    
    -- Check if we have these colors already cached
    if button.cache.colors[cache_key] then
        return button.cache.colors[cache_key].background,
               button.cache.colors[cache_key].border,
               button.cache.colors[cache_key].icon,
               button.cache.colors[cache_key].text
    end
    
    -- Calculate colors
    local colors = {
        background = CONFIG.COLORS[state_key].BG[mouse_key],
        border = CONFIG.COLORS[state_key].BORDER[mouse_key],
        icon = CONFIG.COLORS[state_key].ICON[mouse_key],
        text = CONFIG.COLORS[state_key].TEXT[mouse_key]
    }
    
    -- Apply user button colors if defined
    if button.user_colors then
        -- Check if we need to apply a specific mouse state color
        if button.user_colors[mouse_key_lower] then
            colors = ColorUtils.applyUserColors(colors, button.user_colors[mouse_key_lower])
        end
        
        -- Also check for general colors that apply to all states
        if button.user_colors.all then
            colors = ColorUtils.applyUserColors(colors, button.user_colors.all)
        end
    end
    
    -- Apply custom state overrides for this button
    if button.custom_colors and button.custom_colors[state_key] then
        local custom_state = button.custom_colors[state_key]
        
        -- Apply mouse-specific colors first if they exist
        if custom_state[mouse_key_lower] then
            colors = ColorUtils.applyUserColors(colors, custom_state[mouse_key_lower])
        end
        
        -- Then apply generic state colors that apply to all mouse states
        if custom_state.all then
            colors = ColorUtils.applyUserColors(colors, custom_state.all)
        end
    end
    
    -- Convert colors to ImGui format
    local bg_color = ColorUtils.toImGuiColor(colors.background)
    local border_color = ColorUtils.toImGuiColor(colors.border)
    local icon_color = ColorUtils.toImGuiColor(colors.icon)
    local text_color = ColorUtils.toImGuiColor(colors.text)
    
    -- Cache the calculated colors using the composite key
    button.cache.colors[cache_key] = {
        background = bg_color,
        border = border_color,
        icon = icon_color,
        text = text_color
    }
    
    return bg_color, border_color, icon_color, text_color
end

-- Get derived colors based on HSV transformations
function ColorUtils.getDerivedColors(baseColor, configBaseColor, configHoverColor, configClickedColor)
    -- Convert all inputs to HSV for better color manipulation
    local baseHSV = ColorUtils.toHSV(baseColor)
    local configBaseHSV = ColorUtils.toHSV(configBaseColor)
    local configHoverHSV = ColorUtils.toHSV(configHoverColor)
    local configClickedHSV = ColorUtils.toHSV(configClickedColor)
    
    -- Calculate the value differences
    local hoverValueDiff = configHoverHSV.v - configBaseHSV.v
    local clickedValueDiff = configClickedHSV.v - configBaseHSV.v
    
    -- Apply differences to base color
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
    
    -- Convert back to hex
    local hoverColor = ColorUtils.toHex(ColorUtils.toImGuiColor(ColorUtils.fromHSV(hoverHSV)))
    local clickedColor = ColorUtils.toHex(ColorUtils.toImGuiColor(ColorUtils.fromHSV(clickedHSV)))
    
    return hoverColor, clickedColor
end

return ColorUtils