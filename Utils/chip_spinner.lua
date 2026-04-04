-- Utils/chip_spinner.lua
-- Three-part chip: side buttons (− / +) flanking a readout region (text entry target).

local M = {}

M.GAP = 3
M.H_PAD = 5
M.V_PAD = 2
M.ROUND = 3

function M.side_button_width(ctx, label)
    label = label or "-"
    return reaper.ImGui_CalcTextSize(ctx, label) + M.H_PAD * 2
end

function M.chip_line_height(ctx)
    return reaper.ImGui_GetTextLineHeight(ctx) + M.V_PAD * 2
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
        local tw = reaper.ImGui_CalcTextSize(ctx, text)
        local tx = rect.x + (rect.w - tw) / 2
        local ty = rect.y + (rect.h - reaper.ImGui_GetTextLineHeight(ctx)) / 2
        local dx, dy = coords:relativeToDrawList(tx, ty)
        reaper.ImGui_DrawList_AddText(draw_list, dx, dy, text_col, text)
    end
end

return M
