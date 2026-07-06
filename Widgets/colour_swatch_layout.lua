-- Widgets/colour_swatch_layout.lua
-- Grid planning for colour swatch cells.

local M = {}

M.MIN_CELL = 15
M.MAX_CELL = M.MIN_CELL * 2.5
M.GAP = 2
M.PAD_X = 4
M.PAD_Y_HORIZONTAL = 4
M.PAD_Y_VERTICAL_TOP = 6
M.PAD_Y_VERTICAL_BOTTOM = 12

-- Pick a column count that prefers larger swatches (up to max_c)
-- while still respecting the minimum cell size.
function M.columns_for_width_vertical(inner_w, n, min_c, max_c)
    n = math.max(1, n or 1)
    if inner_w < min_c then
        return 1
    end

    local max_cols_by_min = math.max(1, math.floor((inner_w + M.GAP) / (min_c + M.GAP)))
    local min_cols_for_max = math.max(1, math.ceil((inner_w + M.GAP) / (max_c + M.GAP)))
    local preferred_cols = math.max(1, math.min(max_cols_by_min, min_cols_for_max))

    return math.max(1, math.min(n, preferred_cols))
end

function M.cell_size(inner_w, cols, min_c, max_c)
    if cols <= 0 then
        return min_c
    end
    if inner_w <= 0 then
        return 1
    end
    local size = (inner_w - (cols - 1) * M.GAP) / cols
    local min_cell = inner_w < min_c and math.max(1, inner_w) or min_c
    return math.max(min_cell, math.min(max_c, size))
end

function M.horizontal_inner_height_budget(base_h, min_c)
    local h = (base_h or CONFIG.SIZES.HEIGHT or 0) - (M.PAD_Y_HORIZONTAL * 2)
    return math.max(min_c, h)
end

-- Horizontal toolbars: keep height bounded and widen widget as needed.
-- Try two rows only when they fit min_c; otherwise fall back to one row.
function M.plan_horizontal_grid(n, inner_h_budget, min_c, max_c)
    if n <= 0 then
        return 1, 1, min_c
    end

    local two_row_cell = (inner_h_budget - M.GAP) / 2
    local rows = (n >= 2 and two_row_cell >= min_c) and 2 or 1

    local cell
    if rows == 1 then
        cell = math.max(min_c, math.min(max_c, inner_h_budget))
    else
        cell = math.max(min_c, math.min(max_c, two_row_cell))
    end

    local cols = math.ceil(n / rows)
    return rows, cols, cell
end

-- Row item counts: first (n % rows) rows get ceil(n/rows), rest get floor — e.g. 15 in 2 rows → 8,7
function M.balanced_row_counts(n, rows)
    if rows <= 0 or n <= 0 then
        return {}
    end
    local q = math.floor(n / rows)
    local r = n - q * rows
    local counts = {}
    for i = 1, rows do
        counts[i] = q + (i <= r and 1 or 0)
    end
    return counts
end

-- Returns list of { x, y, w, h } in inner coordinates (origin top-left of padded area), and total height used
function M.layout_rects_vertical(inner_w, n, min_c, max_c)
    if n <= 0 then
        return {}, 0
    end
    local cols = M.columns_for_width_vertical(inner_w, n, min_c, max_c)
    local rows = math.ceil(n / cols)
    local cw = M.cell_size(inner_w, cols, min_c, max_c)
    local ch = cw
    local row_counts
    if rows >= 2 then
        row_counts = M.balanced_row_counts(n, rows)
    else
        row_counts = { n }
    end

    local rects = {}
    local idx = 1
    local y = 0
    for row = 1, rows do
        local cnt = row_counts[row] or 0
        local row_w = cnt * cw + (cnt - 1) * M.GAP
        local x0 = (inner_w - row_w) / 2
        for c = 1, cnt do
            if idx <= n then
                rects[idx] = {
                    x = x0 + (c - 1) * (cw + M.GAP),
                    y = y,
                    w = cw,
                    h = ch
                }
                idx = idx + 1
            end
        end
        y = y + ch + (row < rows and M.GAP or 0)
    end
    return rects, y
end

function M.layout_rects_horizontal(inner_w, n, inner_h_budget, min_c, max_c)
    if n <= 0 then
        return {}, 0
    end

    local rows, _, cell = M.plan_horizontal_grid(n, inner_h_budget, min_c, max_c)
    local ch = cell
    local row_counts = rows >= 2 and M.balanced_row_counts(n, rows) or { n }

    local rects = {}
    local idx = 1
    local y = 0
    for row = 1, rows do
        local cnt = row_counts[row] or 0
        local row_w = cnt * cell + (cnt - 1) * M.GAP
        local x0 = (inner_w - row_w) / 2
        for c = 1, cnt do
            if idx <= n then
                rects[idx] = {
                    x = x0 + (c - 1) * (cell + M.GAP),
                    y = y,
                    w = cell,
                    h = ch
                }
                idx = idx + 1
            end
        end
        y = y + ch + (row < rows and M.GAP or 0)
    end

    return rects, y
end

function M.layout_rects_preview_single_row(inner_w, n, inner_h_budget, min_c, max_c)
    if n <= 0 then
        return {}, 0
    end

    local cell = math.max(1, math.min(max_c, math.max(min_c, inner_h_budget)))
    local max_visible = math.max(1, math.floor((inner_w + M.GAP) / (cell + M.GAP)))
    local visible = math.max(1, math.min(n, max_visible))
    local row_w = visible * cell + (visible - 1) * M.GAP
    local x0 = (inner_w - row_w) / 2

    local rects = {}
    for i = 1, visible do
        rects[i] = {
            x = x0 + (i - 1) * (cell + M.GAP),
            y = 0,
            w = cell,
            h = cell
        }
    end
    return rects, cell
end

function M.layout_rects(inner_w, n, is_vertical_toolbar, inner_h_budget, min_c, max_c)
    if is_vertical_toolbar then
        return M.layout_rects_vertical(inner_w, n, min_c, max_c)
    end
    return M.layout_rects_horizontal(inner_w, n, inner_h_budget, min_c, max_c)
end

return M
