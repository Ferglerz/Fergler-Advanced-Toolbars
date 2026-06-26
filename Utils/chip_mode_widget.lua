-- Utils/chip_mode_widget.lua
-- Factory for row-style chip multiswitch widgets (timebase, ruler unit, etc.).

local ROW = require("Renderers.Widgets.chip_row")
local CHIP_MS = require("Utils.chip_multiswitch")
local CHIP_HIT = require("Utils.chip_hit_prefix")
local PREVIEW_FB = require("Utils.widget_preview_fallback")
local DRAWING = require("Utils.drawing")

local M = {}

function M.mode_by_id(modes, id)
    return UTILS.findById(modes, id)
end

function M.preview_mode_entries(mode_ids, modes)
    local list = {}
    for _, pid in ipairs(mode_ids) do
        local m = M.mode_by_id(modes, pid)
        if m then
            list[#list + 1] = m
        end
    end
    return list
end

function M.new(spec)
    local MODES = spec.modes
    CHIP_MS.normalize_chip_entries(MODES)

    local PREFIX = spec.prefix
    local layout_opts = {
        min_chip_w = spec.min_chip_w or 24,
        chip_gap = spec.chip_gap,
        pad_x = spec.pad_x,
        pad_y = spec.pad_y,
    }

    local widget = {
        name = spec.name,
        display_name = spec.display_name,
        category = spec.category,
        type = spec.type or "display",
        update_interval = spec.update_interval,
        description = spec.description,
        label = spec.label or "",
        chip_widget = true,
        suppress_tooltip = spec.suppress_tooltip ~= false,
        width = spec.width,
        _active_id = spec.default_active_id,
    }

    for k, v in pairs(spec.state or {}) do
        widget[k] = v
    end

    if spec.slide_out then
        widget._slide_out_mode = true
    end

    local function toolbar_label(self)
        if spec.toolbar_label then
            return spec.toolbar_label(self, MODES)
        end
        local id = self._active_id
        if not id then
            return spec.toolbar_fallback or "—"
        end
        local mode = M.mode_by_id(MODES, id)
        return mode and CHIP_MS.chip_caption(mode) or (spec.toolbar_fallback or "—")
    end

    local function draw_toolbar_chip(ctx, coords, draw_list, chip, btn_txt, btn_bg, enabled, is_hover, alpha_factor)
        DRAWING.drawWidgetPillChip(ctx, coords, draw_list, chip, chip.label or "", btn_txt, btn_bg, {
            active = enabled,
            filled = true,
            hover = is_hover and enabled,
            disabled = not enabled,
            rounding = ROW.CHIP_ROUND,
            alpha_factor = alpha_factor,
        })
    end

    function widget.getLayoutWidth(self, ctx, is_vertical_toolbar)
        if spec.getLayoutWidth then
            return spec.getLayoutWidth(self, ctx, is_vertical_toolbar, MODES, layout_opts)
        end
        if spec.slide_out and not is_vertical_toolbar and ctx and reaper.ImGui_CalcTextSize then
            local R = ROW.button_rounding_content_pad()
            local label = toolbar_label(self)
            local natural = math.max(72, ROW.toolbar_chip_width(ctx, label) + ((layout_opts.pad_x or 4) + R) * 2)
            return ROW.apply_preview_width_cap(self, natural)
        end
        local natural = ROW.default_layout_width(ctx, #MODES, {
            base_width = self.width or spec.width or 200,
            min_chip_w = layout_opts.min_chip_w,
            chip_gap = layout_opts.chip_gap,
            pad_x = layout_opts.pad_x,
        })
        return ROW.apply_preview_width_cap(self, natural)
    end

    function widget.getLayoutHeight(self, ctx, inner_w, is_vertical_toolbar)
        if spec.getLayoutHeight then
            return spec.getLayoutHeight(self, ctx, inner_w, is_vertical_toolbar, MODES, layout_opts)
        end
        if spec.getLayoutHeight then
            return spec.getLayoutHeight(self, ctx, inner_w, is_vertical_toolbar, MODES, layout_opts)
        end
        if spec.slide_out and is_vertical_toolbar then
            return ROW.vertical_toolbar_height(ctx, 1, layout_opts)
        end
        return ROW.standard_horizontal_or_vertical_height(ctx, #MODES, is_vertical_toolbar, layout_opts, inner_w)
    end

    function widget.getValue(self)
        if spec.getValue then
            return spec.getValue(self, MODES)
        end
        return 0
    end

    local function layout_entries(ctx, rel_x, rel_y, render_width, layout)
        local opts = layout_opts
        if layout then
            opts = {}
            for k, v in pairs(layout_opts) do
                opts[k] = v
            end
            opts.height = ROW.widget_body_height(layout)
        end
        return ROW.layout_entries(ctx, rel_x, rel_y, render_width, layout, MODES, opts)
    end

    local function host_toolbar_is_vertical(self)
        local host_layout = self._host_button and self._host_button.layout
        return host_layout and host_layout.is_vertical
    end

    local function cache_slide_out_plan(self, ctx, host_w, host_h, layout)
        local constraints = {}
        if layout and layout.is_vertical then
            constraints.panel_h = host_h
        else
            constraints.panel_w = host_w
        end
        local w, h, rows, cols = ROW.plan_slide_out_panel(ctx, MODES, layout_opts, constraints)
        self._slide_out_plan = { w = w, h = h, rows = rows, cols = cols }
        return self._slide_out_plan
    end

    local function layout_slide_out_entries(self, ctx, rel_x, rel_y, render_width, slide_height, layout)
        if spec.slide_out_layout_chips then
            return spec.slide_out_layout_chips(self, ctx, rel_x, rel_y, render_width, slide_height, MODES, layout_opts)
        end
        if not self._slide_out_plan then
            cache_slide_out_plan(self, ctx, render_width, slide_height, layout)
        end
        return ROW.layout_slide_out_multiswitch(ctx, rel_x, rel_y, render_width, slide_height, MODES, layout_opts, self._slide_out_plan)
    end

    function widget.hitTestSubcontrols(self, ctx, coords, rel_x, rel_y, render_width, layout, is_slide_out)
        if spec.can_interact and not spec.can_interact(self) then
            return nil
        end
        local mx, my = coords:getRelativeMouse()
        if is_slide_out then
            if spec.slide_out_can_interact and not spec.slide_out_can_interact(self) then
                return nil
            end
            local h = self._slide_panel_h or self:slide_height(ctx, render_width, self._slide_host_h, layout) or CONFIG.SIZES.HEIGHT
            local chips = layout_slide_out_entries(self, ctx, rel_x, rel_y, render_width, h, layout)
            return ROW.hit_test_chips(mx, my, coords, chips, PREFIX)
        end
        if spec.slide_out then
            local chip = ROW.layout_toolbar_chip(ctx, rel_x, rel_y, render_width, layout, toolbar_label(self), { pad_x = layout_opts.pad_x })
            if coords:pointInRelativeRect(mx, my, chip.x, chip.y, chip.w, chip.h) then
                return "toolbar_mode"
            end
            return nil
        end
        local chips = layout_entries(ctx, rel_x, rel_y, render_width, layout)
        return ROW.hit_test_chips(mx, my, coords, chips, PREFIX)
    end

    function widget.onSubcontrolClick(self, sub_id)
        if sub_id == "toolbar_mode" then
            return false
        end
        if spec.can_interact and not spec.can_interact(self) then
            return false
        end
        local id = CHIP_HIT.strip(PREFIX, sub_id)
        if not id and spec.resolve_click_id then
            id = spec.resolve_click_id(sub_id)
        end
        if not id then
            return false
        end
        local mode = M.mode_by_id(MODES, id)
        if not mode then
            return false
        end
        if spec.apply then
            spec.apply(self, mode)
        end
        if spec.on_apply then
            spec.on_apply(self, mode)
        end
        if spec.set_active_on_apply ~= false then
            self._active_id = id
        end
        return true
    end

    local function draw_state(self)
        if spec.get_draw_state then
            return spec.get_draw_state(self)
        end
        return { enabled = true, mixed = false }
    end

    local function is_selected(self, mode)
        if spec.is_selected then
            return spec.is_selected(self, mode)
        end
        return self._active_id == mode.id
    end

    local function merge_chip_draw_opts(self, ctx, base, vert)
        if spec.chip_draw_opts then
            local extra = spec.chip_draw_opts(self, ctx, vert, MODES)
            if extra then
                for k, v in pairs(extra) do
                    base[k] = v
                end
            end
        end
        return base
    end

    local function render_preview(ctx, self, rel_x, rel_y, render_width, coords, draw_list, btn_txt, btn_bg)
        if spec.render_preview then
            spec.render_preview(ctx, self, rel_x, rel_y, render_width, coords, draw_list, btn_txt, btn_bg, MODES, layout_opts)
            return
        end
        if spec.preview_active_id then
            spec.preview_active_id(self)
        elseif self._active_id == nil and spec.default_active_id then
            self._active_id = spec.default_active_id
        end
        local h = CONFIG.SIZES.HEIGHT
        local mx, my = coords:getRelativeMouse()
        local preview_ids = spec.preview_ids or {}
        local chips = ROW.preview_entries_row(ctx, rel_x, rel_y, render_width, preview_ids, MODES, layout_opts)
        local title = spec.preview_title or spec.name or "Preview"
        if PREVIEW_FB.when(ctx, not chips, title, rel_x, rel_y, render_width, h, coords, draw_list, btn_txt, 0) then
            return
        end
        local state = draw_state(self)
        CHIP_MS.draw(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, merge_chip_draw_opts(self, ctx, {
            mx = mx,
            my = my,
            enabled = state.enabled ~= false,
            mixed = state.mixed == true,
            chip_round = ROW.CHIP_ROUND,
            is_selected_segment = function(c)
                return is_selected(self, c.mode)
            end,
        }, false))
    end

    function widget.renderCustom(ctx, self, rel_x, rel_y, render_width, coords, draw_list, text_color, layout, bg_color)
        local btn_txt, btn_bg = COLOR_UTILS.widgetButtonColors(text_color, bg_color)
        if self._preview_mode then
            render_preview(ctx, self, rel_x, rel_y, render_width, coords, draw_list, btn_txt, btn_bg)
            return
        end
        local mx, my = coords:getRelativeMouse()
        local vert = layout and layout.is_vertical
        local state = draw_state(self)
        local is_slide_out = self._is_rendering_slide_out == true

        if is_slide_out then
            local h = self._slide_panel_h or self:slide_height(ctx, render_width, self._slide_host_h, layout) or CONFIG.SIZES.HEIGHT
            local chips = layout_slide_out_entries(self, ctx, rel_x, rel_y, render_width, h, layout)
            local slide_ns = spec.slide_namespace or (PREFIX .. "so")
            CHIP_MS.draw(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, merge_chip_draw_opts(self, ctx, {
                mx = mx,
                my = my,
                enabled = state.enabled ~= false,
                mixed = state.mixed == true,
                chip_round = ROW.CHIP_ROUND,
                grid_layout = true,
                slide_namespace = slide_ns,
                alpha_factor = self._slide_alpha_factor,
                multi_toggle = spec.slide_multi_toggle ~= false,
                label_for = function(c)
                    return CHIP_MS.label_for_orientation(ctx, c.mode, c.w, false, 4)
                end,
                is_selected_segment = function(c)
                    return is_selected(self, c.mode)
                end,
            }, false))
            return
        end

        if spec.slide_out then
            local label = toolbar_label(self)
            local chip = ROW.layout_toolbar_chip(ctx, rel_x, rel_y, render_width, layout, label, { pad_x = layout_opts.pad_x })
            local hov = coords:pointInRelativeRect(mx, my, chip.x, chip.y, chip.w, chip.h)
            draw_toolbar_chip(ctx, coords, draw_list, chip, btn_txt, btn_bg, state.enabled ~= false, hov, nil)
            if spec.after_toolbar_chip_render then
                spec.after_toolbar_chip_render(ctx, self, rel_x, rel_y, render_width, coords, draw_list, btn_txt, layout)
            end
            return
        end

        local chips = layout_entries(ctx, rel_x, rel_y, render_width, layout)

        local function label_for_chip(c)
            return CHIP_MS.label_for_orientation(ctx, c.mode, c.w, vert, 4)
        end

        CHIP_MS.draw(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, merge_chip_draw_opts(self, ctx, {
            mx = mx,
            my = my,
            enabled = state.enabled ~= false,
            mixed = state.mixed == true,
            chip_round = ROW.CHIP_ROUND,
            vertical = vert,
            label_for = label_for_chip,
            is_selected_segment = function(c)
                return is_selected(self, c.mode)
            end,
        }, vert))
    end

    if spec.slide_out then
        widget.slide_width = spec.slide_width or function(self, ctx, host_w, host_h, layout)
            local plan = cache_slide_out_plan(self, ctx, host_w, host_h, layout)
            return plan.w
        end
        widget.slide_height = spec.slide_height or function(self, ctx, host_w, host_h, layout)
            if not self._slide_out_plan then
                cache_slide_out_plan(self, ctx, host_w, host_h, layout)
            end
            return self._slide_out_plan.h
        end
    end

    if spec.init then
        spec.init(widget, MODES)
    end

    return widget
end

return M
