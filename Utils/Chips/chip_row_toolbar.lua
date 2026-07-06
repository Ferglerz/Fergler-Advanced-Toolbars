-- Centered toolbar chip layout helpers (single chip, two-row stacks).

local M = {}

function M.attach(row)
    --- Natural width for a single centered toolbar chip label.
    function row.toolbar_chip_width(ctx, label, opts)
        opts = opts or {}
        if not ctx or not reaper.ImGui_CalcTextSize then
            return opts.min_w or 44
        end
        local pad_h = opts.pad_h or 10
        local min_w = opts.min_w or 44
        local tw = reaper.ImGui_CalcTextSize(ctx, label or "—") or 0
        return math.max(min_w, tw + pad_h * 2)
    end

    --- Horizontally center a content block inside a toolbar button.
    function row.center_block_x(rel_x, render_width, block_w, pad_x)
        pad_x = pad_x or 0
        return rel_x + pad_x + math.max(0, (render_width - pad_x * 2 - block_w) / 2)
    end

    --- Two stacked toolbar rows: returns y0 (top row), y1 (bottom row), total_h.
    function row.toolbar_two_row_stack(rel_y, body_h, row_h, gap)
        gap = gap or row.TOOLBAR_STACK_GAP
        local total_h = row_h * 2 + gap
        local y0 = rel_y + (body_h - total_h) / 2
        return y0, y0 + row_h + gap, total_h
    end

    --- Centered single toolbar chip rect for slide-out mode widgets.
    function row.layout_toolbar_chip(ctx, rel_x, rel_y, render_width, layout, label, opts)
        opts = opts or {}
        render_width = tonumber(render_width) or 72
        local body_h = opts.height or row.widget_body_height(layout)
        local chip_h = row.chip_line_height(ctx)
        local R = row.button_rounding_content_pad()
        local pad_x = (opts.pad_x or 4) + R
        local min_inner = opts.min_inner_w or 40
        local inner_w = math.max(min_inner, render_width - pad_x * 2)
        local chip_w = math.min(row.toolbar_chip_width(ctx, label, opts), inner_w)
        local x = rel_x + pad_x + math.max(0, (render_width - pad_x * 2 - chip_w) / 2)
        local y = rel_y + (body_h - chip_h) / 2
        return {
            id = opts.id or "toolbar_mode",
            x = x,
            y = y,
            w = chip_w,
            h = chip_h,
            label = label,
        }
    end
end

return M
