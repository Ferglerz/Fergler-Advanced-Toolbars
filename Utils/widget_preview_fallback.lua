-- Centered widget-picker preview labels when chip strips do not fit / cannot be built.

local M = {}

function M.draw_centered_title(ctx, title, rel_x, rel_y, width, height, coords, draw_list, text_color, value_y_offset)
    DRAWING.drawWidgetCenteredValueText(
        ctx,
        title,
        rel_x,
        rel_y,
        width,
        height,
        coords,
        draw_list,
        text_color,
        value_y_offset or 0
    )
end

--- If predicate is true, draws centered title and returns true (caller should return early).
function M.when(ctx, predicate, title, rel_x, rel_y, width, height, coords, draw_list, text_color, value_y_offset)
    if not predicate then
        return false
    end
    M.draw_centered_title(ctx, title, rel_x, rel_y, width, height, coords, draw_list, text_color, value_y_offset)
    return true
end

return M
