-- Renderers/Widgets/slider_quick_chips.lua
-- Preset chip row for pan/spread-style sliders (-100 … 100). Slide-out only.

local ROW = require("Renderers.Widgets.chip_row")
local CHIP_MS = require("Utils.chip_multiswitch")
local WIDGET_DRAW = require("Renderers.Widgets.common_draw")

local M = {}

M.PREFIX = "iqv_"
M.READOUT_PAD = 4

local ENTRIES = {
    { id = "m100", short_label = "-100", value = -100 },
    { id = "m50", short_label = "-50", value = -50 },
    { id = "z", short_label = "0", value = 0 },
    { id = "p50", short_label = "50", value = 50 },
    { id = "p100", short_label = "100", value = 100 },
}

CHIP_MS.normalize_chip_entries(ENTRIES)

local CHIP_LAYOUT_OPTS = {
    pad_x = 4,
    chip_pad_h = 6,
    min_chip_w = 16,
}

function M.entry_by_id(id)
    return UTILS.findById(ENTRIES, id)
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

function M.readout_band_height(ctx)
    local lh = reaper.ImGui_GetTextLineHeight(ctx) or (CONFIG.SIZES.TEXT or 12)
    return M.READOUT_PAD + lh + M.READOUT_PAD
end

function M.cache_slide_plan(widget, ctx, host_w, host_h, layout)
    local readout_h = M.readout_band_height(ctx)
    local constraints = {}
    if layout and layout.is_vertical then
        constraints.panel_h = math.max(ROW.chip_line_height(ctx), host_h - readout_h)
    else
        constraints.panel_w = host_w
    end
    local w, h, rows, cols = ROW.plan_slide_out_panel(ctx, ENTRIES, CHIP_LAYOUT_OPTS, constraints)
    widget._slide_out_plan = {
        w = w,
        h = h,
        rows = rows,
        cols = cols,
        readout_h = readout_h,
    }
    return widget._slide_out_plan
end

function M.layout_slide_out_chips(ctx, widget, rel_x, rel_y, render_width, band_height)
    local plan = widget._slide_out_plan
    if not plan then
        return {}
    end
    return ROW.layout_slide_out_multiswitch(ctx, rel_x, rel_y, render_width, band_height, ENTRIES, CHIP_LAYOUT_OPTS, plan)
end

function M.slide_height(widget, ctx, host_w, host_h, layout)
    local plan = M.cache_slide_plan(widget, ctx, host_w, host_h, layout)
    if layout and layout.is_vertical then
        return host_h
    end
    return plan.readout_h + plan.h
end

function M.slide_width(widget, ctx, host_w, host_h, layout)
    local plan = M.cache_slide_plan(widget, ctx, host_w, host_h, layout)
    if layout and layout.is_vertical then
        return plan.w
    end
    return host_w
end

local function draw_chips(ctx, widget, coords, draw_list, btn_txt, btn_bg, chips, mx, my, alpha_factor)
    if not chips or #chips == 0 then
        return
    end
    local enabled = not (widget.is_disabled and widget.is_disabled())
    CHIP_MS.draw(ctx, widget, chips, coords, draw_list, btn_txt, btn_bg, {
        mx = mx,
        my = my,
        enabled = enabled,
        chip_round = ROW.CHIP_ROUND,
        slide_namespace = "iqv_ms",
        alpha_factor = alpha_factor,
        multi_toggle = true,
        label_for = function(c)
            return CHIP_MS.chip_caption(c.mode)
        end,
        is_selected_segment = function(c)
            if c.blank then
                return false
            end
            local v = c.mode and c.mode.value
            if v == nil then
                return false
            end
            return math.abs((widget.value or 0) - v) < 0.51
        end,
    })
end

function M.draw_slide_out(ctx, widget, rel_x, rel_y, render_width, coords, draw_list, btn_txt, btn_bg, alpha_factor, layout)
    local plan = widget._slide_out_plan
    local readout_h = (plan and plan.readout_h) or M.readout_band_height(ctx)
    WIDGET_DRAW.drawSliderValueReadout(ctx, coords, draw_list, widget, rel_x, rel_y, render_width, readout_h, btn_txt, alpha_factor)

    local panel_h = widget._slide_panel_h or (readout_h + ((plan and plan.h) or M.chip_band_height(ctx)))
    local chips_y = rel_y + readout_h
    local chips_h = math.max(ROW.chip_line_height(ctx), panel_h - readout_h)
    local chips = M.layout_slide_out_chips(ctx, widget, rel_x, chips_y, render_width, chips_h)
    if not chips or #chips == 0 then
        return
    end
    local mx, my = coords:getRelativeMouse()
    draw_chips(ctx, widget, coords, draw_list, btn_txt, btn_bg, chips, mx, my, alpha_factor)
end

function M.hit_test_slide_out(ctx, widget, coords, rel_x, rel_y, render_width, layout)
    local plan = widget._slide_out_plan
    local readout_h = (plan and plan.readout_h) or M.readout_band_height(ctx)
    local panel_h = widget._slide_panel_h or (readout_h + ((plan and plan.h) or 0))
    local chips_y = rel_y + readout_h
    local chips_h = math.max(ROW.chip_line_height(ctx), panel_h - readout_h)
    local chips = M.layout_slide_out_chips(ctx, widget, rel_x, chips_y, render_width, chips_h)
    if not chips or #chips == 0 then
        return nil
    end
    local mx, my = coords:getRelativeMouse()
    return ROW.hit_test_chips(mx, my, coords, chips, M.PREFIX)
end

function M.hit_test_subcontrol(ctx, widget, coords, rel_x, rel_y, render_width, layout, is_slide_out)
    if is_slide_out then
        return M.hit_test_slide_out(ctx, widget, coords, rel_x, rel_y, render_width, layout)
    end
    return nil
end

function M.on_subcontrol_click(widget, sub_id)
    if widget.is_disabled and widget.is_disabled() then
        return false
    end
    local id = sub_id and sub_id:match("^iqv_(.+)$")
    if not id then
        return false
    end
    local e = M.entry_by_id(id)
    if not e then
        return false
    end
    widget.value = e.value
    if widget.setValue then
        pcall(widget.setValue, e.value)
    end
    return true
end

function M.attach(widget, attach_opts)
    attach_opts = attach_opts or {}
    widget.slider_quick_chips = true
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
