-- Renderers/_Widgets_chip_row.lua
-- Shared horizontal/vertical chip layouts and hit-testing for multiswitch-style widgets (ruler, grid row, timebase, etc.).

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
    return reaper.ImGui_GetTextLineHeight(ctx) + M.CHIP_V_PAD * 2
end

--- entries: array of tables with .id (string); chip text uses Utils.chip_multiswitch (label, optional short_label).
--- Preserved on each chip as .entry and .mode (alias).
function M.layout_entries_horizontal(ctx, rel_x, rel_y, render_width, entries, options)
    options = options or {}
    local pad_x = (options.pad_x or 4) + M.button_rounding_content_pad()
    local gap = options.chip_gap or M.CHIP_GAP
    local min_w = options.min_chip_w or 24
    local h = CONFIG.SIZES.HEIGHT
    local chip_h = M.chip_line_height(ctx)
    local row_y = rel_y + (h - chip_h) / 2
    local total = #entries
    local usable_w = math.max(40, render_width - pad_x * 2)
    local per_w = math.floor((usable_w - gap * (total - 1)) / total)
    per_w = math.max(min_w, per_w)
    local grid_w = total * per_w + gap * (total - 1)
    local x = rel_x + pad_x + math.max(0, (usable_w - grid_w) / 2)
    local chips = {}
    for _, e in ipairs(entries) do
        chips[#chips + 1] = {
            id = e.id,
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
        local btn_h = CONFIG.SIZES.HEIGHT or chip_h
        local max_rows = (2 * chip_h + gap <= btn_h) and 2 or 1
        rows = max_rows
        cols = math.ceil(n / rows)
    end

    local usable_w = math.max(40, width - pad_x * 2)
    local cell_w = math.floor((usable_w - (cols - 1) * gap) / cols)
    cell_w = math.max(min_w, cell_w)
    local grid_w = cols * cell_w + (cols - 1) * gap
    local x0 = rel_x + pad_x + math.max(0, (width - pad_x * 2 - grid_w) / 2)

    local grid_h = rows * chip_h + math.max(0, rows - 1) * gap
    local y0
    local outer_h
    if is_vert then
        y0 = rel_y + pad_y
        outer_h = pad_y + grid_h + pad_y
    else
        local btn_h = CONFIG.SIZES.HEIGHT or chip_h
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
        return M.layout_entries_vertical(ctx, rel_x, rel_y, render_width, entries, options)
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

function M.vertical_toolbar_height(ctx, n_entries, options)
    options = options or {}
    local base = CONFIG.SIZES.HEIGHT
    if not ctx or not reaper.ImGui_GetTextLineHeight then
        return base
    end
    local chip_h = M.chip_line_height(ctx)
    local gap = options.chip_gap or M.CHIP_GAP
    local pad = (options.pad_y or 4) + M.button_rounding_content_pad()
    return pad * 2 + n_entries * chip_h + math.max(0, n_entries - 1) * gap
end

function M.standard_horizontal_or_vertical_height(ctx, n_entries, is_vertical_toolbar, options)
    if not is_vertical_toolbar then
        return CONFIG.SIZES.HEIGHT
    end
    return M.vertical_toolbar_height(ctx, n_entries, options)
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
    local per_w = math.floor((usable_w - gap * (total - 1)) / total)
    per_w = math.max(min_w, per_w)
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

return M
