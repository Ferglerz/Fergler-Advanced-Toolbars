-- color_utils.lua
local ColorUtils = {}

-- Direct conversion from various formats to ImGui color
function ColorUtils.toImGuiColor(color)
    -- Already in ImGui format
    if type(color) == "number" then
        return color
    end
    
    -- Hex string format
    if type(color) == "string" then
        local hex = color:gsub("#", "")
        local r = tonumber(hex:sub(1, 2), 16)
        local g = tonumber(hex:sub(3, 4), 16)
        local b = tonumber(hex:sub(5, 6), 16)
        local a = tonumber(hex:sub(7, 8) or "FF", 16)

        if not r or not g or not b or not a then
            return 0xFF0000FF -- Default to red if parsing fails
        end

        return (r << 24) | (g << 16) | (b << 8) | a
    end
    
    -- Table with RGBA components
    if type(color) == "table" and color.r and color.g and color.b then
        local a = color.a or 255
        return (color.r << 24) | (color.g << 16) | (color.b << 8) | a
    end
    
    -- REAPER native color
    if type(color) == "number" and color & 0x1000000 ~= 0 then
        -- Remove the flag bit
        local colorValue = color & 0xFFFFFF
        
        -- On Windows, GetOS() contains "Win", colors are stored as BGR
        if reaper.GetOS():match("Win") then
            local r = (colorValue) & 0xFF
            local g = (colorValue >> 8) & 0xFF
            local b = (colorValue >> 16) & 0xFF
            return (r << 24) | (g << 16) | (b << 8) | 0xFF
        else
            -- On macOS/Linux, colors are stored as RGB
            local r = (colorValue >> 16) & 0xFF
            local g = (colorValue >> 8) & 0xFF
            local b = colorValue & 0xFF
            return (r << 24) | (g << 16) | (b << 8) | 0xFF
        end
    end
    
    return 0xFFFFFFFF -- Default to white if format not recognized
end

-- For backward compatibility
function ColorUtils.hexToImGuiColor(hex)
    return ColorUtils.toImGuiColor(hex)
end

function ColorUtils.nativeColorToImGuiColor(nativeColor)
    return ColorUtils.toImGuiColor(nativeColor)
end

-- Extract RGBA components from color
function ColorUtils.extractComponents(color)
    -- Convert to ImGui format first if not already
    if type(color) ~= "number" then
        color = ColorUtils.toImGuiColor(color)
    end
    
    local r = (color >> 24) & 0xFF
    local g = (color >> 16) & 0xFF
    local b = (color >> 8) & 0xFF
    local a = color & 0xFF
    
    return {r = r, g = g, b = b, a = a}
end

-- Convert to hex string
function ColorUtils.toHex(color)
    local components = ColorUtils.extractComponents(color)
    return string.format("#%02X%02X%02X%02X", components.r, components.g, components.b, components.a)
end

-- Calculate HSV (Hue, Saturation, Value) directly from any color format
function ColorUtils.toHSV(color)
    local rgba = ColorUtils.extractComponents(color)
    
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

-- Convert HSV to RGB
function ColorUtils.fromHSV(hsv)
    if not hsv or not hsv.h or not hsv.s or not hsv.v then
        return nil
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

-- One-step function to get derived colors based on a base color and reference colors
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
    
    -- Convert back to original format
    local hoverColor = ColorUtils.toHex(ColorUtils.toImGuiColor(ColorUtils.fromHSV(hoverHSV)))
    local clickedColor = ColorUtils.toHex(ColorUtils.toImGuiColor(ColorUtils.fromHSV(clickedHSV)))
    
    return hoverColor, clickedColor
end

return ColorUtils