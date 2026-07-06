-- Utils/widget_spinner_slide_out/slide_out.lua

local ROW = require("Utils.Chips.chip_row")
local SPINNER = require("Utils.Chips.chip_spinner")

return function(widget, spec, env)
    local MODES = env.MODES
    local MIN_CHIP = env.MIN_CHIP
    local enabled_list = env.enabled_list
    local ensure_included = env.ensure_included

    local function multiswitch_layout_opts()
        return {
            pad_x = 4,
            chip_pad_h = 6,
            min_chip_w = MIN_CHIP,
            sizing = "fill",
            caption_for = function(e)
                if spec.caption_for then
                    return spec.caption_for(widget, e)
                end
                return e.short_label or UTILS.formatWidgetValue(widget, e.rate)
            end,
        }
    end

    env.multiswitch_layout_opts = multiswitch_layout_opts

    local function cache_slide_plan(self, ctx, host_w, host_h, layout)
        ensure_included(self)
        local list = enabled_list(self)
        if #list < 1 then
            list = MODES
        end
        return ROW.cache_slide_out_plan(self, ctx, host_w, host_h, layout, list, multiswitch_layout_opts())
    end

    env.cache_slide_plan = cache_slide_plan

    local function slide_out_layout_opts(self, ctx, panel_w, panel_h, layout)
        local plan = self._slide_out_plan or cache_slide_plan(self, ctx, panel_w, panel_h, layout)
        local opts = multiswitch_layout_opts()
        opts.rows = plan.rows
        opts.height = panel_h
        return opts
    end

    env.slide_out_layout_opts = slide_out_layout_opts

    local function layout_multiswitch_chips(ctx, rel_x, rel_y, ms_width, layout, list)
        return ROW.layout_multiswitch_grid(ctx, rel_x, rel_y, ms_width, layout, list, multiswitch_layout_opts())
    end

    env.layout_multiswitch_chips = layout_multiswitch_chips

    local function horizontal_multiswitch_cols(ctx, n)
        if not ctx or not reaper.ImGui_GetTextLineHeight or n < 1 then
            return math.max(1, n)
        end
        local chip_h = ROW.chip_line_height(ctx)
        local gap = ROW.CHIP_GAP
        local btn_h = tonumber(CONFIG.SIZES.HEIGHT) or chip_h
        local rows = (2 * chip_h + gap <= btn_h) and 2 or 1
        return math.ceil(n / rows)
    end

    env.horizontal_multiswitch_cols = horizontal_multiswitch_cols

    local function multiswitch_block_height(ctx, n, is_vertical, inner_w)
        if not is_vertical then
            return CONFIG.SIZES.HEIGHT
        end
        if not ctx or not inner_w then
            return CONFIG.SIZES.HEIGHT
        end
        local inset = ROW.button_rounding_content_pad()
        local pad_y = 4 + inset
        local pad_x = 4 + inset
        local chip_h = ROW.chip_line_height(ctx)
        local gap = ROW.CHIP_GAP
        local usable_w = math.max(40, inner_w - pad_x * 2)
        local cell_w = ROW.uniform_chip_cell_width(ctx, MODES, multiswitch_layout_opts())
        local cols = (usable_w >= 2 * cell_w + gap) and 2 or 1
        cols = math.min(cols, math.max(1, n))
        local rows = math.ceil(n / cols)
        local grid_h = rows * chip_h + math.max(0, rows - 1) * gap
        return pad_y + grid_h + pad_y
    end

    env.multiswitch_block_height = multiswitch_block_height

    function widget.slide_height(self, ctx, host_w, host_h, layout)
        local plan = cache_slide_plan(self, ctx, host_w, host_h, layout)
        return plan.h
    end

    function widget.slide_width(self, ctx, host_w, host_h, layout)
        local plan = cache_slide_plan(self, ctx, host_w, host_h, layout)
        return ROW.slide_out_panel_width(host_w, plan.w, layout)
    end
end
