-- Slide-out panel planning and sizing for chip multiswitch grids.

local M = {}

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

function M.attach(row)
    function row.slide_out_pad(options)
        options = options or {}
        return options.pad or options.pad_x or options.pad_y or 4
    end

    function row.slide_out_content_pad(options)
        local pad = row.slide_out_pad(options)
        return pad, pad
    end

    --- Inset rect for slide-out panel content. edges: { top, bottom, left, right } default true.
    function row.slide_out_content_rect(rel_x, rel_y, panel_w, panel_h, options, edges)
        options = options or {}
        edges = edges or {}
        local pad = row.slide_out_pad(options)
        local inset_l = edges.left ~= false and pad or 0
        local inset_r = edges.right ~= false and pad or 0
        local inset_t = edges.top ~= false and pad or 0
        local inset_b = edges.bottom ~= false and pad or 0
        return rel_x + inset_l, rel_y + inset_t,
            math.max(1, panel_w - inset_l - inset_r),
            math.max(1, panel_h - inset_t - inset_b)
    end

    function row.center_grid_in_panel(rel_x, rel_y, panel_w, panel_h, grid_w, grid_h)
        return rel_x + math.max(0, (panel_w - grid_w) / 2), rel_y + math.max(0, (panel_h - grid_h) / 2)
    end

    --- Host-axis constraint for plan_slide_out_panel (min panel width = host button width).
    function row.slide_out_panel_constraints(host_w, _host_h, _layout, _extra)
        return { host_w_min = host_w or 0 }
    end

    --- Slide-out panel width from content plan (caller centers panel on host when narrower).
    function row.slide_out_panel_width(_host_w, planned_w, _layout)
        return planned_w or 0
    end

    --- Prefer two chip rows for horizontal slide-outs when n > 2; pairs fit one row.
    function row.preferred_horizontal_slide_out_rows(n)
        if n <= 2 then
            return 1
        end
        return 2
    end

    --- Chip grid content size only (no panel inset). Returns grid_w, grid_h, rows, cols.
    function row.plan_horizontal_slide_out_grid(ctx, entries, options, _host_w)
        options = options or {}
        local n = #(entries or {})
        local chip_h = row.chip_line_height(ctx)
        local gap = options.chip_gap or row.CHIP_GAP

        if n < 1 then
            local cell_w = row.uniform_chip_cell_width(ctx, entries, options)
            return cell_w, chip_h, 1, 1
        end

        local rows = options.rows or row.preferred_horizontal_slide_out_rows(n)
        local cols = math.ceil(n / rows)
        local cell_w = row.uniform_chip_cell_width(ctx, entries, options)
        local grid_w = cols * cell_w + math.max(0, cols - 1) * gap
        local grid_h = rows * chip_h + math.max(0, rows - 1) * gap
        return grid_w, grid_h, rows, cols
    end

    --- Natural horizontal slide-out panel size: content + equal inset on all four sides.
    function row.plan_horizontal_slide_out_content(ctx, entries, options, _host_w)
        local grid_w, grid_h, rows, cols = row.plan_horizontal_slide_out_grid(ctx, entries, options, _host_w)
        local pad = row.slide_out_pad(options)
        return grid_w + pad * 2, grid_h + pad * 2, rows, cols
    end

    --- Total panel height for stacked horizontal slide-out rows (one outer inset).
    function row.measure_horizontal_stacked_slide_out_height(ctx, grid_heights, row_gap, options)
        options = options or {}
        local chip_h = row.chip_line_height(ctx)
        local pad = row.slide_out_pad(options)
        row_gap = row_gap or row.CHIP_GAP
        local n = #(grid_heights or {})
        if n < 1 then
            return chip_h + pad * 2
        end
        local content_h = 0
        for i, gh in ipairs(grid_heights) do
            content_h = content_h + (gh or chip_h)
            if i < n then
                content_h = content_h + row_gap
            end
        end
        return content_h + pad * 2
    end

    function row.max_multiswitch_cols_for_inner_w(ctx, entries, inner_w, options)
        local gap = options.chip_gap or row.CHIP_GAP
        local cell_w = row.uniform_chip_cell_width(ctx, entries, options)
        if cell_w <= 0 then
            return 1
        end
        return math.max(1, math.floor((inner_w + gap) / (cell_w + gap)))
    end

    function row.max_multiswitch_rows_for_inner_h(ctx, inner_h, options)
        local chip_h = row.chip_line_height(ctx)
        local gap = options.chip_gap or row.CHIP_GAP
        return math.max(1, math.floor((inner_h + gap) / (chip_h + gap)))
    end

    --- Slide-out panel size from entry count and host toolbar orientation. Returns width, height, rows, cols.
    function row.slide_out_multiswitch_metrics(ctx, entries, options, host_is_vertical)
        options = options or {}
        local n = #(entries or {})
        local chip_h = row.chip_line_height(ctx)
        local gap = options.chip_gap or row.CHIP_GAP
        local pad = row.slide_out_pad(options)
        if n < 1 then
            return row.uniform_multiswitch_width(ctx, entries, 1, options), chip_h + pad * 2, 1, 1
        end
        local rows, cols
        if host_is_vertical then
            cols = math.min(2, n)
            rows = math.ceil(n / cols)
        else
            rows = row.preferred_horizontal_slide_out_rows(n)
            cols = math.ceil(n / rows)
        end
        local w = row.uniform_multiswitch_width(ctx, entries, cols, options)
        local grid_h = rows * chip_h + math.max(0, rows - 1) * gap
        return w + pad * 2, grid_h + pad * 2, rows, cols
    end

    --- Plan slide-out panel from host button size.
    --- Set panel_h only (vertical host): height fixed first, width wraps grid content.
    --- Set panel_w only (horizontal host): width fixed first, height grows with grid rows.
    --- Returns width, height, rows, cols.
    function row.plan_slide_out_panel(ctx, entries, options, constraints)
        constraints = constraints or {}
        options = options or {}
        local n = #(entries or {})
        local chip_h = row.chip_line_height(ctx)
        local gap = options.chip_gap or row.CHIP_GAP
        local pad_x, pad_y = row.slide_out_content_pad(options)
        local panel_w = constraints.panel_w
        local panel_h = constraints.panel_h

        if n < 1 then
            return panel_w or row.uniform_multiswitch_width(ctx, entries, 1, options),
                panel_h or (chip_h + pad_y * 2),
                1,
                1
        end

        local inner_w = panel_w and math.max(40, panel_w - pad_x * 2) or nil
        local inner_h = panel_h and math.max(chip_h, panel_h - pad_y * 2) or nil
        local rows, cols

        if constraints.host_w_min and not panel_w and not panel_h then
            return row.plan_horizontal_slide_out_content(ctx, entries, options, constraints.host_w_min)
        end

        if panel_h and not panel_w then
            local rows_max = row.max_multiswitch_rows_for_inner_h(ctx, inner_h, options)
            if options.rows then
                rows = math.min(options.rows, n)
                cols = math.ceil(n / rows)
            else
                rows, cols = balanced_multiswitch_grid(n, rows_max, n)
            end
            local w = row.uniform_multiswitch_width(ctx, entries, cols, options)
            return w, panel_h, rows, cols
        end

        if panel_w then
            local cols_max = row.max_multiswitch_cols_for_inner_w(ctx, entries, inner_w, options)
            cols = math.min(n, cols_max)
            rows = math.ceil(n / cols)
            if inner_h then
                local rows_max = row.max_multiswitch_rows_for_inner_h(ctx, inner_h, options)
                if rows > rows_max then
                    rows = rows_max
                    cols = math.ceil(n / rows)
                end
            end
            local grid_h = rows * chip_h + math.max(0, rows - 1) * gap
            local h = panel_h or (grid_h + pad_y * 2)
            return panel_w, h, rows, cols
        end

        return row.slide_out_multiswitch_metrics(ctx, entries, options, constraints.host_is_vertical)
    end

    --- Plan slide-out grid for one entry list. Returns width, height, rows, cols.
    function row.plan_slide_out_entries(ctx, entries, options, host_w, host_h, layout)
        local constraints = row.slide_out_panel_constraints(host_w, host_h, layout)
        return row.plan_slide_out_panel(ctx, entries, options or {}, constraints)
    end

    --- Cache a simple slide-out plan on widget._slide_out_plan ({ w, h, rows, cols }).
    function row.cache_slide_out_plan(widget, ctx, host_w, host_h, layout, entries, options)
        local w, h, rows, cols = row.plan_slide_out_entries(ctx, entries, options, host_w, host_h, layout)
        widget._slide_out_plan = { w = w, h = h, rows = rows, cols = cols }
        return widget._slide_out_plan
    end
end

return M
