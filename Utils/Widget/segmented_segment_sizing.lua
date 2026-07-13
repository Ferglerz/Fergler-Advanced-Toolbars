-- Shared segment width helpers for segmented_layout and segmented_measure.

local CHIP_ROW = require("Utils.Chips.chip_row")

local M = {}

function M.multiswitch_opts(seg, inner_gap)
    return {
        pad_x = 4,
        chip_gap = inner_gap,
        chip_pad_h = 6,
        min_chip_w = seg.min_chip_w or 24,
        rows = seg.rows,
    }
end

function M.toggle_text_width(ctx, self, seg, render_width)
    if seg.get_width then
        return seg.get_width(self, ctx, render_width)
    end
    if seg.max_width_labels then
        local max_tw = 0
        for _, l in ipairs(seg.max_width_labels) do
            local w = reaper.ImGui_CalcTextSize(ctx, l) or 0
            if w > max_tw then
                max_tw = w
            end
        end
        local tw = max_tw + 16
        return math.max(tw, seg.min_width or 0)
    end
    local fallback = seg.get_label and seg.get_label(self, ctx, 0) or seg.label or ""
    local tw = (reaper.ImGui_CalcTextSize(ctx, fallback) or 0) + 16
    return math.max(tw, seg.min_width or 0)
end

function M.multiswitch_uniform_width(ctx, seg, inner_gap)
    return CHIP_ROW.uniform_chip_row_width(ctx, seg.modes, {
        pad_x = 0,
        chip_gap = inner_gap,
        chip_pad_h = 6,
        min_chip_w = seg.min_chip_w or 24,
    })
end

return M
