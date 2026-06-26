-- Renderers/Widgets/chip_row.lua
-- Shared horizontal/vertical chip layouts and hit-testing for multiswitch-style widgets (ruler, grid row, timebase, etc.).

local CHIP_MS = require("Utils.chip_multiswitch")

local M = {}

M.CHIP_GAP = 3
M.CHIP_V_PAD = 2
M.CHIP_ROUND = 3

-- Single-glyph icon fonts inside chips (e.g. Magnet.ttf): scale with chip inner height, not CONFIG.ICON_FONT.SIZE.
M.MAGNET_ICON_FRAC_OF_CHIP_INNER = 0.625
M.MAGNET_ICON_MIN_PX = 6

--- Pixel size for a chip-inlaid icon font, from chip inner band (text line = chip_line_height − 2×CHIP_V_PAD).
--- opts.frac_of_chip_inner, opts.min_px override module defaults when set.
function M.magnet_icon_size(ctx, opts)
    opts = opts or {}
    local frac = opts.frac_of_chip_inner or M.MAGNET_ICON_FRAC_OF_CHIP_INNER
    local min_px = opts.min_px or M.MAGNET_ICON_MIN_PX
    local chip_h = M.chip_line_height(ctx)
    local inner = chip_h - 2 * M.CHIP_V_PAD
    return math.max(min_px, math.floor(inner * frac + 0.5))
end

--- Inset for chip content inside a toolbar button: 1 px per px of button rounding (clears rounded chrome).
function M.button_rounding_content_pad()
    return math.max(0, math.floor(tonumber(CONFIG.SIZES.ROUNDING) or 0))
end

function M.chip_line_height(ctx)
    local lh
    if ctx and reaper.ImGui_GetTextLineHeight then
        lh = reaper.ImGui_GetTextLineHeight(ctx)
    end
    if type(lh) ~= "number" or lh ~= lh then
        lh = CONFIG.SIZES.TEXT or 12
    end
    return lh + M.CHIP_V_PAD * 2
end

--- Widget content band height (excludes vertical toolbar title strip above rel_y).
function M.widget_body_height(layout)
    local h = (layout and layout.height) or CONFIG.SIZES.HEIGHT
    if layout and layout.is_vertical and (layout.title_height or 0) > 0 then
        h = h - layout.title_height
    end
    return h
end

function M.max_caption_width(ctx, entries, caption_for)
    local max_tw = 0
    for _, e in ipairs(entries or {}) do
        local text = caption_for and caption_for(e) or CHIP_MS.chip_caption(e)
        if type(text) == "string" and text ~= "" then
            max_tw = math.max(max_tw, reaper.ImGui_CalcTextSize(ctx, text) or 0)
        end
    end
    return max_tw
end

--- Uniform chip width: widest caption + horizontal padding (default multiswitch cell size).
function M.uniform_chip_cell_width(ctx, entries, options)
    options = options or {}
    if not ctx or not reaper.ImGui_CalcTextSize then
        return options.min_chip_w or 24
    end
    local pad_h = options.chip_pad_h or 6
    local min_w = options.min_chip_w or 0
    local max_tw = M.max_caption_width(ctx, entries, options.caption_for)
    return math.max(min_w, math.ceil(max_tw) + pad_h * 2)
end

function M.uniform_chip_row_width(ctx, entries, options)
    options = options or {}
    local gap = options.chip_gap or M.CHIP_GAP
    local inset = M.button_rounding_content_pad()
    local pad_x = (options.pad_x or 4) + inset
    local cell_w = M.uniform_chip_cell_width(ctx, entries, options)
    local n = #(entries or {})
    return pad_x * 2 + n * cell_w + gap * math.max(0, n - 1)
end

function M.uniform_multiswitch_width(ctx, entries, cols, options)
    options = options or {}
    local gap = options.chip_gap or M.CHIP_GAP
    local inset = M.button_rounding_content_pad()
    local pad_x = (options.pad_x or 4) + inset
    local cell_w = M.uniform_chip_cell_width(ctx, entries, options)
    cols = math.max(1, cols or 1)
    return pad_x * 2 + cols * cell_w + gap * math.max(0, cols - 1)
end

--- Up to 2 rows when two chip lines fit in CONFIG.SIZES.HEIGHT (horizontal toolbar slide-outs).
function M.horizontal_multiswitch_rows(ctx, options)
    options = options or {}
    if options.rows then
        return options.rows
    end
    if not ctx or not reaper.ImGui_GetTextLineHeight then
        return 2
    end
    local chip_h = M.chip_line_height(ctx)
    local gap = options.chip_gap or M.CHIP_GAP
    local btn_h = options.height or CONFIG.SIZES.HEIGHT or chip_h
    return (2 * chip_h + gap <= btn_h) and 2 or 1
end

function M.slide_out_content_pad(options)
    options = options or {}
    local inset = M.button_rounding_content_pad()
    return (options.pad_x or 4) + inset, (options.pad_y or 4) + inset
end

function M.max_multiswitch_cols_for_inner_w(ctx, entries, inner_w, options)
    local gap = options.chip_gap or M.CHIP_GAP
    local cell_w = M.uniform_chip_cell_width(ctx, entries, options)
    if cell_w <= 0 then
        return 1
    end
    return math.max(1, math.floor((inner_w + gap) / (cell_w + gap)))
end

function M.max_multiswitch_rows_for_inner_h(ctx, inner_h, options)
    local chip_h = M.chip_line_height(ctx)
    local gap = options.chip_gap or M.CHIP_GAP
    return math.max(1, math.floor((inner_h + gap) / (chip_h + gap)))
end

--- Balanced rows×cols for n chips; respects row/col caps (height-first slide-outs).
local function balanced_multiswitch_grid(n, rows_max, cols_max)
    rows_max = math.max(1, rows_max or n)
    cols_max = math.max(1, cols_max or n)
    local ideal_cols = math.ceil(math.sqrt(n))
    local rows = math.min(rows_max, math.max(1, math.ceil(n / ideal_cols)))
    local cols = math.ceil(n / rows)
    if cols > cols_max then
        cols = cols_max
        rows = math.ceil(n / cols)
        if rows > rows_max then
            rows = rows_max
            cols = math.ceil(n / rows)
        end
    end
    return math.max(1, rows), math.max(1, cols)
end

--- Plan slide-out panel from host button size.
--- Set panel_h only (vertical host): height fixed first, width wraps grid content.
--- Set panel_w only (horizontal host): width fixed first, height grows with grid rows.
--- Returns width, height, rows, cols.
function M.plan_slide_out_panel(ctx, entries, options, constraints)
    constraints = constraints or {}
    options = options or {}
    local n = #(entries or {})
    local chip_h = M.chip_line_height(ctx)
    local gap = options.chip_gap or M.CHIP_GAP
    local pad_x, pad_y = M.slide_out_content_pad(options)
    local panel_w = constraints.panel_w
    local panel_h = constraints.panel_h

    if n < 1 then
        return panel_w or M.uniform_multiswitch_width(ctx, entries, 1, options),
            panel_h or (chip_h + pad_y * 2),
            1,
            1
    end

    local inner_w = panel_w and math.max(40, panel_w - pad_x * 2) or nil
    local inner_h = panel_h and math.max(chip_h, panel_h - pad_y * 2) or nil
    local rows, cols

    if panel_h and not panel_w then
        local rows_max = M.max_multiswitch_rows_for_inner_h(ctx, inner_h, options)
        rows, cols = balanced_multiswitch_grid(n, rows_max, n)
        local w = M.uniform_multiswitch_width(ctx, entries, cols, options)
        return w, panel_h, rows, cols
    end

    if panel_w then
        local cols_max = M.max_multiswitch_cols_for_inner_w(ctx, entries, inner_w, options)
        cols = math.min(n, cols_max)
        rows = math.ceil(n / cols)
        if inner_h then
            local rows_max = M.max_multiswitch_rows_for_inner_h(ctx, inner_h, options)
            if rows > rows_max then
                rows = rows_max
                cols = math.ceil(n / rows)
            end
        end
        local grid_h = rows * chip_h + math.max(0, rows - 1) * gap
        local h = panel_h or (grid_h + pad_y * 2)
        return panel_w, h, rows, cols
    end

    return M.slide_out_multiswitch_metrics(ctx, entries, options, constraints.host_is_vertical)
end

--- Slide-out panel size from entry count and host toolbar orientation. Returns width, height, rows, cols.
function M.slide_out_multiswitch_metrics(ctx, entries, options, host_is_vertical)
    options = options or {}
    local n = #(entries or {})
    local chip_h = M.chip_line_height(ctx)
    local gap = options.chip_gap or M.CHIP_GAP
    local inset = M.button_rounding_content_pad()
    local pad_y = (options.pad_y or 4) + inset
    if n < 1 then
        return M.uniform_multiswitch_width(ctx, entries, 1, options), chip_h + pad_y * 2, 1, 1
    end
    local rows, cols
    if host_is_vertical then
        cols = math.min(2, n)
        rows = math.ceil(n / cols)
    else
        rows = M.horizontal_multiswitch_rows(ctx, options)
        cols = math.ceil(n / rows)
    end
    local w = M.uniform_multiswitch_width(ctx, entries, cols, options)
    local h = rows * chip_h + math.max(0, rows - 1) * gap + pad_y * 2
    return w, h, rows, cols
end

--- Grid layout for slide-out multiswitch panels; returns chips (same as layout_multiswitch_grid).
function M.layout_slide_out_multiswitch(ctx, rel_x, rel_y, render_width, slide_height, entries, options, plan)
    options = options or {}
    local rows = plan and plan.rows
    if not rows then
        rows = select(3, M.plan_slide_out_panel(ctx, entries, options, {
            panel_w = render_width,
            panel_h = slide_height,
        }))
    end
    local chips = M.layout_multiswitch_grid(ctx, rel_x, rel_y, render_width, { is_vertical = false }, entries, {
        pad_x = options.pad_x,
        pad_y = options.pad_y,
        rows = rows,
        min_chip_w = options.min_chip_w,
        chip_gap = options.chip_gap,
        chip_pad_h = options.chip_pad_h,
        caption_for = options.caption_for,
        height = slide_height,
    })
    return chips
end

local function resolve_chip_cell_width(ctx, entries, usable_w, total, gap, min_w, options)
    local sizing = options.sizing or "uniform_text"
    if sizing == "fill" then
        local per_w = math.floor((usable_w - gap * (total - 1)) / total)
        return math.max(min_w, per_w)
    end
    if sizing == "uniform_text" and ctx and reaper.ImGui_CalcTextSize then
        return M.uniform_chip_cell_width(ctx, entries, options)
    end
    return min_w
end

--- Uniform chip row in a fixed strip (x, y, strip_w); centers when strip is wider than the row.
function M.layout_chip_strip(ctx, x, y, strip_w, entries, options)
    options = options or {}
    local gap = options.chip_gap or M.CHIP_GAP
    local min_w = options.min_chip_w or 24
    local chip_h = M.chip_line_height(ctx)
    local total = #(entries or {})
    if total < 1 then
        return {}
    end
    local usable_w = math.max(40, strip_w)
    local per_w = resolve_chip_cell_width(ctx, entries, usable_w, total, gap, min_w, options)
    local grid_w = total * per_w + gap * (total - 1)
    local cx = x + math.max(0, (usable_w - grid_w) / 2)
    local chips = {}
    for _, e in ipairs(entries) do
        chips[#chips + 1] = {
            id = e.id,
            x = cx,
            y = y,
            w = per_w,
            h = chip_h,
            entry = e,
            mode = e,
        }
        cx = cx + per_w + gap
    end
    return chips
end

--- entries: array of tables with .id (string); chip text uses Utils.chip_multiswitch (label, optional short_label).
--- Preserved on each chip as .entry and .mode (alias).
function M.layout_entries_horizontal(ctx, rel_x, rel_y, render_width, entries, options)
    options = options or {}
    local pad_x = (options.pad_x or 4) + M.button_rounding_content_pad()
    local chip_h = M.chip_line_height(ctx)
    local body_h = options.height or CONFIG.SIZES.HEIGHT
    local row_y = options.row_y or (rel_y + (body_h - chip_h) / 2)
    local usable_w = math.max(40, render_width - pad_x * 2)
    return M.layout_chip_strip(ctx, rel_x + pad_x, row_y, usable_w, entries, options)
end

--- Equal-cell grid for multiswitch (row-major). Pads with `blank = true` chips to fill rows×cols.
--- layout.is_vertical: narrow strip → up to 2 columns when width allows; else 1 column.
--- Horizontal toolbar: up to 2 rows when two chip lines fit in CONFIG.SIZES.HEIGHT; else 1 row.
--- Returns chips, outer_height (vertical includes symmetric vertical pad; horizontal = grid pixel height only).
function M.layout_multiswitch_grid(ctx, rel_x, rel_y, width, layout, entries, options)
    options = options or {}
    local min_w = options.min_chip_w or 24
    local gap = options.chip_gap or M.CHIP_GAP
    local chip_h = M.chip_line_height(ctx)
    local inset = M.button_rounding_content_pad()
    local pad_x = (options.pad_x or 4) + inset
    local pad_y = (options.pad_y or 4) + inset
    local is_vert = layout and layout.is_vertical
    local n = #(entries or {})
    if n < 1 then
        return {}, CONFIG.SIZES.HEIGHT
    end

    local rows, cols
    if is_vert then
        local usable_w = math.max(40, width - pad_x * 2)
        cols = (usable_w >= 2 * min_w + gap) and 2 or 1
        cols = math.min(cols, math.max(1, n))
        rows = math.ceil(n / cols)
    else
        local btn_h = options.height or CONFIG.SIZES.HEIGHT or chip_h
        local max_rows = options.rows or ((2 * chip_h + gap <= btn_h) and 2 or 1)
        rows = max_rows
        cols = math.ceil(n / rows)
    end

    local usable_w = math.max(40, width - pad_x * 2)
    local cell_w = resolve_chip_cell_width(ctx, entries, usable_w, cols, gap, min_w, options)
    local grid_w = cols * cell_w + (cols - 1) * gap
    local x0 = rel_x + pad_x + math.max(0, (width - pad_x * 2 - grid_w) / 2)

    local grid_h = rows * chip_h + math.max(0, rows - 1) * gap
    local y0
    local outer_h
    if is_vert then
        y0 = rel_y + pad_y
        outer_h = pad_y + grid_h + pad_y
    else
        local btn_h = options.height or CONFIG.SIZES.HEIGHT or chip_h
        y0 = rel_y + math.max(0, (btn_h - grid_h) / 2)
        outer_h = grid_h
    end

    local chips = {}
    local ei = 1
    for r = 1, rows do
        for c = 1, cols do
            local x = x0 + (c - 1) * (cell_w + gap)
            local y = y0 + (r - 1) * (chip_h + gap)
            if ei <= n then
                local e = entries[ei]
                chips[#chips + 1] = {
                    id = e.id,
                    x = x,
                    y = y,
                    w = cell_w,
                    h = chip_h,
                    entry = e,
                    mode = e,
                }
                ei = ei + 1
            else
                chips[#chips + 1] = {
                    id = "__ms_blank_" .. tostring(#chips + 1),
                    blank = true,
                    x = x,
                    y = y,
                    w = cell_w,
                    h = chip_h,
                    entry = nil,
                    mode = nil,
                }
            end
        end
    end
    return chips, outer_h
end

function M.layout_entries_vertical(ctx, rel_x, rel_y, render_width, entries, options)
    options = options or {}
    local inset = M.button_rounding_content_pad()
    local pad_x = (options.pad_x or 4) + inset
    local pad_y = (options.pad_y or 4) + inset
    local gap = options.chip_gap or M.CHIP_GAP
    local chip_h = M.chip_line_height(ctx)
    local usable_w = math.max(40, render_width - pad_x * 2)
    local x = rel_x + pad_x
    local y = rel_y + pad_y
    local chips = {}
    for _, e in ipairs(entries) do
        chips[#chips + 1] = {
            id = e.id,
            x = x,
            y = y,
            w = usable_w,
            h = chip_h,
            entry = e,
            mode = e,
        }
        y = y + chip_h + gap
    end
    return chips
end

function M.layout_entries(ctx, rel_x, rel_y, render_width, layout, entries, options)
    if layout and layout.is_vertical then
        local chips = M.layout_multiswitch_grid(ctx, rel_x, rel_y, render_width, layout, entries, options)
        return chips
    end
    return M.layout_entries_horizontal(ctx, rel_x, rel_y, render_width, entries, options)
end

--- prefix includes trailing underscore, e.g. "ruler_".
function M.hit_test_chips(mx, my, coords, chips, prefix)
    for _, chip in ipairs(chips) do
        if not chip.blank and coords:pointInRelativeRect(mx, my, chip.x, chip.y, chip.w, chip.h) then
            return prefix .. chip.id
        end
    end
    return nil
end

function M.default_layout_width(ctx, n_entries, options)
    options = options or {}
    local min_per = options.min_chip_w or 24
    local inset = M.button_rounding_content_pad()
    local pad = (options.pad_x or 4) * 2 + inset * 2
    local gap = options.chip_gap or M.CHIP_GAP
    local natural = options.base_width or 520
    if ctx and reaper.ImGui_GetTextLineHeight then
        local computed = pad + n_entries * min_per + gap * math.max(0, n_entries - 1)
        natural = math.max(natural, computed)
    end
    return natural
end

function M.vertical_toolbar_height(ctx, n_entries, options, inner_w)
    options = options or {}
    if inner_w and inner_w > 0 and ctx and n_entries and n_entries > 0 then
        local entries = {}
        for i = 1, n_entries do
            entries[i] = { id = tostring(i) }
        end
        local _, outer_h = M.layout_multiswitch_grid(ctx, 0, 0, inner_w, { is_vertical = true }, entries, options)
        return outer_h
    end
    local base = CONFIG.SIZES.HEIGHT
    if not ctx or not reaper.ImGui_GetTextLineHeight then
        return base
    end
    local chip_h = M.chip_line_height(ctx)
    local gap = options.chip_gap or M.CHIP_GAP
    local pad = (options.pad_y or 4) + M.button_rounding_content_pad()
    return pad * 2 + n_entries * chip_h + math.max(0, n_entries - 1) * gap
end

function M.standard_horizontal_or_vertical_height(ctx, n_entries, is_vertical_toolbar, options, inner_w)
    if not is_vertical_toolbar then
        return CONFIG.SIZES.HEIGHT
    end
    return M.vertical_toolbar_height(ctx, n_entries, options, inner_w)
end

--- Centered subset row for widget browser preview; returns nil if too narrow.
function M.preview_entries_row(ctx, rel_x, rel_y, render_width, preview_ids, all_entries, options)
    options = options or {}
    local gap = options.chip_gap or M.CHIP_GAP
    local min_w = options.min_chip_w or 24
    local pad_x = (options.pad_x or 4) + M.button_rounding_content_pad()
    local id_key = options.id_key or "id"

    local by_id = {}
    for _, e in ipairs(all_entries) do
        by_id[e[id_key]] = e
    end
    local subset = {}
    for _, pid in ipairs(preview_ids) do
        local e = by_id[pid]
        if e then
            subset[#subset + 1] = e
        end
    end
    if #subset < #preview_ids then
        return nil
    end

    local h = CONFIG.SIZES.HEIGHT
    local chip_h = M.chip_line_height(ctx)
    local row_y = rel_y + (h - chip_h) / 2
    local total = #subset
    local usable_w = math.max(40, render_width - pad_x * 2)
    local per_w = resolve_chip_cell_width(ctx, subset, usable_w, total, gap, min_w, options)
    local row_w = total * per_w + gap * (total - 1)
    if row_w > render_width - pad_x * 2 then
        return nil
    end
    local chips = {}
    local x = rel_x + (render_width - row_w) / 2
    for _, e in ipairs(subset) do
        chips[#chips + 1] = {
            id = e[id_key],
            x = x,
            y = row_y,
            w = per_w,
            h = chip_h,
            entry = e,
            mode = e,
        }
        x = x + per_w + gap
    end
    return chips
end

function M.apply_preview_width_cap(self, natural_w)
    local cap = tonumber(self._preview_width_cap)
    if cap and cap > 0 then
        return math.min(natural_w, cap)
    end
    return natural_w
end

--- Natural width for a single centered toolbar chip label.
function M.toolbar_chip_width(ctx, label, opts)
    opts = opts or {}
    if not ctx or not reaper.ImGui_CalcTextSize then
        return opts.min_w or 44
    end
    local pad_h = opts.pad_h or 10
    local min_w = opts.min_w or 44
    local tw = reaper.ImGui_CalcTextSize(ctx, label or "—") or 0
    return math.max(min_w, tw + pad_h * 2)
end

--- Centered single toolbar chip rect for slide-out mode widgets.
function M.layout_toolbar_chip(ctx, rel_x, rel_y, render_width, layout, label, opts)
    opts = opts or {}
    render_width = tonumber(render_width) or 72
    local body_h = opts.height or M.widget_body_height(layout)
    local chip_h = M.chip_line_height(ctx)
    local R = M.button_rounding_content_pad()
    local pad_x = (opts.pad_x or 4) + R
    local min_inner = opts.min_inner_w or 40
    local inner_w = math.max(min_inner, render_width - pad_x * 2)
    local chip_w = math.min(M.toolbar_chip_width(ctx, label, opts), inner_w)
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

return M
