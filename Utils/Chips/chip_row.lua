-- Renderers/Widgets/chip_row.lua
-- Shared horizontal/vertical chip layouts and hit-testing for multiswitch-style widgets (ruler, grid row, timebase, etc.).

local FLEX = require("Utils.Core.flex_layout")
local SLIDE_OUT = require("Utils.Chips.chip_row_slide_out")
local MS_LAYOUT = require("Utils.Chips.chip_row_multiswitch_layout")

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

--- Inset for chip content inside a toolbar button: clears rounded chrome for buttons with rounding.
function M.button_rounding_content_pad(target)
    local button = nil
    if target and type(target) == "table" then
        if target._host_button then
            button = target._host_button
        elseif target.button then
            button = target.button
        elseif target.action_id or target.isSeparator or target.is_alone ~= nil or target.is_section_start ~= nil or target.is_visual_section_start ~= nil then
            button = target
        end
    end
    if not button then
        button = _G.CURRENT_HOST_BUTTON
    end

    if button and type(button) == "table" then
        if button.isSeparator and button:isSeparator() then
            return 0
        end
        local has_rounding = (not CONFIG.UI.USE_GROUPING)
            or button.is_alone
            or button.is_visual_section_start
            or button.is_visual_section_end
            or button.is_section_start
            or button.is_section_end
        if not has_rounding then
            return 0
        end
    end

    return math.max(0, math.floor((tonumber(CONFIG.SIZES.ROUNDING) or 0) / 2))
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
    if layout and layout.body_height then
        return layout.body_height
    end
    local h = (layout and layout.height) or CONFIG.SIZES.HEIGHT
    if layout and layout.is_vertical and (layout.title_height or 0) > 0 then
        h = h - layout.title_height
    end
    return h
end

--- Place a content block vertically within the widget body (horizontal + vertical toolbars).
function M.center_content_y(rel_y, layout, content_h, min_top_pad)
    min_top_pad = min_top_pad or 0
    local body_h = M.widget_body_height(layout)
    if not body_h or body_h <= 0 or not content_h or content_h <= 0 then
        return rel_y + min_top_pad
    end
    local extra = body_h - content_h
    if extra <= 0 then
        return rel_y + min_top_pad
    end
    return rel_y + math.max(min_top_pad, extra * 0.5)
end

function M.max_caption_width(ctx, entries, caption_for)
    local max_tw = 0
    for _, e in ipairs(entries or {}) do
        local text = caption_for and caption_for(e) or require("Utils.Chips.chip_multiswitch").chip_caption(e)
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
    local inset = M.button_rounding_content_pad(options)
    local pad_x = (options.pad_x or 4) + inset
    local cell_w = M.uniform_chip_cell_width(ctx, entries, options)
    local n = #(entries or {})
    return pad_x * 2 + n * cell_w + gap * math.max(0, n - 1)
end

function M.uniform_multiswitch_width(ctx, entries, cols, options)
    options = options or {}
    local gap = options.chip_gap or M.CHIP_GAP
    local inset = M.button_rounding_content_pad(options)
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

--- Horizontally center a content block inside a toolbar button.
function M.center_block_x(rel_x, render_width, block_w, pad_x)
    pad_x = pad_x or 0
    return rel_x + pad_x + math.max(0, (render_width - pad_x * 2 - block_w) / 2)
end

--- Two stacked toolbar rows: returns y0 (top row), y1 (bottom row), total_h.
function M.toolbar_two_row_stack(rel_y, body_h, row_h, gap)
    gap = gap or M.TOOLBAR_STACK_GAP
    local total_h = row_h * 2 + gap
    local y0 = rel_y + (body_h - total_h) / 2
    return y0, y0 + row_h + gap, total_h
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
    local chip_gap = opts.chip_gap or M.CHIP_GAP
    local inset = M.button_rounding_content_pad(opts or layout)
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
    local body_h = M.widget_body_height(layout)
    local start_y
    if is_vertical then
        -- Vertical: getLayoutHeight sizes body to pad + wrapped lines; anchor from top inset.
        start_y = rel_y + pad_y
    else
        -- Horizontal: body is toolbar row height; center chip block (no stacked top pad).
        start_y = rel_y + math.max(0, (body_h - total_h) * 0.5)
    end
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
    local pad_x = (options.pad_x or 4) + M.button_rounding_content_pad(options)
    local chip_h = M.chip_line_height(ctx)
    local body_h = options.height or CONFIG.SIZES.HEIGHT
    local row_y = options.row_y or (rel_y + (body_h - chip_h) / 2)
    local usable_w = math.max(40, render_width - pad_x * 2)
    return M.layout_chip_strip(ctx, rel_x + pad_x, row_y, usable_w, entries, options)
end

function M.layout_entries_vertical(ctx, rel_x, rel_y, render_width, entries, options)
    options = options or {}
    local layout = options.layout
    local inset = M.button_rounding_content_pad(options)
    local pad_x = (options.pad_x or 4) + inset
    local pad_y = (options.pad_y or 4) + inset
    local gap = options.chip_gap or M.CHIP_GAP
    local chip_h = M.chip_line_height(ctx)
    local usable_w = math.max(40, render_width - pad_x * 2)
    local x = rel_x + pad_x
    local total_h = #entries * chip_h + math.max(0, #entries - 1) * gap
    local y = M.center_content_y(rel_y, layout, total_h, pad_y)
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
    local inset = M.button_rounding_content_pad(options)
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
    local pad = (options.pad_y or 4) + M.button_rounding_content_pad(options)
    return pad * 2 + n_entries * chip_h + math.max(0, n_entries - 1) * gap
end

function M.standard_horizontal_or_vertical_height(ctx, n_entries, is_vertical_toolbar, options, inner_w)
    if not is_vertical_toolbar then
        return CONFIG.SIZES.HEIGHT
    end
    return math.max(CONFIG.SIZES.HEIGHT or 28, M.vertical_toolbar_height(ctx, n_entries, options, inner_w))
end

--- Centered subset row for widget browser preview; returns nil if too narrow.
function M.preview_entries_row(ctx, rel_x, rel_y, render_width, preview_ids, all_entries, options)
    options = options or {}
    local gap = options.chip_gap or M.CHIP_GAP
    local min_w = options.min_chip_w or 24
    local pad_x = (options.pad_x or 4) + M.button_rounding_content_pad(options)
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
