-- Renderers/Widgets/chip_row.lua
-- Shared horizontal/vertical chip layouts and hit-testing for multiswitch-style widgets (ruler, grid row, timebase, etc.).

local CHIP_MS = require("Utils.Chips.chip_multiswitch")
local FLEX = require("Utils.Core.flex_layout")
local SLIDE_OUT = require("Utils.Chips.chip_row_slide_out")
local MS_LAYOUT = require("Utils.Chips.chip_row_multiswitch_layout")
local TOOLBAR = require("Utils.Chips.chip_row_toolbar")

local M = {}

M.CHIP_GAP = 3
M.CHIP_V_PAD = 2
M.CHIP_ROUND = 3
-- Vertical gap between two stacked toolbar rows (spinner stacks, M over P|R, etc.).
M.TOOLBAR_STACK_GAP = 6

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
--- In vertical mode rel_y is always the content origin (below title); size and center within this band.
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

SLIDE_OUT.attach(M)
MS_LAYOUT.attach(M)
TOOLBAR.attach(M)

local function resolve_chip_cell_width(ctx, entries, usable_w, total, gap, min_w, options)
    return MS_LAYOUT.resolve_chip_cell_width(M, ctx, entries, usable_w, total, gap, min_w, options)
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

--- Flex-wrap chip groups into positioned items. Each group is an array of items with .w and .h.
--- opts.defer_item(it) → true keeps item out of chips[] (caller handles placement, e.g. time readout).
--- Returns chips, deferred items, meta { chip_h, pad_x, lines }.
function M.layout_flex_wrap_groups(ctx, rel_x, rel_y, render_width, layout, groups, opts)
    opts = opts or {}
    local is_vertical = layout and layout.is_vertical
    local body_h = M.widget_body_height(layout)
    local chip_gap = opts.chip_gap or M.CHIP_GAP
    local inset = M.button_rounding_content_pad()
    local pad_x = (opts.row_pad_x or 3) + inset
    local pad_y = opts.pad_y or (4 + inset)
    local inner_w = math.max(10, render_width - pad_x * 2)
    local max_w = is_vertical and inner_w or (opts.max_wrap_w or 99999)
    local chip_h = opts.chip_h
    if not chip_h and ctx and reaper.ImGui_GetTextLineHeight then
        chip_h = M.chip_line_height(ctx) + (opts.chip_h_extra or 0)
    end
    chip_h = chip_h or CONFIG.SIZES.HEIGHT

    local lines = FLEX.wrap_groups(groups, max_w, chip_gap, chip_gap)
    local chips = {}
    local deferred = {}
    local total_h = #lines * chip_h + math.max(0, #lines - 1) * chip_gap
    local start_y = is_vertical and (rel_y + pad_y) or (rel_y + (body_h - total_h) / 2)
    local y = start_y

    for line_idx, line in ipairs(lines) do
        local x = rel_x + pad_x
        if is_vertical and #line.items == 1 and opts.stretch_single_on_vertical then
            line.items[1].w = inner_w
        end
        for _, it in ipairs(line.items) do
            it.x = x
            it.y = y
            if opts.defer_item and opts.defer_item(it, line_idx) then
                deferred[#deferred + 1] = it
            else
                chips[#chips + 1] = it
            end
            x = x + it.w + chip_gap
        end
        y = y + chip_h + chip_gap
    end

    return chips, deferred, {
        chip_h = chip_h,
        pad_x = pad_x,
        pad_y = pad_y,
        inner_w = inner_w,
        lines = lines,
        start_y = start_y,
    }
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

return M
