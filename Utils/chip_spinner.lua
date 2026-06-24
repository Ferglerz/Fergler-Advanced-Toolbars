local ICON_FONTS_LIB = require("Utils.icon_fonts")
local DRAWING = require("Utils.drawing")

local M = {}

M.GAP = 3
M.H_PAD = 5
M.V_PAD = 2
M.ROUND = 3

local _minus_font_resolved
local _plus_font_resolved
local _font_cache_rev

local function icon_mode(font_type)
    local rev = _G._adv_tb_icon_font_rev or 0
    if _font_cache_rev ~= rev then
        _font_cache_rev = rev
        _minus_font_resolved = nil
        _plus_font_resolved = nil
    end

    local cached
    if font_type == "minus" then cached = _minus_font_resolved end
    if font_type == "plus" then cached = _plus_font_resolved end
    if cached ~= nil then return cached end

    local resolved = { use_icons = false }
    if not SCRIPT_PATH or SCRIPT_PATH == "" or not C or not C.ButtonContent then
        if font_type == "minus" then _minus_font_resolved = resolved else _plus_font_resolved = resolved end
        return resolved
    end

    local filename = font_type == "minus" and "Minus.ttf" or "Plus.ttf"
    local p = UTILS.joinPath(SCRIPT_PATH, "IconFonts", "icons", "Math and Code", filename)
    if not reaper.file_exists(p) then
        if font_type == "minus" then _minus_font_resolved = resolved else _plus_font_resolved = resolved end
        return resolved
    end

    local f = C.ButtonContent:loadIconFont(UTILS.normalizeSlashes("IconFonts/icons/Math and Code/" .. filename))
    if not f then
        if font_type == "minus" then _minus_font_resolved = resolved else _plus_font_resolved = resolved end
        return resolved
    end

    resolved = { use_icons = true, font = f }
    if font_type == "minus" then _minus_font_resolved = resolved else _plus_font_resolved = resolved end
    return resolved
end

function M.chip_line_height(ctx)
    return reaper.ImGui_GetTextLineHeight(ctx) + M.V_PAD * 2
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
        hover = is_hover,
        disabled = false,
    })
    local x1, y1 = coords:relativeToDrawList(rect.x, rect.y)
    local x2, y2 = coords:relativeToDrawList(rect.x + rect.w, rect.y + rect.h)
    reaper.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, bg_col, M.ROUND)

    if type(text) == "string" and text ~= "" then
        DRAWING.drawCenteredText(ctx, coords, draw_list, rect.x, rect.y, rect.w, rect.h, text, text_col)
    end
end

return M
