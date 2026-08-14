-- Utils/Widget/slider_quick_chips.lua
-- Preset chip row for pan/spread-style sliders (-100 … 100). Slide-out only.

local ROW = require("Utils.Chips.chip_row")
local CHIP_MS = require("Utils.Chips.chip_multiswitch")
local DRAWING = require("Utils.Draw.drawing")
local ICON_FONTS = require("Utils.Core.icon_fonts")
local BASE = require("Utils.Widget.chip_widget_base")
local SLIDE_HOST = require("Utils.Widget.slide_out_chip_host")

local M = {}

M.PREFIX = "iqv_"

local ENTRIES = {
    { id = "m100", short_label = "-100", value = -100 },
    { id = "m50", short_label = "-50", value = -50 },
    { id = "z", short_label = "0", value = 0 },
    { id = "p50", short_label = "50", value = 50 },
    { id = "p100", short_label = "100", value = 100 },
}

CHIP_MS.normalize_chip_entries(ENTRIES)

local CHIP_LAYOUT_OPTS = {
    pad = 4,
    chip_pad_h = 6,
    min_chip_w = 16,
}

function M.entry_by_id(id, entries)
    return BASE.mode_by_id(entries or ENTRIES, id)
end

local function widget_entries(widget)
    return (widget and widget._quick_chip_entries) or ENTRIES
end

local function widget_entry_rows(widget)
    if widget and widget._quick_chip_entry_rows then
        return widget._quick_chip_entry_rows
    end
    return { widget_entries(widget) }
end

local function widget_prefix(widget)
    return (widget and widget._quick_chip_prefix) or M.PREFIX
end

local function widget_match_tolerance(widget)
    return (widget and widget._quick_chip_match_tolerance) or 0.51
end

local function widget_slide_toggles(widget)
    return (widget and widget._quick_slide_toggles) or nil
end

local TOGGLE_SUB_PREFIX = "tg_"

local function find_entry(widget, id)
    for _, row in ipairs(widget_entry_rows(widget)) do
        local e = BASE.mode_by_id(row, id)
        if e then
            return e
        end
    end
    return nil
end

local function entry_is_toggle(entry)
    return entry and entry.toggle == true
end

local function entry_is_icon(entry)
    return entry and type(entry.icon) == "string" and entry.icon ~= ""
end

local function chip_entry(chip)
    return chip and (chip.mode or chip.entry)
end

local function entry_selected(widget, entry, tol)
    if not entry then
        return false
    end
    if entry_is_toggle(entry) then
        return entry.get_state and entry.get_state(widget) == true
    end
    if entry.delta then
        return false
    end
    local v = entry.value
    if v == nil then
        return false
    end
    return math.abs((widget.value or 0) - v) < tol
end

local function find_toggle(widget, id)
    local toggles = widget_slide_toggles(widget)
    if not toggles then
        return nil
    end
    for _, t in ipairs(toggles) do
        if t.id == id then
            return t
        end
    end
    return nil
end


local function toggle_row_band_height(ctx, opts)
    local chip_h = ROW.chip_line_height(ctx)
    local pad = ROW.slide_out_pad(opts)
    return chip_h + pad
end

local function planned_toggle_row_width(ctx, toggles, opts)
    if not toggles or #toggles < 1 then
        return 0
    end
    local chip_h = ROW.chip_line_height(ctx)
    local pad = ROW.slide_out_pad(opts)
    if #toggles == 1 and entry_is_icon(toggles[1]) then
        return chip_h + pad * 2
    end
    return ROW.uniform_chip_row_width(ctx, toggles, opts) + pad * 2
end

local function layout_toggle_row(ctx, widget, rel_x, y, render_width, edges)
    local toggles = widget_slide_toggles(widget)
    if not toggles or #toggles < 1 then
        return {}, 0
    end
    CHIP_MS.normalize_chip_entries(toggles)
    local opts = {
        pad_x = 4,
        chip_pad_h = 6,
        min_chip_w = 36,
        slide_out = true,
        slide_out_edges = edges or { top = false, bottom = true, left = true, right = true },
    }
    local band_h = toggle_row_band_height(ctx, opts)
    local chips = ROW.layout_slide_out_multiswitch(ctx, rel_x, y, render_width, band_h, toggles, opts, { rows = 1, cols = #toggles })
    for _, c in ipairs(chips) do
        c._slide_toggle = true
    end
    return chips, band_h
end

function M.effective_show(_widget, _layout)
    return false
end

function M.effective_show_for_toolbar(_widget, _is_vertical_toolbar)
    return false
end

function M.min_chips_stripe_width(ctx)
    return ROW.uniform_chip_row_width(ctx, ENTRIES, CHIP_LAYOUT_OPTS)
end

function M.get_layout_width(widget, _ctx, _is_vertical_toolbar)
    return widget.width or 120
end

function M.get_layout_height(_widget, _ctx, _inner_w, _is_vertical_toolbar)
    return CONFIG.SIZES.HEIGHT
end

local function entry_rows_content_height(ctx, entry_rows, row_plans)
    local chip_h = ROW.chip_line_height(ctx)
    local gap = CHIP_LAYOUT_OPTS.chip_gap or ROW.CHIP_GAP
    local content_h = 0
    for i, row in ipairs(entry_rows) do
        local rp = row_plans and row_plans[i] or {}
        local row_rows = rp.rows or 1
        content_h = content_h + row_rows * chip_h + math.max(0, row_rows - 1) * gap
        if i < #entry_rows then
            content_h = content_h + gap
        end
    end
    return content_h
end

local function row_layout_opts(widget)
    if widget._slide_out_chip_rows then
        local opts = {}
        for k, v in pairs(CHIP_LAYOUT_OPTS) do
            opts[k] = v
        end
        opts.rows = widget._slide_out_chip_rows
        return opts
    end
    return CHIP_LAYOUT_OPTS
end

function M.cache_slide_plan(widget, ctx, host_w, host_h, layout)
    local entry_rows = widget_entry_rows(widget)
    local toggles = widget_slide_toggles(widget)
    local toggle_band_h = 0
    local toggle_row_w = 0
    if toggles and #toggles > 0 then
        toggle_band_h = toggle_row_band_height(ctx, CHIP_LAYOUT_OPTS)
        toggle_row_w = planned_toggle_row_width(ctx, toggles, CHIP_LAYOUT_OPTS)
    end
    return ROW.cache_stacked_slide_out_plan(widget, ctx, host_w, host_h, layout, entry_rows, function(_i, _row)
        return row_layout_opts(widget)
    end, {
        row_gap = CHIP_LAYOUT_OPTS.chip_gap or ROW.CHIP_GAP,
        options = CHIP_LAYOUT_OPTS,
        toggle_band_h = toggle_band_h,
        toggle_row_w = toggle_row_w,
    })
end

function M.layout_slide_out_chips(ctx, widget, rel_x, rel_y, render_width, panel_h)
    local plan = widget._slide_out_plan
    if not plan then
        return {}
    end
    local entry_rows = widget_entry_rows(widget)
    local band_h = panel_h or plan.h or ROW.chip_line_height(ctx)
    local chip_h = ROW.chip_line_height(ctx)
    local gap = CHIP_LAYOUT_OPTS.chip_gap or ROW.CHIP_GAP
    local toggles = widget_slide_toggles(widget)
    local toggle_reserve = (toggles and #toggles > 0) and (gap + toggle_row_band_height(ctx, CHIP_LAYOUT_OPTS)) or 0
    local preset_band_h = band_h - toggle_reserve

    local preset_chips
    if #entry_rows < 2 then
        local rp = plan.row_plans and plan.row_plans[1] or plan
        local preset_opts = row_layout_opts(widget)
        if toggles and #toggles > 0 then
            preset_opts.slide_out_edges = { top = true, bottom = false, left = true, right = true }
        end
        preset_chips = ROW.layout_slide_out_multiswitch(ctx, rel_x, rel_y, render_width, preset_band_h, entry_rows[1], preset_opts, rp)
    else
        local content_h = plan.content_h or entry_rows_content_height(ctx, entry_rows, plan.row_plans)
        if toggle_reserve > 0 then
            content_h = content_h - toggle_reserve + gap
        end
        preset_chips = {}
        local row_opts = row_layout_opts(widget)
        local pad = ROW.slide_out_pad(row_opts)
        local inner_h = math.max(0, preset_band_h - pad * 2)
        local y = rel_y + pad
        if content_h < inner_h then
            y = rel_y + pad + (inner_h - content_h) / 2
        end
        for i, row in ipairs(entry_rows) do
            local rp = plan.row_plans and plan.row_plans[i] or {}
            local row_rows = rp.rows or 1
            local row_h = row_rows * chip_h + math.max(0, row_rows - 1) * gap
            local row_chips = ROW.layout_slide_out_multiswitch(ctx, rel_x, y, render_width, row_h, row, row_layout_opts(widget), {
                rows = row_rows,
                cols = rp.cols or #row,
            })
            for _, c in ipairs(row_chips) do
                preset_chips[#preset_chips + 1] = c
            end
            y = y + row_h + gap
        end
    end

    local toggle_y = rel_y + preset_band_h + (toggle_reserve > 0 and gap or 0)
    local toggle_chips, _ = layout_toggle_row(ctx, widget, rel_x, toggle_y, render_width)
    local all = {}
    for _, c in ipairs(preset_chips or {}) do
        all[#all + 1] = c
    end
    for _, c in ipairs(toggle_chips) do
        all[#all + 1] = c
    end
    return all, toggle_chips
end

function M.slide_height(widget, ctx, host_w, host_h, layout)
    local plan = M.cache_slide_plan(widget, ctx, host_w, host_h, layout)
    return plan.h
end

function M.slide_width(widget, ctx, host_w, host_h, layout)
    local plan = M.cache_slide_plan(widget, ctx, host_w, host_h, layout)
    return SLIDE_HOST.panel_width(host_w, plan, layout)
end

local function draw_icon_toggle_chips(ctx, widget, coords, draw_list, btn_txt, btn_bg, chips, mx, my, alpha_factor)
    for _, c in ipairs(chips or {}) do
        local entry = chip_entry(c)
        if entry_is_icon(entry) then
            local hover = coords:pointInRelativeRect(mx, my, c.x, c.y, c.w, c.h)
            local active = entry_selected(widget, entry, 0)
            DRAWING.drawToolbarIconPillChip(ctx, coords, draw_list, c, btn_txt, btn_bg, {
                active = active,
                hover = hover,
                icon_path = entry.icon,
                icon_char = utf8.char(ICON_FONTS.ICON_CODEPOINT),
                icon_sz = c.h * 0.8,
                fallback_text = "P",
                rounding = ROW.CHIP_ROUND,
                alpha_factor = alpha_factor,
            })
        end
    end
end

local function draw_preset_chips(ctx, widget, coords, draw_list, btn_txt, btn_bg, chips, mx, my, alpha_factor)
    if not chips or #chips == 0 then
        return
    end
    local prefix = widget_prefix(widget)
    local enabled = not COLOR_UTILS.isWidgetDisabled(widget)
    local tol = widget_match_tolerance(widget)
    local has_icon = false
    for _, c in ipairs(chips) do
        if entry_is_icon(chip_entry(c)) then
            has_icon = true
            break
        end
    end
    SLIDE_HOST.draw_ms(ctx, widget, chips, coords, draw_list, btn_txt, btn_bg,
        SLIDE_HOST.slide_draw_opts(ctx, { slide_namespace = prefix .. "ms", chip_round = ROW.CHIP_ROUND }, widget, prefix, mx, my,
            function()
                return false
            end,
            { enabled = enabled, mixed = false },
            {
                alpha_factor = alpha_factor,
                grid_layout = true,
                label_for = function(c)
                    local entry = chip_entry(c)
                    if entry_is_icon(entry) then
                        return ""
                    end
                    return CHIP_MS.chip_caption(c.mode)
                end,
                is_selected_segment = function(c)
                    if c.blank then
                        return false
                    end
                    return entry_selected(widget, chip_entry(c), tol)
                end,
            }))
    if has_icon then
        draw_icon_toggle_chips(ctx, widget, coords, draw_list, btn_txt, btn_bg, chips, mx, my, alpha_factor)
    end
end

local function draw_toggle_chips(ctx, widget, coords, draw_list, btn_txt, btn_bg, chips, mx, my, alpha_factor)
    if not chips or #chips == 0 then
        return
    end
    local has_icon = false
    for _, c in ipairs(chips) do
        if entry_is_icon(chip_entry(c)) then
            has_icon = true
            break
        end
    end
    if has_icon then
        draw_icon_toggle_chips(ctx, widget, coords, draw_list, btn_txt, btn_bg, chips, mx, my, alpha_factor)
        return
    end
    local prefix = widget_prefix(widget)
    SLIDE_HOST.draw_ms(ctx, widget, chips, coords, draw_list, btn_txt, btn_bg, {
        mx = mx,
        my = my,
        enabled = not COLOR_UTILS.isWidgetDisabled(widget),
        chip_round = ROW.CHIP_ROUND,
        slide_namespace = prefix .. TOGGLE_SUB_PREFIX,
        alpha_factor = alpha_factor,
        multi_toggle = true,
        label_for = function(c)
            return CHIP_MS.chip_caption(c.mode)
        end,
        is_selected_segment = function(c)
            local tid = c.id or (c.mode and c.mode.id)
            local t = find_toggle(widget, tid)
            if t and t.get_state then
                return t.get_state(widget) == true
            end
            return false
        end,
    })
end

local function cached_layout_slide_out_chips(ctx, widget, rel_x, rel_y, render_width, panel_h)
    local cache_key = string.format("%s|%s|%s|%s", rel_x, rel_y, render_width, panel_h or 0)
    local frame_time = _G.FRAME_TIME
    if frame_time and widget._slide_chip_layout_frame == frame_time and widget._slide_chip_layout_key == cache_key then
        return widget._slide_chip_layout_all, widget._slide_chip_layout_toggle
    end
    local all_chips, toggle_chips = M.layout_slide_out_chips(ctx, widget, rel_x, rel_y, render_width, panel_h)
    if frame_time then
        widget._slide_chip_layout_frame = frame_time
        widget._slide_chip_layout_key = cache_key
        widget._slide_chip_layout_all = all_chips
        widget._slide_chip_layout_toggle = toggle_chips
    end
    return all_chips, toggle_chips
end

function M.draw_slide_out(ctx, widget, rel_x, rel_y, render_width, coords, draw_list, btn_txt, btn_bg, alpha_factor, layout)
    local panel_h = widget._slide_panel_h or widget:slide_height(ctx, widget._slide_host_w, widget._slide_host_h, layout)
    local all_chips, toggle_chips = cached_layout_slide_out_chips(ctx, widget, rel_x, rel_y, render_width, panel_h)
    if not all_chips or #all_chips == 0 then
        return
    end
    local mx, my = coords:getRelativeMouse()
    local preset = {}
    local toggle_set = {}
    if toggle_chips then
        for _, c in ipairs(toggle_chips) do
            toggle_set[c.id or (c.mode and c.mode.id)] = true
        end
    end
    for _, c in ipairs(all_chips) do
        local cid = c.id or (c.mode and c.mode.id)
        if not toggle_set[cid] then
            preset[#preset + 1] = c
        end
    end
    draw_preset_chips(ctx, widget, coords, draw_list, btn_txt, btn_bg, preset, mx, my, alpha_factor)
    draw_toggle_chips(ctx, widget, coords, draw_list, btn_txt, btn_bg, toggle_chips or {}, mx, my, alpha_factor)
end

function M.hit_test_slide_out(ctx, widget, coords, rel_x, rel_y, render_width, layout)
    local panel_h = widget._slide_panel_h or widget:slide_height(ctx, widget._slide_host_w, widget._slide_host_h, layout)
    local all_chips, toggle_chips = cached_layout_slide_out_chips(ctx, widget, rel_x, rel_y, render_width, panel_h)
    if (not all_chips or #all_chips == 0) and (not toggle_chips or #toggle_chips == 0) then
        return nil
    end
    local mx, my = coords:getRelativeMouse()
    local prefix = widget_prefix(widget)
    local toggle_set = {}
    if toggle_chips then
        for _, c in ipairs(toggle_chips) do
            toggle_set[c.id or (c.mode and c.mode.id)] = true
        end
    end
    local preset = {}
    for _, c in ipairs(all_chips or {}) do
        local cid = c.id or (c.mode and c.mode.id)
        if not toggle_set[cid] then
            preset[#preset + 1] = c
        end
    end
    local hit = BASE.hit_test_chips(mx, my, coords, preset, prefix)
    if hit then
        return hit
    end
    return BASE.hit_test_chips(mx, my, coords, toggle_chips or {}, prefix .. TOGGLE_SUB_PREFIX)
end

function M.hit_test_subcontrol(ctx, widget, coords, rel_x, rel_y, render_width, layout, is_slide_out)
    if is_slide_out then
        return M.hit_test_slide_out(ctx, widget, coords, rel_x, rel_y, render_width, layout)
    end
    return nil
end

function M.on_subcontrol_click(widget, sub_id)
    if COLOR_UTILS.isWidgetDisabled(widget) then
        return false
    end
    local prefix = widget_prefix(widget)
    local toggle_id = BASE.strip_click_id(prefix .. TOGGLE_SUB_PREFIX, sub_id)
    if toggle_id then
        local t = find_toggle(widget, toggle_id)
        if t and t.on_click then
            t.on_click(widget)
            return true
        end
        return false
    end
    local id = BASE.strip_click_id(prefix, sub_id)
    if not id then
        return false
    end
    local e = find_entry(widget, id)
    if not e then
        return false
    end
    if entry_is_toggle(e) then
        if e.on_click then
            e.on_click(widget)
        end
        return true
    end
    local new_value
    if e.delta then
        new_value = (widget.value or 0) + e.delta
        local min_v = widget.min_value or -math.huge
        local max_v = widget.max_value or math.huge
        new_value = math.max(min_v, math.min(max_v, new_value))
    else
        new_value = e.value
    end
    widget.value = new_value
    if widget.setValue then
        pcall(widget.setValue, new_value)
    end
    return true
end

function M.attach(widget, attach_opts)
    attach_opts = attach_opts or {}
    local prefix = attach_opts.prefix or M.PREFIX

    if attach_opts.entry_rows then
        for _, row in ipairs(attach_opts.entry_rows) do
            CHIP_MS.normalize_chip_entries(row)
        end
        widget._quick_chip_entry_rows = attach_opts.entry_rows
        widget._quick_chip_entries = attach_opts.entry_rows[1]
    else
        local entries = attach_opts.entries or ENTRIES
        CHIP_MS.normalize_chip_entries(entries)
        widget._quick_chip_entries = entries
    end

    widget._quick_chip_prefix = prefix
    if attach_opts.match_tolerance then
        widget._quick_chip_match_tolerance = attach_opts.match_tolerance
    end
    if attach_opts.slide_toggles then
        widget._quick_slide_toggles = attach_opts.slide_toggles
    end

    widget.slider_quick_chips = true
    if attach_opts.slide_out_chip_rows then
        widget._slide_out_chip_rows = attach_opts.slide_out_chip_rows
    end
    if attach_opts.slide_out then
        widget._slide_out_mode = true
        widget.slide_height = function(self, ctx, host_w, host_h, layout)
            return M.slide_height(self, ctx, host_w, host_h, layout)
        end
        widget.slide_width = function(self, ctx, host_w, host_h, layout)
            return M.slide_width(self, ctx, host_w, host_h, layout)
        end
    end

    widget.getLayoutWidth = function(self, ctx, is_vertical_toolbar)
        return M.get_layout_width(self, ctx, is_vertical_toolbar)
    end

    widget.getLayoutHeight = function(self, ctx, inner_w, is_vertical_toolbar)
        return M.get_layout_height(self, ctx, inner_w, is_vertical_toolbar)
    end

    widget.hitTestSubcontrols = function(self, ctx, coords, rel_x, rel_y, render_width, layout, is_slide_out)
        return M.hit_test_subcontrol(ctx, self, coords, rel_x, rel_y, render_width, layout, is_slide_out)
    end

    widget.onSubcontrolClick = function(self, sub_id)
        return M.on_subcontrol_click(self, sub_id)
    end
end

return M
