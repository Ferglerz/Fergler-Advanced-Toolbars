-- Segmented widget row layout: visibility, segment sizing, full multi-row layout.

local CHIP_ROW = require("Utils.Chips.chip_row")
local DRAWING = require("Utils.Draw.drawing")

local M = {}

function M.get_visible_rows(rows_config, is_slide_out)
    local visible = {}
    for idx, row in ipairs(rows_config or {}) do
        if row.slide_only and not is_slide_out then
        elseif row.toolbar_only and is_slide_out then
        else
            visible[#visible + 1] = { index = idx, row = row }
        end
    end
    return visible
end

function M.estimate_segment_width(self, ctx, seg, render_width, inner_gap)
    if seg.type == "toggle" then
        if seg.get_width then
            return seg.get_width(self, ctx, render_width)
        end
        local fallback = seg.get_label and seg.get_label(self, ctx, 0) or seg.label or ""
        local tw = (reaper.ImGui_CalcTextSize(ctx, fallback) or 0) + 16
        return math.max(seg.min_width or 0, tw)
    elseif seg.type == "multiswitch" then
        return CHIP_ROW.uniform_chip_row_width(ctx, seg.modes, {
            pad_x = 0, chip_gap = inner_gap, chip_pad_h = 6, min_chip_w = seg.min_chip_w or 24,
        })
    end
    return 0
end

function M.measure_readout_width(self, ctx, seg, avail_w)
    local label = seg.get_label and seg.get_label(self, ctx) or seg.label or ""
    if seg.compact_two_line then
        local m = DRAWING.measureCompactReadout(ctx, label, avail_w, {
            font_scale = seg.compact_font_scale or 0.5,
        })
        if seg.flex then
            return avail_w, m.lines, m.font_size
        end
        return math.max(seg.min_width or 0, math.min(avail_w, m.width or 0)), m.lines, m.font_size
    end
    local tw = reaper.ImGui_CalcTextSize(ctx, label) or 0
    if tw > avail_w and #label > 2 then
        local text = label
        while #text > 2 do
            local ell_w = reaper.ImGui_CalcTextSize(ctx, text .. "…") or 0
            if ell_w <= avail_w then
                break
            end
            text = text:sub(1, -2)
        end
        label = text .. "…"
        tw = reaper.ImGui_CalcTextSize(ctx, label) or avail_w
    end
    local rw = math.max(seg.min_width or 0, math.min(avail_w, tw))
    return rw, { label }, nil
end

local function trailing_segment_width(self, ctx, segments, from_index, render_width, gap, inner_gap)
    local trailing = 0
    for j = from_index + 1, #segments do
        trailing = trailing + M.estimate_segment_width(self, ctx, segments[j], render_width, inner_gap) + gap
    end
    return trailing
end

local function single_segment_centered(visible_rows, row, is_slide_out)
    return #visible_rows == 1 and #(row.segments or {}) == 1 and not is_slide_out
end

local function layout_readout(ctx, params)
    local self, seg, seg_id, row, cfg_idx, i = params.self, params.seg, params.seg_id, params.row, params.cfg_idx, params.i
    local rel_x, render_width, x_offset, y_offset, chip_h, pad_x, gap = params.rel_x, params.render_width, params.x_offset, params.y_offset, params.chip_h, params.pad_x, params.gap
    local visible_rows, is_slide_out, inner_gap = params.visible_rows, params.is_slide_out, params.inner_gap

    local label = seg.get_label and seg.get_label(self, ctx) or seg.label or ""
    local pad = seg.pad_x or pad_x
    local trailing = trailing_segment_width(self, ctx, row.segments or {}, i, render_width, gap, inner_gap)
    local avail_w = math.max(20, render_width - (x_offset - rel_x) - trailing - pad)
    local rw, lines, font_size = M.measure_readout_width(self, ctx, seg, avail_w)
    local tx = single_segment_centered(visible_rows, row, is_slide_out)
        and CHIP_ROW.center_block_x(rel_x, render_width, rw, pad)
        or x_offset
    local layout = {
        type = "readout",
        rect = { x = tx, y = y_offset, w = rw, h = chip_h },
        label = (#lines == 1 and lines[1]) or label,
        lines = lines,
        font_size = font_size,
        seg = seg,
    }
    return layout, tx + rw + gap
end

local function toggle_text_width(ctx, self, seg, render_width)
    if seg.get_width then
        return seg.get_width(self, ctx, render_width)
    end
    if seg.max_width_labels then
        local max_tw = 0
        for _, l in ipairs(seg.max_width_labels) do
            local w = reaper.ImGui_CalcTextSize(ctx, l) or 0
            if w > max_tw then max_tw = w end
        end
        local tw = max_tw + 16
        return math.max(tw, seg.min_width or 0)
    end
    local fallback = seg.get_label and seg.get_label(self, ctx, 0) or seg.label or ""
    local tw = (reaper.ImGui_CalcTextSize(ctx, fallback) or 0) + 16
    return math.max(tw, seg.min_width or 0)
end

local function layout_toggle(ctx, params)
    local self, seg, seg_id, row = params.self, params.seg, params.seg_id, params.row
    local rel_x, render_width, x_offset, y_offset, chip_h, pad_x, gap = params.rel_x, params.render_width, params.x_offset, params.y_offset, params.chip_h, params.pad_x, params.gap
    local visible_rows, is_slide_out = params.visible_rows, params.is_slide_out

    local tw = toggle_text_width(ctx, self, seg, render_width)
    local label = seg.get_label and seg.get_label(self, ctx, tw) or seg.label or ""
    local tx = (#visible_rows == 1 and not is_slide_out and #(row.segments or {}) == 1)
        and CHIP_ROW.center_block_x(rel_x, render_width, tw, pad_x)
        or x_offset
    local layout = {
        type = "toggle",
        rect = { x = tx, y = y_offset, w = tw, h = chip_h },
        label = label,
        seg = seg,
    }
    return layout, tx + tw + gap
end

local function multiswitch_slide_edges(slide_row_count)
    if slide_row_count > 1 then
        return { top = false, bottom = false, left = true, right = true }
    end
    return { top = true, bottom = true, left = true, right = true }
end

local function layout_multiswitch(ctx, params)
    local self, seg, seg_id, row, cfg_idx = params.self, params.seg, params.seg_id, params.row, params.cfg_idx
    local rel_x, rel_y, render_width, layout, x_offset, y_offset, chip_h, pad_x, gap = params.rel_x, params.rel_y, params.render_width, params.layout, params.x_offset, params.y_offset, params.chip_h, params.pad_x, params.gap
    local is_slide_out, inner_gap, visible_rows, slide_row_count, slide_panel_h = params.is_slide_out, params.inner_gap, params.visible_rows, params.slide_row_count, params.slide_panel_h

    local grid_x = is_slide_out and rel_x or x_offset
    local host_is_vert = layout and layout.is_vertical
    local grid_y
    if is_slide_out then
        grid_y = (host_is_vert and #visible_rows == 1) and rel_y or y_offset
    else
        grid_y = y_offset
    end
    local grid_h = is_slide_out and slide_panel_h or chip_h
    local avail_w = is_slide_out and render_width or math.max(30, render_width - (x_offset - rel_x) - pad_x)
    local ms_w = CHIP_ROW.uniform_chip_row_width(ctx, seg.modes, {
        pad_x = 0, chip_gap = inner_gap, chip_pad_h = 6, min_chip_w = seg.min_chip_w or 24,
    })
    local grid_w = is_slide_out and render_width or math.max(ms_w, avail_w)
    local ms_opts = {
        pad_x = 4,
        chip_gap = inner_gap,
        chip_pad_h = 6,
        min_chip_w = seg.min_chip_w or 24,
        rows = seg.rows,
        height = grid_h,
        sizing = seg.sizing,
    }
    if is_slide_out then
        ms_opts.slide_out = true
        ms_opts.slide_out_edges = multiswitch_slide_edges(slide_row_count)
        local _, planned_grid_h, plan_rows = CHIP_ROW.plan_horizontal_slide_out_grid(ctx, seg.modes, ms_opts, render_width)
        ms_opts.rows = plan_rows
        grid_h = planned_grid_h
        ms_opts.height = (slide_row_count == 1) and slide_panel_h or grid_h
    elseif not is_slide_out then
        ms_opts.pad_x = 0
    end
    local chips, outer_h = CHIP_ROW.layout_multiswitch_grid(ctx, grid_x, grid_y, grid_w, { height = grid_h }, seg.modes, ms_opts)
    local seg_layout = {
        type = "multiswitch",
        rect = { x = grid_x, y = grid_y, w = grid_w, h = outer_h },
        chips = chips,
        seg = seg,
        seg_row = cfg_idx,
    }
    local extra = {
        row_max_h = outer_h,
        slide_content_h = (is_slide_out and outer_h) or nil,
        slide_grid_h = is_slide_out and grid_h or nil,
    }
    return seg_layout, grid_x + ms_w + gap, extra
end

local SEGMENT_LAYOUT = {
    readout = layout_readout,
    toggle = layout_toggle,
    multiswitch = layout_multiswitch,
}

local function row_has_segment_types(row)
    local has_toggle, has_multiswitch = false, false
    for _, seg in ipairs(row.segments or {}) do
        if seg.type == "toggle" then
            has_toggle = true
        elseif seg.type == "multiswitch" then
            has_multiswitch = true
        end
    end
    return has_toggle, has_multiswitch
end

local function center_slide_out_toggle_row(rel_x, rel_y, render_width, slide_panel_h, layouts, row, cfg_idx, row_start_x, row_max_x, y_offset, content_w, content_h, slide_row_idx, slide_row_count, gap)
    local edges = {
        top = slide_row_idx == 1,
        bottom = slide_row_idx == slide_row_count,
        left = true,
        right = true,
    }
    local cx, cy, cw, ch = CHIP_ROW.slide_out_content_rect(
        rel_x, rel_y, render_width, slide_panel_h, {}, edges
    )
    local x0, y0 = cx, cy
    if content_w < cw or content_h < ch then
        x0, y0 = CHIP_ROW.center_grid_in_panel(cx, cy, cw, ch, content_w, content_h)
    end
    local dx = x0 - row_start_x
    local dy = y0 - y_offset
    if dx == 0 and dy == 0 then
        return row_max_x
    end
    for i, seg in ipairs(row.segments or {}) do
        local seg_id = "r" .. cfg_idx .. "_s" .. i
        local l = layouts[seg_id]
        if l and l.rect then
            l.rect.x = l.rect.x + dx
            l.rect.y = l.rect.y + dy
        end
    end
    return row_max_x + dx
end

function M.layout_all_rows(self, ctx, rel_x, rel_y, render_width, layout, is_slide_out, rows_config, gap, inner_gap)
    local chip_h = reaper.ImGui_GetTextLineHeight(ctx) + CHIP_ROW.CHIP_V_PAD * 2
    local R = CHIP_ROW.button_rounding_content_pad()
    local pad_x = 4 + R
    local pad_y = 4 + R

    local layouts = {}
    local y_offset = rel_y + pad_y
    local max_w_used = 0
    local slide_content_h = 0
    local slide_grid_heights = {}

    local visible_rows = M.get_visible_rows(rows_config, is_slide_out)
    local slide_row_count = is_slide_out and #visible_rows or 0
    local slide_outer_pad = is_slide_out and CHIP_ROW.slide_out_pad({ pad_x = 4 }) or 0
    local slide_panel_h = is_slide_out and (self._slide_panel_h or CHIP_ROW.widget_body_height(layout) or CONFIG.SIZES.HEIGHT)

    if is_slide_out then
        y_offset = rel_y
        if slide_row_count > 1 then
            y_offset = rel_y + slide_outer_pad
        end
    elseif #visible_rows == 1 then
        local h = CHIP_ROW.widget_body_height(layout)
        y_offset = rel_y + (h - chip_h) / 2
    end

    for slide_row_idx, entry in ipairs(visible_rows) do
        local cfg_idx = entry.index
        local row = entry.row
        local x_offset = rel_x + pad_x
        local row_max_x = x_offset
        local row_max_h = chip_h

        for i, seg in ipairs(row.segments or {}) do
            local handler = SEGMENT_LAYOUT[seg.type]
            if handler then
                local seg_id = "r" .. cfg_idx .. "_s" .. i
                local seg_layout, next_x, extra = handler(ctx, {
                    self = self,
                    seg = seg,
                    seg_id = seg_id,
                    row = row,
                    cfg_idx = cfg_idx,
                    i = i,
                    rel_x = rel_x,
                    rel_y = rel_y,
                    render_width = render_width,
                    layout = layout,
                    x_offset = x_offset,
                    y_offset = y_offset,
                    chip_h = chip_h,
                    pad_x = pad_x,
                    gap = gap,
                    inner_gap = inner_gap,
                    visible_rows = visible_rows,
                    is_slide_out = is_slide_out,
                    slide_row_count = slide_row_count,
                    slide_panel_h = slide_panel_h,
                })
                layouts[seg_id] = seg_layout
                x_offset = next_x
                row_max_x = math.max(row_max_x, x_offset)
                if extra then
                    if extra.row_max_h and extra.row_max_h > row_max_h then
                        row_max_h = extra.row_max_h
                    end
                    if extra.slide_content_h and extra.slide_content_h > slide_content_h then
                        slide_content_h = extra.slide_content_h
                    end
                    if extra.slide_grid_h then
                        slide_grid_heights[#slide_grid_heights + 1] = extra.slide_grid_h
                    end
                end
            end
        end

        local row_has_toggle, row_has_multiswitch = row_has_segment_types(row)
        if is_slide_out and row_has_toggle and not row_has_multiswitch then
            local row_start_x = rel_x + pad_x
            local content_w = row_max_x - row_start_x - gap
            row_max_x = center_slide_out_toggle_row(
                rel_x, rel_y, render_width, slide_panel_h, layouts, row, cfg_idx,
                row_start_x, row_max_x, y_offset, content_w, row_max_h,
                slide_row_idx, slide_row_count, gap
            )
        end

        if row_max_x - rel_x > max_w_used then
            max_w_used = row_max_x - rel_x
        end
        if slide_row_count > 1 and slide_row_idx == slide_row_count then
            row_max_h = row_max_h + slide_outer_pad
        end
        y_offset = y_offset + row_max_h + gap
    end

    local total_w = max_w_used + pad_x - gap
    if is_slide_out then
        if layout and layout.is_vertical then
            return layouts, total_w, slide_content_h or slide_panel_h or chip_h
        end
        return layouts, total_w, CHIP_ROW.measure_horizontal_stacked_slide_out_height(ctx, slide_grid_heights, gap)
    end
    return layouts, total_w, y_offset - rel_y - gap + pad_y
end

return M
