-- Utils/Core/color/widget.lua

local convert = require("Utils.Core.color.convert")
local packChannels = convert._packChannels

local M = {}

local CHIP_HOVER_LERP = 0.25
local CHIP_TRACK_OPACITY_BOOST = 0.10
-- Disabled sliders: 40% more transparent than the prior muted look (multiply alpha by 0.6).
M.WIDGET_DISABLED_EXTRA_FADE = 0.6

local function lerpColor(c1, c2, t)
    local r1, g1, b1 = convert.extractChannels(c1)
    local r2, g2, b2 = convert.extractChannels(c2)
    return packChannels(
        math.floor(r1 + (r2 - r1) * t + 0.5),
        math.floor(g1 + (g2 - g1) * t + 0.5),
        math.floor(b1 + (b2 - b1) * t + 0.5),
        0xFF
    )
end

--- True when widget.is_disabled exists and returns true (shared greyed-out / no-op state).
function M.isWidgetDisabled(widget)
    if not widget or type(widget.is_disabled) ~= "function" then
        return false
    end
    local ok, disabled = pcall(widget.is_disabled, widget)
    return ok and disabled == true
end

--- Slide-out should not open while disabled or when slide_out_can_interact returns false.
function M.slideOutBlocked(widget)
    if M.isWidgetDisabled(widget) then
        return true
    end
    if type(widget.slide_out_can_interact) == "function" then
        local ok, can = pcall(widget.slide_out_can_interact, widget)
        return ok and not can
    end
    return false
end

--- Muted slider/knob colors when isWidgetDisabled is true (extra fade applied on top of base mute).
function M.widgetDisabledSliderVisuals(text_color, bg_color, fill_color)
    local fade = M.WIDGET_DISABLED_EXTRA_FADE
    local track_bg = convert.modulateAlpha(0x1A1A1AFF, fade)
    local fill = convert.modulateAlpha(fill_color or 0x444444FF, fade)
    local text = convert.modulateAlpha(convert.setAlpha(text_color, 0x60), fade)
    local value_text = convert.modulateAlpha(bg_color or text, fade)
    return {
        track_bg = track_bg,
        fill_color = fill,
        text_color = text,
        value_color = value_text,
        handle_color = convert.modulateAlpha(convert.setAlpha(text_color, 0xFF), 0.3),
        ring_color = convert.modulateAlpha(convert.setAlpha(track_bg, 0x55), fade),
        dim_arc = convert.modulateAlpha(convert.setAlpha(track_bg, 0x35), fade),
    }
end

--- Grid ruler chip: alpha-overlay pills (not multiswitch track/pill).
function M.rulerPillColors(text_imggui, bg_imggui, opts)
    opts = opts or {}
    local tr, tg, tb = convert.extractChannels(text_imggui)
    local br, bg_g, bb = convert.extractChannels(bg_imggui)

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
    local dark_bg = convert.relativeLuminance(bg_imggui) < 0.5

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
        chip_bg = convert.modulateAlpha(chip_bg, opts.alpha_factor)
        chip_text = convert.modulateAlpha(chip_text, opts.alpha_factor)
    end

    return chip_bg, chip_text
end

function M.widgetPillColors(text_imggui, bg_imggui, opts)
    opts = opts or {}
    local tr, tg, tb = convert.extractChannels(text_imggui)
    local text_txt = packChannels(tr, tg, tb, 0xFF)
    local pal = M.multiswitchPalette(text_imggui, bg_imggui)
    local base_track = lerpColor(pal.track, pal.pill, CHIP_TRACK_OPACITY_BOOST)

    local chip_bg
    if opts.active then
        chip_bg = pal.pill
    elseif opts.hover and not opts.disabled then
        chip_bg = lerpColor(base_track, pal.pill, CHIP_HOVER_LERP)
    else
        chip_bg = base_track
    end

    local chip_text
    if opts.active then
        chip_text = pal.text_on_pill
    elseif opts.filled ~= false then
        chip_text = pal.text_on_track
    else
        chip_text = text_txt
    end

    if opts.disabled then
        chip_bg = convert.setAlpha(chip_bg, 0x55)
        chip_text = pal.text_disabled
    end

    if opts.alpha_factor and opts.alpha_factor < 1.0 then
        chip_bg = convert.modulateAlpha(chip_bg, opts.alpha_factor)
        chip_text = convert.modulateAlpha(chip_text, opts.alpha_factor)
    end

    return chip_bg, chip_text
end

function M.widgetButtonColors(text_color, bg_color, defaults)
    defaults = defaults or {}
    return text_color or defaults.text or 0xFFFFFFFF, bg_color or defaults.bg or 0x000000FF
end

function M.multiswitchTrackFill(btn_bg)
    local br, bg_g, bb = convert.extractChannels(btn_bg)
    local r = math.floor(br * 0.4 + 0x33 * 0.6)
    local g = math.floor(bg_g * 0.4 + 0x33 * 0.6)
    local b = math.floor(bb * 0.4 + 0x33 * 0.6)
    return packChannels(r, g, b, 0xFF)
end

function M.multiswitchPalette(btn_txt, btn_bg)
    local tr, tg, tb = convert.extractChannels(btn_txt)
    local br, bg_g, bb = convert.extractChannels(btn_bg)
    local text_bg = packChannels(br, bg_g, bb, 0xFF)
    local text_txt = packChannels(tr, tg, tb, 0xFF)
    local text_disabled = convert.setAlpha(text_bg, 0x7A)

    if convert.relativeLuminance(btn_bg) < 0.5 then
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
        track = M.multiswitchTrackFill(btn_bg),
        pill = text_txt,
        text_on_pill = text_bg,
        text_on_track = text_bg,
        text_disabled = text_disabled,
    }
end

return M
