-- Utils/Widget/elements_misc.lua
-- Chip button, multiswitch, and colour swatch elements.

local DRAWING = require("Utils.Draw.drawing")
local SLIDE_HOST = require("Utils.Widget.slide_out_chip_host")

local M = {}

-- Interactive Chip Button element
function M.button(ctx, widget, coords, draw_list, rel_x, rel_y, render_width, render_height, label, text_color, bg_color, is_hovered, is_active, flags)
    local rounding = flags and flags.rounding or 4
    local draw_flags = flags and flags.draw_flags or 0

    local fill_color = bg_color or 0x222222FF
    if is_hovered then
        fill_color = COLOR_UTILS.lighten(fill_color, 0.15)
    end
    if is_active then
        fill_color = COLOR_UTILS.lighten(fill_color, 0.3)
    end

    DRAWING.drawChipBackground(coords, draw_list, rel_x, rel_y, render_width, render_height, fill_color, {
        rounding = rounding,
        flags = draw_flags,
        border_color = COLOR_UTILS.setAlpha(text_color, 0x25)
    })

    if label and label ~= "" then
        DRAWING.drawCenteredText(ctx, coords, draw_list, rel_x, rel_y, render_width, render_height, label, text_color, 0)
    end
end

-- Multiswitch element
function M.multiswitch(ctx, widget, coords, draw_list, text_color, bg_color, chips, opts)
    SLIDE_HOST.draw_ms(ctx, widget, chips, coords, draw_list, text_color, bg_color, opts)
end

-- Color Swatch element
function M.colour_swatch(ctx, widget, coords, draw_list, rel_x, rel_y, render_width, render_height, text_color, bg_color, layout)
    if widget.renderColourSwatch then
        widget.renderColourSwatch(ctx, widget, rel_x, rel_y, render_width, coords, draw_list, text_color, layout, bg_color, render_height)
    end
end

return M
