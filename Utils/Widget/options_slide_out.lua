-- Utils/Widget/options_slide_out.lua
-- Helpers for host chip / readout + slide-out option rows (toggle grids, multiswitch).

local ROW = require("Utils.Chips.chip_row")
local DRAWING = require("Utils.Draw.drawing")
local ICON_FONTS = require("Utils.Core.icon_fonts")
local CHIP_MS = require("Utils.Chips.chip_multiswitch")

local M = {}

local DEFAULT_ICON_GAP = 4

function M.with_slide_out(spec)
    spec.slide_out = true
    return spec
end

function M.resolve_icon(icon_path)
    return ICON_FONTS.resolveToolbarIcon(icon_path)
end

function M.icon_column_width(ctx, bundle, gap)
    gap = gap or DEFAULT_ICON_GAP
    if not bundle or not bundle.use_icons or not ctx then
        return 0
    end
    local icon_sz = ROW.magnet_icon_size(ctx)
    return math.max(icon_sz * 0.65, icon_sz) + gap
end

function M.draw_icon_leading_toggle(ctx, coords, draw_list, rect, label, hover, btn_txt, btn_bg, opts)
    opts = opts or {}
    local bundle = opts.icon_bundle
    local show_icon = opts.show_icon
    if show_icon == nil then
        show_icon = bundle and bundle.use_icons
    end
    local icon_font = opts.icon_font
    local icon_sz = 0
    if show_icon and bundle and bundle.use_icons then
        icon_sz = opts.icon_sz or ROW.magnet_icon_size(ctx)
        icon_font = icon_font or bundle.font
    end
    DRAWING.drawWidgetPillChipLeadingIcon(ctx, coords, draw_list, rect, label, btn_txt, btn_bg, {
        active = opts.active == true,
        filled = opts.filled ~= false,
        hover = hover and not opts.active,
        disabled = opts.disabled,
        rounding = opts.rounding or ROW.CHIP_ROUND,
        text_y_offset = opts.text_y_offset or 0,
        icon_font = icon_font,
        icon_char = opts.icon_char,
        icon_sz = icon_sz,
        icon_gap = opts.icon_gap or DEFAULT_ICON_GAP,
        alpha_factor = opts.alpha_factor,
    })
end

function M.host_readout_row(get_label, opts)
    opts = opts or {}
    return {
        toolbar_only = true,
        segments = {
            {
                type = "readout",
                get_label = get_label,
                min_width = opts.min_width,
                pad_x = opts.pad_x,
            },
        },
    }
end

function M.host_toggle_row(toggle_seg)
    return {
        toolbar_only = true,
        segments = { toggle_seg },
    }
end

function M.slide_multiswitch(modes, get_active, on_click, opts)
    opts = opts or {}
    CHIP_MS.normalize_chip_entries(modes)
    return {
        slide_only = true,
        segments = {
            {
                type = "multiswitch",
                modes = modes,
                min_chip_w = opts.min_chip_w,
                rows = opts.rows,
                get_active = get_active,
                on_click = on_click,
            },
        },
    }
end

function M.slide_multi_toggle(modes, is_on, on_click, opts)
    opts = opts or {}
    CHIP_MS.normalize_chip_entries(modes)
    return {
        slide_only = true,
        segments = {
            {
                type = "multiswitch",
                modes = modes,
                multi_toggle = true,
                min_chip_w = opts.min_chip_w,
                rows = opts.rows,
                is_on = is_on,
                on_click = on_click,
            },
        },
    }
end

--- Independent pill toggles (no shared multiswitch track, no merged selection).
function M.slide_toggle_chips(modes, is_on, on_click, opts)
    opts = opts or {}
    CHIP_MS.normalize_chip_entries(modes)
    local segments = {}
    for _, mode in ipairs(modes) do
        local id = mode.id
        local caption = mode.short_label or mode.label or id
        segments[#segments + 1] = {
            type = "toggle",
            label = caption,
            min_width = opts.min_chip_w or 40,
            get_label = function()
                return caption
            end,
            get_state = function(self)
                return is_on(self, id)
            end,
            on_click = function(self)
                on_click(self, id)
            end,
        }
    end
    return {
        slide_only = true,
        segments = segments,
    }
end

function M.slide_action_row(modes, on_click, opts)
    opts = opts or {}
    CHIP_MS.normalize_chip_entries(modes)
    return {
        slide_only = true,
        segments = {
            {
                type = "multiswitch",
                modes = modes,
                multi_toggle = true,
                min_chip_w = opts.min_chip_w,
                rows = opts.rows,
                is_on = function()
                    return false
                end,
                on_click = on_click,
            },
        },
    }
end

return M
