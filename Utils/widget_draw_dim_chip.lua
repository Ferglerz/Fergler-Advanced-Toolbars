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
    local hover_col = COLOR_UTILS.setAlpha(lavender, hover_alpha)

    local variant = opts.variant or "filled_outline"

    if dim_on then
        DRAWING.drawChipBackground(coords, draw_list, rel_x, rel_y, w, h, lavender, { rounding = round })
        if hover then
            DRAWING.drawChipBackground(coords, draw_list, rel_x, rel_y, w, h, hover_col, { rounding = round })
        end
    elseif variant == "hover_only_when_off" then
        if hover then
            DRAWING.drawChipBackground(coords, draw_list, rel_x, rel_y, w, h, hover_col, { rounding = round })
        end
    else
        DRAWING.drawChipBackground(coords, draw_list, rel_x, rel_y, w, h, bg_idle, { rounding = round, border_color = lavender })
        if hover then
            DRAWING.drawChipBackground(coords, draw_list, rel_x, rel_y, w, h, hover_col, { rounding = round })
        end
    end

    DRAWING.drawCenteredText(ctx, coords, draw_list, rel_x, rel_y, w, h, label, text_color, 0)
end

return M
