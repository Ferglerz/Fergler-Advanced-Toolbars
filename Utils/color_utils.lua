-- Utils/color_utils.lua
local ColorUtils = {}

-- Direct conversion from various formats to ImGui color
function ColorUtils.hexToImGuiColor(color)
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

    return 0xFFFFFFFF 
end

function ColorUtils.reaperColorToImGui(color)
    -- Extract RGB values assuming BGR format in REAPER
    local b = (color >> 16) & 0xFF
    local g = (color >> 8) & 0xFF
    local r = color & 0xFF
    
    -- Construct ImGui color (0xRRGGBBAA format)
    return (b << 24) | (g << 16) | (r << 8) | 0xFF
end

-- Extract RGBA components from color
function ColorUtils.extractComponents(color)
    -- Convert to ImGui format first if not already
    if type(color) ~= "number" then
        color = ColorUtils.hexToImGuiColor(color)
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

-- Get all colors needed for rendering a button
-- Get all colors needed for rendering a button
-- Get all colors needed for rendering a button
function ColorUtils.getButtonColors(button, state_key, mouse_key)
    local mouse_key_lower = mouse_key:lower()
    
    local colors = {
        background = CONFIG.COLORS[state_key].BG[mouse_key],
        border = CONFIG.COLORS[state_key].BORDER[mouse_key],
        icon = CONFIG.COLORS[state_key].ICON[mouse_key],
        text = CONFIG.COLORS[state_key].TEXT[mouse_key]
    }

    if button.custom_color and state_key == "NORMAL" then
        for key, value in pairs(button.custom_color) do
            -- Map the key to the correct CONFIG key
            local config_key
            if key == "background" then config_key = "BG"
            elseif key == "border" then config_key = "BORDER"
            elseif key == "icon" then config_key = "ICON"
            elseif key == "text" then config_key = "TEXT"
            else config_key = key:upper()
            end
            
            -- Store the normal color
            local normal_color = value.normal
            
            -- Only calculate hover/clicked if needed
            if mouse_key_lower == "hover" or mouse_key_lower == "clicked" then
                -- Get reference colors from config
                local configBaseColor = CONFIG.COLORS.NORMAL[config_key].NORMAL
                local configHoverColor = CONFIG.COLORS.NORMAL[config_key].HOVER
                local configClickedColor = CONFIG.COLORS.NORMAL[config_key].CLICKED
                
                -- Calculate derived colors on-the-fly
                local hoverColor, clickedColor = ColorUtils.getDerivedColors(
                    normal_color, configBaseColor, configHoverColor, configClickedColor
                )
                
                -- Use the appropriate derived color
                if mouse_key_lower == "hover" then
                    colors[key] = hoverColor
                elseif mouse_key_lower == "clicked" then
                    colors[key] = clickedColor
                end
            else
                -- Use normal color
                colors[key] = normal_color
            end
        end
    end

    return ColorUtils.hexToImGuiColor(colors.background),
           ColorUtils.hexToImGuiColor(colors.border),
           ColorUtils.hexToImGuiColor(colors.icon),
           ColorUtils.hexToImGuiColor(colors.text)
end

-- Get derived colors based on a base color and reference colors
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
    local hoverColor = ColorUtils.toHex(ColorUtils.hexToImGuiColor(ColorUtils.fromHSV(hoverHSV)))
    local clickedColor = ColorUtils.toHex(ColorUtils.hexToImGuiColor(ColorUtils.fromHSV(clickedHSV)))

    return hoverColor, clickedColor
end

return ColorUtils
