-- Utils/color_utils.lua
local ColorUtils = {}

local function packChannels(r, g, b, a)
    return (r << 24) | (g << 16) | (b << 8) | a
end

-- Extract RGBA channels from an ImGui color integer
function ColorUtils.extractChannels(color)
    if not color then return 0, 0, 0, 0 end
    local r = (color >> 24) & 0xFF
    local g = (color >> 16) & 0xFF
    local b = (color >> 8) & 0xFF
    local a = color & 0xFF
    return r, g, b, a
end

-- Replace alpha byte of an ImGui color (alpha 0–255)
function ColorUtils.setAlpha(color, alpha_byte)
    if not color then return color end
    return (color & 0xFFFFFF00) | (math.floor(tonumber(alpha_byte) or 0) & 0xFF)
end

ColorUtils.replaceAlpha = ColorUtils.setAlpha

-- Core color conversion - all other conversions use this
function ColorUtils.toRGBA(color)
    -- Already in number format
    if type(color) == "number" then
        local r, g, b, a = ColorUtils.extractChannels(color)
        return { r = r, g = g, b = b, a = a }
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
    if not color then return {r = 0, g = 0, b = 0, a = 0} end
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

-- Helper function to get cached color with fallback
function ColorUtils.getCachedColor(state_key, color_type, mouse_key)
    if CONFIG_MANAGER then
        local cached = CONFIG_MANAGER:getCachedColorSafe(state_key, color_type, mouse_key)
        if cached then
            return cached
        end
    end

    -- Fallback to original conversion
    return ColorUtils.toImGuiColor(CONFIG.COLORS[state_key][color_type][mouse_key])
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
    
    -- Start with default config colors (using cached colors for performance)
    local colors = {
        background = CONFIG.COLORS[state_key].BG[mouse_key],
        border = CONFIG.COLORS[state_key].BORDER[mouse_key],
        icon = CONFIG.COLORS[state_key].ICON[mouse_key],
        text = CONFIG.COLORS[state_key].TEXT[mouse_key]
    }
    
    -- Apply user_colors if no custom colors are defined for this button
    if not button.custom_color and button.user_colors then
        -- Check if we need to apply a specific mouse state color
        if button.user_colors[mouse_key_lower] then
            colors = ColorUtils.applyUserColors(colors, button.user_colors[mouse_key_lower])
        end
        
        -- Also check for general colors that apply to all states
        if button.user_colors.all then
            colors = ColorUtils.applyUserColors(colors, button.user_colors.all)
        end
    end
    
    -- Apply custom colors ONLY for NORMAL state
    if button.custom_color and state_key == "NORMAL" then
        -- Apply base colors (normal state)
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
        
        -- Apply hover/active state colors if in that state
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
    
    -- Apply border offset if BG/Border linking is enabled and we have an offset
    if CONFIG.COLOR_SETTINGS and CONFIG.COLOR_SETTINGS.LINK_BG_BORDER and button.border_offset then
        -- Apply offset when linking is enabled, regardless of custom border colors
        if button.border_offset.saturation ~= 0 or button.border_offset.value ~= 0 then
            colors.border = ColorUtils.applyHSVOffset(colors.background, button.border_offset.saturation, button.border_offset.value)
        end
    end
    
    -- Convert colors to ImGui format (use cached colors when possible)
    local bg_color, border_color, icon_color, text_color

    -- Check if we can use cached colors (no custom modifications)
    if not button.custom_color and not button.user_colors and
       (not button.border_offset or (button.border_offset.saturation == 0 and button.border_offset.value == 0)) then
        -- Use cached colors for maximum performance
        bg_color = ColorUtils.getCachedColor(state_key, "BG", mouse_key)
        border_color = ColorUtils.getCachedColor(state_key, "BORDER", mouse_key)
        icon_color = ColorUtils.getCachedColor(state_key, "ICON", mouse_key)
        text_color = ColorUtils.getCachedColor(state_key, "TEXT", mouse_key)
    else
        -- Fallback to conversion for modified colors
        bg_color = ColorUtils.toImGuiColor(colors.background)
        border_color = ColorUtils.toImGuiColor(colors.border)
        icon_color = ColorUtils.toImGuiColor(colors.icon)
        text_color = ColorUtils.toImGuiColor(colors.text)
    end
    
    -- Cache the calculated colors using the composite key
    button.cache.colors[cache_key] = {
        background = bg_color,
        border = border_color,
        icon = icon_color,
        text = text_color
    }
    
    return bg_color, border_color, icon_color, text_color
end

-- Relative luminance (sRGB, 0–1) for picking readable foreground on a fill.
function ColorUtils.relativeLuminance(imggui_color)
    local r, g, b = ColorUtils.extractChannels(imggui_color)
    return 0.299 * (r / 255) + 0.587 * (g / 255) + 0.114 * (b / 255)
end

-- White or black label on a solid fill (utility for other UI if needed).
function ColorUtils.smartTextOnFill(fill_imggui)
    if ColorUtils.relativeLuminance(fill_imggui) < 0.5 then
        return 0xFFFFFFFF
    end
    return 0x000000FF
end

-- Toolbar pill / widget chip (ImGui 0xRRGGBBAA).
-- Dark button bg: white fill, label from button bg (inverse of light-button path).
-- Light button bg: fill from button text, label from button bg.
-- Track labels (idle, no pill): match button text colour.
function ColorUtils.widgetPillColors(text_imggui, bg_imggui, opts)
    opts = opts or {}
    local tr, tg, tb = ColorUtils.extractChannels(text_imggui)
    local br, bg_g, bb = ColorUtils.extractChannels(bg_imggui)

    local alpha_idle = math.floor(0.65 * 255 + 0.5)
    local alpha_hover = math.floor(0.80 * 255 + 0.5)
    local alpha = alpha_idle
    if opts.active then
        alpha = 0xFF
    elseif opts.hover then
        alpha = alpha_hover
    end

    local ta = opts.disabled and 0x7A or 0xFF
    local on_fill = opts.active or opts.filled
    local dark_bg = ColorUtils.relativeLuminance(bg_imggui) < 0.5

    local chip_bg
    if dark_bg then
        chip_bg = packChannels(0xFF, 0xFF, 0xFF, alpha)
    else
        chip_bg = packChannels(tr, tg, tb, alpha)
    end

    local chip_text
    if on_fill then
        chip_text = packChannels(br, bg_g, bb, ta)
    else
        chip_text = packChannels(tr, tg, tb, ta)
    end

    if opts.alpha_factor and opts.alpha_factor < 1.0 then
        chip_bg = ColorUtils.modulateAlpha(chip_bg, opts.alpha_factor)
        chip_text = ColorUtils.modulateAlpha(chip_text, opts.alpha_factor)
    end

    return chip_bg, chip_text
end

function ColorUtils.dimmedText(base_color, alpha)
    return ColorUtils.setAlpha(base_color, alpha or 0x80)
end

function ColorUtils.groupLabelColor()
    return ColorUtils.toImGuiColor(CONFIG.COLORS.GROUP.LABEL)
end

function ColorUtils.applyAlphaFactor(color, factor)
    return ColorUtils.modulateAlpha(color, factor)
end


-- Normalize toolbar text/bg passed into widget renderCustom.
function ColorUtils.widgetButtonColors(text_color, bg_color, defaults)
    defaults = defaults or {}
    return text_color or defaults.text or 0xFFFFFFFF, bg_color or defaults.bg or 0x000000FF
end

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

-- Apply user colors to a base color table
function ColorUtils.applyUserColors(baseColors, userColors)
    local result = {}
    for key, value in pairs(baseColors) do
        result[key] = value
    end
    
    -- Override with user colors if they exist
    for key, value in pairs(userColors) do
        if key == "background" or key == "border" or key == "icon" or key == "text" then
            result[key] = value
        end
    end
    
    return result
end

-- Apply HSV offset to a color
function ColorUtils.applyHSVOffset(baseColor, saturationOffset, valueOffset)
    -- Convert to HSV
    local hsv = ColorUtils.toHSV(baseColor)
    
    -- Apply offsets (clamp to valid ranges)
    hsv.s = math.max(0, math.min(1, hsv.s + saturationOffset))
    hsv.v = math.max(0, math.min(1, hsv.v + valueOffset))
    
    -- Convert back to hex
    return ColorUtils.toHex(ColorUtils.toImGuiColor(ColorUtils.fromHSV(hsv)))
end

-- Calculate border color from background using stored offset
function ColorUtils.calculateBorderFromBackground(backgroundColor, borderOffset)
    return ColorUtils.applyHSVOffset(backgroundColor, borderOffset.saturation, borderOffset.value)
end

-- Calculate HSV offset between two colors (for reverse-engineering existing combinations)
function ColorUtils.calculateHSVOffset(baseColor, targetColor)
    local baseHSV = ColorUtils.toHSV(baseColor)
    local targetHSV = ColorUtils.toHSV(targetColor)
    
    return {
        saturation = targetHSV.s - baseHSV.s,
        value = targetHSV.v - baseHSV.v
    }
end

-- Raise RGB channels by a fixed delta (ImGui 0xRRGGBBAA); alpha unchanged.
function ColorUtils.lightenByDelta(color, delta)
    if not color then
        return color
    end
    local r, g, b, a = ColorUtils.extractChannels(color)
    return packChannels(
        math.min(255, r + delta),
        math.min(255, g + delta),
        math.min(255, b + delta),
        a
    )
end

-- Brighten via HSV value offset (0–1); used for interactive widget fills.
function ColorUtils.lighten(color, v_delta)
    if not color or not v_delta or v_delta == 0 then
        return color
    end
    local hsv = ColorUtils.toHSV(color)
    hsv.v = math.max(0, math.min(1, hsv.v + v_delta))
    return ColorUtils.toImGuiColor(ColorUtils.fromHSV(hsv))
end

-- Modulate the alpha of an ImGui color by a factor (0.0 to 1.0)
function ColorUtils.modulateAlpha(color, factor)
    if not color or factor >= 1.0 then return color end
    local r, g, b, a = ColorUtils.extractChannels(color)
    local new_a = math.floor(a * factor + 0.5)
    return packChannels(r, g, b, new_a)
end

-- Darkened track fill for light-button multiswitch chrome.
function ColorUtils.multiswitchTrackFill(btn_bg)
    local br, bg_g, bb = ColorUtils.extractChannels(btn_bg)
    local r = math.floor(br * 0.4 + 0x33 * 0.6)
    local g = math.floor(bg_g * 0.4 + 0x33 * 0.6)
    local b = math.floor(bb * 0.4 + 0x33 * 0.6)
    return packChannels(r, g, b, 0xFF)
end

--- Sliding multiswitch chrome: light buttons use dark track + text-colour pill; dark buttons invert.
function ColorUtils.multiswitchPalette(btn_txt, btn_bg)
    local tr, tg, tb = ColorUtils.extractChannels(btn_txt)
    local br, bg_g, bb = ColorUtils.extractChannels(btn_bg)
    local text_bg = packChannels(br, bg_g, bb, 0xFF)
    local text_txt = packChannels(tr, tg, tb, 0xFF)
    local text_disabled = ColorUtils.setAlpha(text_bg, 0x7A)

    if ColorUtils.relativeLuminance(btn_bg) < 0.5 then
        local track_r = math.floor(br * 0.4 + 0xFF * 0.6)
        local track_g = math.floor(bg_g * 0.4 + 0xFF * 0.6)
        local track_b = math.floor(bb * 0.4 + 0xFF * 0.6)
        return {
            track = packChannels(track_r, track_g, track_b, 0xFF),
            pill = text_bg,
            text_on_pill = text_txt,
            text_on_track = text_bg,
            text_disabled = text_disabled,
        }
    end

    return {
        track = ColorUtils.multiswitchTrackFill(btn_bg),
        pill = text_txt,
        text_on_pill = text_bg,
        text_on_track = text_bg,
        text_disabled = text_disabled,
    }
end

-- Apply a 50% alpha ghost tint (for drag/drop placeholders)
function ColorUtils.ghostTint(color)
    if not color then return color end
    local _, _, _, a = ColorUtils.extractChannels(color)
    return ColorUtils.setAlpha(color, math.floor(a * 0.5))
end

return ColorUtils