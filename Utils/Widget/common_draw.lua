-- Utils/Widget/common_draw.lua
-- Shared ImGui draw bits for widget renderers (Widgets.lua, slider, knob).

local DRAWING = require("Utils.Draw.drawing")

local M = {}

--- Centered value readout in a horizontal band (e.g. slider quick-chip slide-out).
function M.drawSliderValueReadout(ctx, coords, draw_list, widget, base_x, base_y, width, band_height, text_color, alpha_factor)
    local text = UTILS.formatWidgetValue(widget)
    DRAWING.drawCenteredBandText(ctx, coords, draw_list, base_x, base_y, width, band_height, text, text_color, { dim = true, alpha_factor = alpha_factor })
end

--- Slider and knob: value string vertically centered, optional label right-aligned.
--- Value text uses toolbar button bg (matches filled chip labels); label stays dimmed.
function M.drawSliderWidgetValueAndLabel(ctx, coords, draw_list, widget, base_x, base_y, width, text_color, bg_color, band_height, text_pad)
    local text = UTILS.formatWidgetValue(widget)
    local value_color = bg_color or COLOR_UTILS.setAlpha(text_color, 0x80)
    local label_color = COLOR_UTILS.setAlpha(text_color, 0x80)

    local height = band_height or (CONFIG and CONFIG.SIZES and CONFIG.SIZES.HEIGHT or 24)
    local pad = text_pad or 4
    local text_rel_y = DRAWING.centeredTextRelY(ctx, base_y, height, 0)

    DRAWING.drawTextRelative(coords, draw_list, base_x + pad, text_rel_y, value_color, text)

    if widget.label and widget.label ~= "" then
        local label_width = reaper.ImGui_CalcTextSize(ctx, widget.label)
        DRAWING.drawTextRelative(coords, draw_list, base_x + width - label_width - pad, text_rel_y, label_color, widget.label)
    end
end

return M
