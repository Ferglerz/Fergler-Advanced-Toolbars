-- Utils/Core/color/convert.lua

local M = {}

local function packChannels(r, g, b, a)
    return (r << 24) | (g << 16) | (b << 8) | a
end

M._packChannels = packChannels

function M.extractChannels(color)
    if not color then return 0, 0, 0, 0 end
    local r = (color >> 24) & 0xFF
    local g = (color >> 16) & 0xFF
    local b = (color >> 8) & 0xFF
    local a = color & 0xFF
    return r, g, b, a
end

function M.setAlpha(color, alpha_byte)
    if not color then return color end
    return (color & 0xFFFFFF00) | (math.floor(tonumber(alpha_byte) or 0) & 0xFF)
end

M.replaceAlpha = M.setAlpha

function M.toRGBA(color)
    if type(color) == "number" then
        local r, g, b, a = M.extractChannels(color)
        return { r = r, g = g, b = b, a = a }
    end

    if type(color) == "string" then
        local hex = color:gsub("#", "")
        local r = tonumber(hex:sub(1, 2), 16)
        local g = tonumber(hex:sub(3, 4), 16)
        local b = tonumber(hex:sub(5, 6), 16)
        local a = tonumber(hex:sub(7, 8) or "FF", 16)

        if not r or not g or not b or not a then
            return {r = 255, g = 0, b = 0, a = 255}
        end

        return {r = r, g = g, b = b, a = a}
    end

    if type(color) == "table" and color.r and color.g and color.b then
        return {
            r = color.r,
            g = color.g,
            b = color.b,
            a = color.a or 255
        }
    end

    return {r = 255, g = 255, b = 255, a = 255}
end

function M.toImGuiColor(color)
    local rgba = M.toRGBA(color)
    return (rgba.r << 24) | (rgba.g << 16) | (rgba.b << 8) | rgba.a
end

function M.toHex(color)
    local rgba = M.toRGBA(color)
    return string.format("#%02X%02X%02X%02X", rgba.r, rgba.g, rgba.b, rgba.a)
end

function M.reaperColorToRGBA(color)
    if not color then return {r = 0, g = 0, b = 0, a = 0} end
    local b = (color >> 16) & 0xFF
    local g = (color >> 8) & 0xFF
    local r = color & 0xFF

    return {r = r, g = g, b = b, a = 255}
end

function M.reaperColorToImGui(color)
    local rgba = M.reaperColorToRGBA(color)
    return (rgba.b << 24) | (rgba.g << 16) | (rgba.r << 8) | rgba.a
end

function M.toHSV(color)
    local rgba = M.toRGBA(color)
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

function M.fromHSV(hsv)
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

function M.relativeLuminance(imggui_color)
    local r, g, b = M.extractChannels(imggui_color)
    return 0.299 * (r / 255) + 0.587 * (g / 255) + 0.114 * (b / 255)
end

function M.smartTextOnFill(fill_imggui)
    if M.relativeLuminance(fill_imggui) < 0.5 then
        return 0xFFFFFFFF
    end
    return 0x000000FF
end

function M.modulateAlpha(color, factor)
    if not color or factor >= 1.0 then return color end
    local r, g, b, a = M.extractChannels(color)
    local new_a = math.floor(a * factor + 0.5)
    return packChannels(r, g, b, new_a)
end

function M.lightenByDelta(color, delta)
    if not color then
        return color
    end
    local r, g, b, a = M.extractChannels(color)
    return packChannels(
        math.min(255, r + delta),
        math.min(255, g + delta),
        math.min(255, b + delta),
        a
    )
end

function M.lighten(color, v_delta)
    if not color or not v_delta or v_delta == 0 then
        return color
    end
    local hsv = M.toHSV(color)
    hsv.v = math.max(0, math.min(1, hsv.v + v_delta))
    return M.toImGuiColor(M.fromHSV(hsv))
end

function M.ghostTint(color)
    if not color then return color end
    local _, _, _, a = M.extractChannels(color)
    return M.setAlpha(color, math.floor(a * 0.5))
end

return M
