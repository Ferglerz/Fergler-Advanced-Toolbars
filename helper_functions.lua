local CONFIG = require "Advanced Toolbars - User Config"

local Helpers = {}

function Helpers.calculateTextWidth(ctx, text, font)
    local max_width = 0
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

Helpers.dump = function(o)
    if type(o) == "table" then
        local s = "{ "
        for k, v in pairs(o) do
            if type(k) ~= "number" then
                k = '"' .. k .. '"'
            end
            s = s .. "[" .. k .. "] = " .. Helpers.dump(v) .. ","
        end
        return s .. "} "
    else
        return tostring(o)
    end
end

-- Convert hex color string to RGBA components (0-255)
function Helpers.hexToRGBA(hex)
    if type(hex) == "number" then
        hex = Helpers.numberToHex(hex)
    end
    if not hex then
        return nil
    end
    hex = hex:gsub("#", "")
    if #hex < 6 then
        return nil
    end

    local r = tonumber(hex:sub(1, 2), 16)
    local g = tonumber(hex:sub(3, 4), 16)
    local b = tonumber(hex:sub(5, 6), 16)
    local a = tonumber(hex:sub(7, 8) or "FF", 16)

    if not r or not g or not b then
        return nil
    end

    return {
        r = r,
        g = g,
        b = b,
        a = a or 255
    }
end

-- Convert RGBA components to hex string
function Helpers.rgbaToHex(rgba)
    if not rgba or not rgba.r or not rgba.g or not rgba.b then
        return nil
    end
    return string.format("#%02X%02X%02X%02X", rgba.r, rgba.g, rgba.b, rgba.a or 255)
end

-- Calculate HSV (Hue, Saturation, Value) from RGB
function Helpers.rgbToHSV(rgba)
    if not rgba or not rgba.r or not rgba.g or not rgba.b then
        return {h = 0, s = 0, v = 0}
    end

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
function Helpers.hsvToRGB(hsv)
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

-- Calculate value difference between two colors
function Helpers.getValueDifference(color1, color2)
    if not color1 or not color2 then
        return 0
    end

    local rgba1 = Helpers.hexToRGBA(color1)
    local rgba2 = Helpers.hexToRGBA(color2)

    if not rgba1 or not rgba2 then
        return 0
    end

    local hsv1 = Helpers.rgbToHSV(rgba1)
    local hsv2 = Helpers.rgbToHSV(rgba2)

    return hsv2.v - hsv1.v
end

-- Apply value difference to a color
function Helpers.applyValueDifference(baseColor, valueDiff)
    if not baseColor or not valueDiff then
        return baseColor
    end
    local rgba = Helpers.hexToRGBA(baseColor)
    if not rgba then
        return baseColor
    end

    local hsv = Helpers.rgbToHSV(rgba)
    if not hsv then
        return baseColor
    end

    -- Calculate new value, handling both positive and negative differences
    local newValue = hsv.v + valueDiff

    -- If we don't have enough range, invert the difference
    if newValue > 1 or newValue < 0 then
        newValue = hsv.v - valueDiff
    end

    -- Clamp final value between 0 and 1
    hsv.v = math.max(0, math.min(1, newValue))

    -- Convert back to RGB and then hex
    local newRGB = Helpers.hsvToRGB(hsv)
    if not newRGB then
        return baseColor
    end

    local newHex = Helpers.rgbaToHex(newRGB)
    return newHex or baseColor
end

function Helpers.numberToHex(num)
    if not num then
        return nil
    end
    -- Extract RGBA components from number
    local r = (num >> 24) & 0xFF
    local g = (num >> 16) & 0xFF
    local b = (num >> 8) & 0xFF
    local a = num & 0xFF
    return string.format("#%02X%02X%02X%02X", r, g, b, a)
end

function Helpers.getDerivedColors(baseColor)
    -- Convert number values to hex strings if needed
    local configBaseColor = Helpers.numberToHex(CONFIG.COLORS.NORMAL) or CONFIG.COLORS.COLOR
    local configHoverColor = Helpers.numberToHex(CONFIG.COLORS.HOVER) or CONFIG.COLORS.HOVER
    local configActiveColor = Helpers.numberToHex(CONFIG.COLORS.ACTIVE) or CONFIG.COLORS.ACTIVE

    -- Calculate value differences from default colors
    local defaultHoverDiff = Helpers.getValueDifference(configBaseColor, configHoverColor)

    local defaultActiveDiff = Helpers.getValueDifference(configBaseColor, configActiveColor)

    -- Ensure baseColor is hex string
    local baseColorHex = type(baseColor) == "number" and Helpers.numberToHex(baseColor) or baseColor

    local hoverColor = Helpers.applyValueDifference(baseColorHex, defaultHoverDiff)
    local activeColor = Helpers.applyValueDifference(baseColorHex, defaultActiveDiff)

    return hoverColor or baseColor, activeColor or baseColor
end

-- Existing hexToImGuiColor function remains the same
function Helpers.hexToImGuiColor(hex)
    if type(hex) == "number" then
        return hex
    end
    if not hex then
        return 0xFFFFFFFF
    end -- Default to white if nil

    hex = hex:gsub("#", "")
    local r = tonumber(hex:sub(1, 2), 16)
    local g = tonumber(hex:sub(3, 4), 16)
    local b = tonumber(hex:sub(5, 6), 16)
    local a = tonumber(hex:sub(7, 8) or "FF", 16)

    if not r or not g or not b or not a then
        return 0xFFFFFFFF -- Default to white if parsing fails
    end

    return (r << 24) | (g << 16) | (b << 8) | a
end
return Helpers
