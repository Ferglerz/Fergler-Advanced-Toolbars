-- Utils/Widget/slide_out_chip_host.lua
-- Shared slide-out multiswitch layout, panel sizing, and CHIP_MS.draw wiring.

local ROW = require("Utils.Chips.chip_row")
local CHIP_MS = require("Utils.Chips.chip_multiswitch")
local BASE = require("Utils.Widget.chip_widget_base")

local M = {}

function M.build_layout_opts(spec)
    local layout_opts = spec.layout_opts or {
        min_chip_w = spec.min_chip_w or 24,
        chip_gap = spec.chip_gap,
        pad_x = spec.pad_x,
        pad_y = spec.pad_y,
    }
    if spec.layout_opts then
        if spec.min_chip_w then layout_opts.min_chip_w = spec.min_chip_w end
        if spec.chip_gap then layout_opts.chip_gap = spec.chip_gap end
        if spec.pad_x then layout_opts.pad_x = spec.pad_x end
        if spec.pad_y then layout_opts.pad_y = spec.pad_y end
        if spec.chip_pad_h then layout_opts.chip_pad_h = spec.chip_pad_h end
        if spec.sizing then layout_opts.sizing = spec.sizing end
    end
    return layout_opts
end

function M.layout_fn(spec, entries, layout_opts)
    return function(self, ctx, rel_x, rel_y, render_width, slide_height, layout)
        if spec.slide_out_layout_chips then
            return spec.slide_out_layout_chips(self, ctx, rel_x, rel_y, render_width, slide_height, entries, layout_opts)
        end
        if not self._slide_out_plan then
            ROW.cache_slide_out_plan(self, ctx, render_width, slide_height, layout, entries, layout_opts)
        end
        return ROW.layout_slide_out_multiswitch(ctx, rel_x, rel_y, render_width, slide_height, entries, layout_opts, self._slide_out_plan)
    end
end

function M.draw_ms(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, opts)
    if not chips or #chips == 0 then
        return
    end
    CHIP_MS.draw(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, opts)
end

function M.plan_panel(widget, ctx, host_w, host_h, layout, entries, layout_opts)
    return ROW.cache_slide_out_plan(widget, ctx, host_w, host_h, layout, entries, layout_opts)
end

function M.panel_width(host_w, plan, layout)
    return ROW.slide_out_panel_width(host_w, plan.w, layout)
end

function M.panel_height(plan)
    return plan.h
end

function M.slide_draw_opts(ctx, spec, self, prefix, mx, my, is_selected_fn, draw_state, extra)
    local state = draw_state or { enabled = true, mixed = false }
    local slide_ns = spec.slide_namespace or (prefix .. "so")
    local opts = {
        mx = mx,
        my = my,
        enabled = state.enabled ~= false and (spec.can_interact == nil or spec.can_interact(self) ~= false),
        mixed = state.mixed == true,
        chip_round = spec.chip_round or ROW.CHIP_ROUND,
        grid_layout = spec.slide_multi_toggle ~= true,
        multi_toggle = spec.slide_multi_toggle == true,
        slide_namespace = slide_ns,
        alpha_factor = self._slide_alpha_factor,
        label_for = function(c)
            if spec.label_for then
                return spec.label_for(ctx, c)
            end
            return CHIP_MS.label_for_orientation(ctx, c.mode, c.w, false, 4)
        end,
        is_selected_segment = function(c)
            if not c or c.blank then
                return false
            end
            return is_selected_fn(self, c.mode)
        end,
    }
    if extra then
        for k, v in pairs(extra) do
            opts[k] = v
        end
    end
    return opts
end

function M.attach_panel_sizing(widget, spec, entries, layout_opts)
    widget.slide_width = spec.slide_width or function(self, ctx, host_w, host_h, layout)
        local plan = M.plan_panel(self, ctx, host_w, host_h, layout, entries, layout_opts)
        return M.panel_width(host_w, plan, layout)
    end
    widget.slide_height = spec.slide_height or function(self, ctx, host_w, host_h, layout)
        local plan = M.plan_panel(self, ctx, host_w, host_h, layout, entries, layout_opts)
        return M.panel_height(plan)
    end
end

--- Reusable slide-out surface: layout, draw, hit, sizing, click handling.
function M.bind(spec)
    local entries = spec.modes or spec.entries or {}
    CHIP_MS.normalize_chip_entries(entries)

    local prefix = spec.prefix or "so_"
    local layout_opts = M.build_layout_opts(spec)
    local layout_chips = M.layout_fn(spec, entries, layout_opts)

    local function is_selected(self, mode)
        if spec.is_selected then
            return spec.is_selected(self, mode)
        end
        return self._active_id == mode.id
    end

    local function draw_chips(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, mx, my, draw_state)
        local state = draw_state and draw_state(self) or { enabled = true, mixed = false }
        M.draw_ms(ctx, self, chips, coords, draw_list, btn_txt, btn_bg,
            M.slide_draw_opts(ctx, spec, self, prefix, mx, my, is_selected, state))
    end

    return {
        entries = entries,
        modes = entries,
        prefix = prefix,
        layout_chips = layout_chips,
        draw_chips = function(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, mx, my)
            draw_chips(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, mx, my, nil)
        end,
        hit_test = function(mx, my, coords, chips)
            return BASE.hit_test_chips(mx, my, coords, chips, prefix)
        end,
        on_sub_id = function(self, sub_id)
            local ok, mode, id = BASE.handle_prefixed_click(prefix, sub_id, entries)
            if not ok or not mode then
                return false
            end
            if spec.on_click_id then
                spec.on_click_id(self, id, mode)
            end
            if spec.apply then
                spec.apply(self, mode)
            end
            if spec.set_active_on_apply ~= false and self._active_id ~= nil then
                self._active_id = id
            end
            return true
        end,
        slide_width = function(self, ctx, host_w, host_h, layout)
            local plan = M.plan_panel(self, ctx, host_w, host_h, layout, entries, layout_opts)
            return M.panel_width(host_w, plan, layout)
        end,
        slide_height = function(self, ctx, host_w, host_h, layout)
            local plan = M.plan_panel(self, ctx, host_w, host_h, layout, entries, layout_opts)
            return M.panel_height(plan)
        end,
    }
end

return M
