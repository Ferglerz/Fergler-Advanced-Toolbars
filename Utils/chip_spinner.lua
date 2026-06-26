local ICON_FONTS_LIB = require("Utils.icon_fonts")
local DRAWING = require("Utils.drawing")

local CHIP_ROW = require("Renderers.Widgets.chip_row")

local M = {}

M.GAP = CHIP_ROW.CHIP_GAP
M.H_PAD = 5
M.V_PAD = CHIP_ROW.CHIP_V_PAD
M.ROUND = CHIP_ROW.CHIP_ROUND

local function icon_mode(font_type)
    local rel = font_type == "minus" and "icons/Math and Code/Minus.ttf" or "icons/Math and Code/Plus.ttf"
    return ICON_FONTS_LIB.resolveToolbarIcon(rel)
end

function M.chip_line_height(ctx)
    return CHIP_ROW.chip_line_height(ctx)
end

function M.side_button_width(ctx, label)
    label = label or "-"
    local is_icon_label = label == "-" or label == "+"
    if is_icon_label then
        local mode = icon_mode(label == "-" and "minus" or "plus")
        if mode.use_icons and ensureIconFontAttachedToContext(ctx, mode.font) then
            local icon_sz = M.chip_line_height(ctx) * 0.8
            reaper.ImGui_PushFont(ctx, mode.font, icon_sz)
            local tw = reaper.ImGui_CalcTextSize(ctx, utf8.char(ICON_FONTS_LIB.ICON_CODEPOINT))
            reaper.ImGui_PopFont(ctx)
            return math.max(tw, icon_sz * 0.65) + M.H_PAD * 2
        end
    end
    return reaper.ImGui_CalcTextSize(ctx, label) + M.H_PAD * 2
end

--- rel_y is toolbar row top; height is CONFIG.SIZES.HEIGHT. Returns rects with keys minus, readout, plus.
function M.layout_horizontal(ctx, rel_x, rel_y, toolbar_h, readout_w)
    local lh = M.chip_line_height(ctx)
    local row_y = rel_y + (toolbar_h - lh) / 2
    local wm = M.side_button_width(ctx, "-")
    local wp = M.side_button_width(ctx, "+")
    local x = rel_x
    local minus = { x = x, y = row_y, w = wm, h = lh }
    x = x + wm + M.GAP
    local readout = { x = x, y = row_y, w = readout_w, h = lh }
    x = x + readout_w + M.GAP
    local plus = { x = x, y = row_y, w = wp, h = lh }
    return minus, readout, plus, lh
end

function M.total_width(ctx, readout_w)
    readout_w = readout_w or 40
    return M.side_button_width(ctx, "-") + M.GAP + readout_w + M.GAP + M.side_button_width(ctx, "+")
end

function M.hit_test(mx, my, coords, minus, readout, plus)
    if coords:pointInRelativeRect(mx, my, minus.x, minus.y, minus.w, minus.h) then
        return "minus"
    end
    if coords:pointInRelativeRect(mx, my, readout.x, readout.y, readout.w, readout.h) then
        return "readout"
    end
    if coords:pointInRelativeRect(mx, my, plus.x, plus.y, plus.w, plus.h) then
        return "plus"
    end
    return nil
end

function M.draw_segment(ctx, coords, draw_list, rect, text, btn_txt, btn_bg, is_hover)
    local bg_col, text_col = COLOR_UTILS.widgetPillColors(btn_txt, btn_bg, {
        active = false,
        filled = true,
        hover = is_hover,
        disabled = false,
    })

    DRAWING.drawTextChip(ctx, coords, draw_list, rect.x, rect.y, rect.w, rect.h, type(text) == "string" and text or "", {
        bg_color = bg_col,
        text_color = text_col,
        rounding = M.ROUND
    })
end

return M
