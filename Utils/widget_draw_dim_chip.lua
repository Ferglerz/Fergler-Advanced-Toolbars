-- Solo dim-style chip: outlined when off, filled when on.

local M = {}

--- Relative coords; hover uses mx,my in same space as rel_x/rel_y.
function M.draw(draw_list, coords, ctx, opts)
    local rel_x = opts.x
    local rel_y = opts.y
    local w = opts.w
    local h = opts.h
    local mx = opts.mx
    local my = opts.my
    local label = opts.label or "Dim"
    local text_color = opts.text_color or 0xFFFFFFFF
    local dim_on = opts.dim_on == true

    local lavender = opts.lavender or 0x967BB8FF
    local bg_idle = opts.bg_idle or 0x101010FF
    local hover_alpha = opts.hover_alpha or 0x55
    local round = opts.round or 3

    local dx1, dy1 = coords:relativeToDrawList(rel_x, rel_y)
    local dx2, dy2 = coords:relativeToDrawList(rel_x + w, rel_y + h)
    local hover = coords:pointInRelativeRect(mx, my, rel_x, rel_y, w, h)
    local hover_col = (lavender & 0xFFFFFF00) | hover_alpha

    local variant = opts.variant or "filled_outline"

    if dim_on then
        reaper.ImGui_DrawList_AddRectFilled(draw_list, dx1, dy1, dx2, dy2, lavender, round)
        if hover then
            reaper.ImGui_DrawList_AddRectFilled(draw_list, dx1, dy1, dx2, dy2, hover_col, round)
        end
    elseif variant == "hover_only_when_off" then
        if hover then
            reaper.ImGui_DrawList_AddRectFilled(draw_list, dx1, dy1, dx2, dy2, hover_col, round)
        end
    else
        reaper.ImGui_DrawList_AddRectFilled(draw_list, dx1, dy1, dx2, dy2, bg_idle, round)
        reaper.ImGui_DrawList_AddRect(draw_list, dx1, dy1, dx2, dy2, lavender, round, 0, opts.stroke or 1.0)
        if hover then
            reaper.ImGui_DrawList_AddRectFilled(draw_list, dx1, dy1, dx2, dy2, hover_col, round)
        end
    end

    local dtw = reaper.ImGui_CalcTextSize(ctx, label)
    local lh = reaper.ImGui_GetTextLineHeight(ctx)
    local dtx = rel_x + (w - dtw) / 2
    local dty = rel_y + (h - lh) / 2
    local tx, ty = coords:relativeToDrawList(dtx, dty)
    reaper.ImGui_DrawList_AddText(draw_list, tx, ty, text_color, label)
end

return M
