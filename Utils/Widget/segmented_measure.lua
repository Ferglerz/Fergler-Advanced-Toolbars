-- Segmented widget toolbar and slide-out dimension measurement.

local CHIP_ROW = require("Utils.Chips.chip_row")
local LAYOUT = require("Utils.Widget.segmented_layout")

local M = {}

function M.measure_horizontal_slide_out_height(ctx, rows_config, inner_gap, gap, panel_w)
    local grid_heights = {}
    for _, entry in ipairs(LAYOUT.get_visible_rows(rows_config, true)) do
        for _, seg in ipairs(entry.row.segments or {}) do
            if seg.type == "multiswitch" and seg.modes and #seg.modes > 0 then
                local opts = {
                    pad_x = 4,
                    chip_gap = inner_gap,
                    chip_pad_h = 6,
                    min_chip_w = seg.min_chip_w or 24,
                    rows = seg.rows,
                }
                local _, grid_h = CHIP_ROW.plan_horizontal_slide_out_grid(ctx, seg.modes, opts, panel_w or 0)
                grid_heights[#grid_heights + 1] = grid_h
            end
        end
    end
    return CHIP_ROW.measure_horizontal_stacked_slide_out_height(ctx, grid_heights, gap)
end

local function accumulate_row_width(self, ctx, entry, w, pad_x, gap, inner_gap, include_multiswitch)
    local row_w = pad_x
    for si, seg in ipairs(entry.row.segments or {}) do
        if seg.type == "readout" then
            local trailing = 0
            for j = si + 1, #(entry.row.segments or {}) do
                trailing = trailing + LAYOUT.estimate_segment_width(self, ctx, entry.row.segments[j], w, inner_gap) + gap
            end
            local avail_w = math.max(20, w - row_w - trailing - pad_x)
            local rw = select(1, LAYOUT.measure_readout_width(self, ctx, seg, avail_w))
            row_w = row_w + rw + gap
        elseif seg.type == "toggle" then
            local tw
            if seg.get_width then
                tw = seg.get_width(self, ctx, w)
            else
                local fallback = seg.get_label and seg.get_label(self, ctx, 0) or seg.label or ""
                tw = (reaper.ImGui_CalcTextSize(ctx, fallback) or 0) + 16
                if tw < (seg.min_width or 0) then tw = seg.min_width end
            end
            row_w = row_w + (tw or 0) + gap
        elseif include_multiswitch and seg.type == "multiswitch" then
            local ms_w = CHIP_ROW.uniform_chip_row_width(ctx, seg.modes, {
                pad_x = 0, chip_gap = inner_gap, chip_pad_h = 6, min_chip_w = seg.min_chip_w or 24,
            })
            row_w = row_w + ms_w + gap
        end
    end
    return row_w
end

function M.measure_toolbar_width(self, ctx, rows_config, gap, inner_gap)
    local R = CHIP_ROW.button_rounding_content_pad()
    local pad_x = 4 + R
    local w = self.width or 120
    for _, entry in ipairs(LAYOUT.get_visible_rows(rows_config, false)) do
        local row_w = accumulate_row_width(self, ctx, entry, w, pad_x, gap, inner_gap, true)
        w = math.max(w, row_w + pad_x - gap)
    end
    return w
end

function M.measure_host_toolbar_width(self, ctx, rows_config, gap, inner_gap)
    local R = CHIP_ROW.button_rounding_content_pad()
    local pad_x = 4 + R
    local w = self.width or 120
    for _, entry in ipairs(LAYOUT.get_visible_rows(rows_config, false)) do
        local row_w = accumulate_row_width(self, ctx, entry, w, pad_x, gap, inner_gap, false)
        w = math.max(w, row_w + pad_x - gap)
    end
    return w
end

local function multiswitch_slide_opts(seg, inner_gap)
    return {
        pad_x = 4,
        chip_gap = inner_gap,
        chip_pad_h = 6,
        min_chip_w = seg.min_chip_w or 24,
        rows = seg.rows,
    }
end

local function toggle_segment_width(ctx, seg)
    local fallback = seg.get_label and seg.get_label(nil, ctx, 0) or seg.label or ""
    local tw = (reaper.ImGui_CalcTextSize(ctx, fallback) or 0) + 16
    if tw < (seg.min_width or 0) then
        tw = seg.min_width
    end
    return tw or 0
end

function M.compute_slide_panel_dims(self, ctx, host_w, rows_config, gap, inner_gap)
    local max_w = host_w or 0
    local R = CHIP_ROW.button_rounding_content_pad()
    local pad_x = 4 + R
    for _, entry in ipairs(LAYOUT.get_visible_rows(rows_config, true)) do
        local row_w = 0
        local row_has_toggle = false
        for _, seg in ipairs(entry.row.segments or {}) do
            if seg.type == "multiswitch" and seg.modes and #seg.modes > 0 then
                local opts = multiswitch_slide_opts(seg, inner_gap)
                local w = select(1, CHIP_ROW.plan_horizontal_slide_out_content(ctx, seg.modes, opts, host_w))
                max_w = math.max(max_w, w or 0)
            elseif seg.type == "toggle" then
                row_has_toggle = true
                row_w = row_w + toggle_segment_width(ctx, seg) + gap
            end
        end
        if row_has_toggle then
            max_w = math.max(max_w, row_w + pad_x * 2 - gap)
        end
    end
    return max_w, M.measure_horizontal_slide_out_height(ctx, rows_config, inner_gap, gap, max_w)
end

return M
