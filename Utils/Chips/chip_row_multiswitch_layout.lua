-- Multiswitch grid layout for toolbar buttons and slide-out panels.

local M = {}

function M.resolve_chip_cell_width(row, ctx, entries, usable_w, total, gap, min_w, options)
    local sizing = options.sizing or "uniform_text"
    if sizing == "fill" then
        local per_w = math.floor((usable_w - gap * (total - 1)) / total)
        return math.max(min_w, per_w)
    end
    if sizing == "uniform_text" and ctx and reaper.ImGui_CalcTextSize then
        return row.uniform_chip_cell_width(ctx, entries, options)
    end
    return min_w
end

function M.attach(row)
    local resolve_chip_cell_width = function(ctx, entries, usable_w, total, gap, min_w, options)
        return M.resolve_chip_cell_width(row, ctx, entries, usable_w, total, gap, min_w, options)
    end

    local center_grid_in_panel = row.center_grid_in_panel

    --- Grid layout for slide-out multiswitch panels; returns chips (same as layout_multiswitch_grid).
    function row.layout_slide_out_multiswitch(ctx, rel_x, rel_y, render_width, slide_height, entries, options, plan)
        options = options or {}
        local rows = plan and plan.rows
        if not rows then
            rows = select(3, row.plan_slide_out_panel(ctx, entries, options, {
                panel_w = render_width,
                panel_h = slide_height,
            }))
        end
        local apply_outer_pad = options.slide_out ~= false
        return row.layout_multiswitch_grid(ctx, rel_x, rel_y, render_width, { is_vertical = false }, entries, {
            slide_out = apply_outer_pad,
            rows = rows,
            min_chip_w = options.min_chip_w,
            chip_gap = options.chip_gap,
            chip_pad_h = options.chip_pad_h,
            caption_for = options.caption_for,
            slide_out_edges = options.slide_out_edges,
            height = slide_height,
        })
    end

    --- Equal-cell grid for multiswitch (row-major). Pads with `blank = true` chips to fill rows×cols.
    --- layout.is_vertical: narrow strip → up to 2 columns when width allows; else 1 column.
    --- Horizontal toolbar: up to 2 rows when two chip lines fit in CONFIG.SIZES.HEIGHT; else 1 row.
    --- Returns chips, outer_height (vertical includes symmetric vertical pad; horizontal = grid pixel height only).
    function row.layout_multiswitch_grid(ctx, rel_x, rel_y, width, layout, entries, options)
        options = options or {}
        local min_w = options.min_chip_w or 24
        local gap = options.chip_gap or row.CHIP_GAP
        local chip_h = row.chip_line_height(ctx)
        local inset = row.button_rounding_content_pad()
        local pad_x = (options.pad_x or 4) + inset
        local pad_y = (options.pad_y or 4) + inset
        local is_vert = layout and layout.is_vertical
        local slide_out = options.slide_out == true
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

        local grid_h = rows * chip_h + math.max(0, rows - 1) * gap
        local usable_w
        if slide_out then
            local edges = options.slide_out_edges
            local panel_h = options.height or grid_h
            local _, _, cw = row.slide_out_content_rect(rel_x, rel_y, width, panel_h, options, edges)
            usable_w = cw
        else
            usable_w = math.max(40, width - pad_x * 2)
        end
        local cell_w = resolve_chip_cell_width(ctx, entries, usable_w, cols, gap, min_w, slide_out and {
            sizing = "fill",
            min_chip_w = min_w,
            chip_gap = gap,
        } or options)
        local grid_w = cols * cell_w + (cols - 1) * gap
        local x0
        local y0
        local outer_h
        if is_vert then
            x0 = rel_x + pad_x + math.max(0, (width - pad_x * 2 - grid_w) / 2)
            y0 = rel_y + pad_y
            outer_h = pad_y + grid_h + pad_y
        elseif slide_out then
            local panel_h = options.height or grid_h
            local edges = options.slide_out_edges
            local cx, cy, cw, ch = row.slide_out_content_rect(rel_x, rel_y, width, panel_h, options, edges)
            x0, y0 = cx, cy
            if grid_w < cw or grid_h < ch then
                x0, y0 = center_grid_in_panel(cx, cy, cw, ch, grid_w, grid_h)
            end
            outer_h = panel_h
        else
            x0 = rel_x + pad_x + math.max(0, (width - pad_x * 2 - grid_w) / 2)
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
end

return M
