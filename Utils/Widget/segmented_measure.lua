-- Segmented widget toolbar and slide-out dimension measurement.

local CHIP_ROW = require("Utils.Chips.chip_row")
local LAYOUT = require("Utils.Widget.segmented_layout")
local SEG_SIZING = require("Utils.Widget.segmented_segment_sizing")

local M = {}

function M.measure_horizontal_slide_out_height(ctx, rows_config, inner_gap, gap, panel_w)
    local grid_heights = {}
    for _, entry in ipairs(LAYOUT.get_visible_rows(rows_config, true)) do
        for _, seg in ipairs(entry.row.segments or {}) do
            if seg.type == "multiswitch" and seg.modes and #seg.modes > 0 then
                local opts = SEG_SIZING.multiswitch_opts(seg, inner_gap)
                local _, grid_h = CHIP_ROW.plan_host_slide_out_grid(ctx, seg.modes, opts, panel_w or 0)
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
            row_w = row_w + SEG_SIZING.toggle_text_width(ctx, self, seg, w) + gap
        elseif include_multiswitch and seg.type == "multiswitch" then
            row_w = row_w + SEG_SIZING.multiswitch_uniform_width(ctx, seg, inner_gap) + gap
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

function M.compute_slide_panel_dims(self, ctx, host_w, rows_config, gap, inner_gap)
    local max_w = host_w or 0
    local R = CHIP_ROW.button_rounding_content_pad()
    local pad_x = 4 + R
    for _, entry in ipairs(LAYOUT.get_visible_rows(rows_config, true)) do
        local row_w = 0
        local row_has_toggle = false
        for _, seg in ipairs(entry.row.segments or {}) do
            if seg.type == "multiswitch" and seg.modes and #seg.modes > 0 then
                local opts = SEG_SIZING.multiswitch_opts(seg, inner_gap)
                local w = select(1, CHIP_ROW.plan_host_slide_out_content(ctx, seg.modes, opts, host_w))
                max_w = math.max(max_w, w or 0)
            elseif seg.type == "toggle" then
                row_has_toggle = true
                row_w = row_w + SEG_SIZING.toggle_text_width(ctx, self, seg, host_w) + gap
            end
        end
        if row_has_toggle then
            max_w = math.max(max_w, row_w + pad_x * 2 - gap)
        end
    end
    return max_w, M.measure_horizontal_slide_out_height(ctx, rows_config, inner_gap, gap, max_w)
end

return M
