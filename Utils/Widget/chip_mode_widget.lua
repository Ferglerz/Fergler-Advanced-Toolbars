-- Utils/Widget/chip_mode_widget.lua
-- Factory for row-style chip multiswitch widgets (timebase, ruler unit, etc.).

local ROW = require("Utils.Chips.chip_row")
local CHIP_MS = require("Utils.Chips.chip_multiswitch")
local PREVIEW_FB = require("Utils.Widget.widget_preview_fallback")
local DRAWING = require("Utils.Draw.drawing")
local BASE = require("Utils.Widget.chip_widget_base")
local SLIDE_HOST = require("Utils.Widget.slide_out_chip_host")

local M = {}

M.mode_by_id = BASE.mode_by_id
M.preview_mode_entries = BASE.preview_mode_entries

function M.with_slide_out_toolbar(spec)
    spec.slide_out = true
    if spec.slide_multi_toggle == nil then
        spec.slide_multi_toggle = false
    end
    spec.min_chip_w = spec.min_chip_w or 28
    spec.preview_toolbar_chip = true
    if not spec.preview_active_id then
        spec.preview_active_id = function(self)
            if self.getValue then
                self.getValue(self)
            end
        end
    end
    return spec
end

local function apply_aggregate(spec)
    if not spec.aggregate then
        return
    end
    local a = spec.aggregate
    spec.state = spec.state or {}
    spec.state._mixed = false
    if a.use_has_selection then
        spec.state._has_selection = false
    else
        spec.state._empty = true
    end

    local orig_getValue = spec.getValue
    spec.getValue = function(self, modes)
        local scalar, mixed, present = a.scan()
        self._mixed = mixed
        if a.use_has_selection then
            self._has_selection = present
        else
            self._empty = not present
        end
        if a.store_field then
            self[a.store_field] = scalar
        end
        if not present or mixed then
            self._active_id = nil
        elseif a.id_from_scalar then
            self._active_id = a.id_from_scalar(scalar)
        end
        if orig_getValue then
            return orig_getValue(self, modes)
        end
        return scalar or 0
    end

    if not spec.toolbar_label then
        spec.toolbar_label = function(self)
            local absent = a.use_has_selection and not self._has_selection or self._empty
            if absent then
                return a.empty_label or "—"
            end
            if self._mixed then
                return a.mixed_label or "Mixed"
            end
            local id = self._active_id
            if not id and a.store_field and a.id_from_scalar then
                id = a.id_from_scalar(self[a.store_field])
            end
            local mode = BASE.mode_by_id(spec.modes, id)
            return mode and CHIP_MS.chip_caption(mode) or (a.fallback_label or "—")
        end
    end

    if not spec.get_draw_state then
        spec.get_draw_state = function(self)
            local enabled = a.use_has_selection and self._has_selection or not self._empty
            return { enabled = enabled, mixed = self._mixed }
        end
    end

    if not spec.can_interact then
        spec.can_interact = function(self)
            return a.use_has_selection and self._has_selection or not self._empty
        end
    end
end

function M.new(spec)
    apply_aggregate(spec)
    local MODES = spec.modes
    CHIP_MS.normalize_chip_entries(MODES)

    local PREFIX = spec.prefix
    local layout_opts = SLIDE_HOST.build_layout_opts(spec)

    local widget = BASE.apply_base_widget(spec, {
        chip_widget = true,
        extra = { _active_id = spec.default_active_id },
    })

    local function toolbar_label(self)
        if spec.toolbar_label then
            return spec.toolbar_label(self, MODES)
        end
        local id = self._active_id
        if not id then
            return spec.toolbar_fallback or "—"
        end
        local mode = BASE.mode_by_id(MODES, id)
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
        if spec.slide_out and is_vertical_toolbar then
            return math.max(CONFIG.SIZES.HEIGHT or 28, ROW.vertical_toolbar_height(ctx, 1, layout_opts))
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

    local layout_slide_out_entries = SLIDE_HOST.layout_fn(spec, MODES, layout_opts)

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
            return BASE.hit_test_chips(mx, my, coords, chips, PREFIX)
        end
        if spec.slide_out then
            local chip = ROW.layout_toolbar_chip(ctx, rel_x, rel_y, render_width, layout, toolbar_label(self), { pad_x = layout_opts.pad_x })
            if coords:pointInRelativeRect(mx, my, chip.x, chip.y, chip.w, chip.h) then
                return "toolbar_mode"
            end
            return nil
        end
        local chips = layout_entries(ctx, rel_x, rel_y, render_width, layout)
        return BASE.hit_test_chips(mx, my, coords, chips, PREFIX)
    end

    function widget.onSubcontrolClick(self, sub_id)
        if sub_id == "toolbar_mode" then
            return false
        end
        if spec.can_interact and not spec.can_interact(self) then
            return false
        end
        local ok, mode, id = BASE.handle_prefixed_click(PREFIX, sub_id, MODES, {
            resolve_click_id = spec.resolve_click_id,
        })
        if not ok or not mode then
            return false
        end
        if spec.apply then
            spec.apply(self, mode)
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
        if spec.preview_toolbar_chip then
            local state = draw_state(self)
            local label = spec.preview_toolbar_label and spec.preview_toolbar_label(self) or toolbar_label(self)
            local chip = ROW.layout_toolbar_chip(ctx, rel_x, rel_y, render_width, nil, label, { pad_x = layout_opts.pad_x })
            draw_toolbar_chip(ctx, coords, draw_list, chip, btn_txt, btn_bg, state.enabled ~= false, false, nil)
            return
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
            SLIDE_HOST.draw_ms(ctx, self, chips, coords, draw_list, btn_txt, btn_bg,
                SLIDE_HOST.slide_draw_opts(ctx, spec, self, PREFIX, mx, my, is_selected, state,
                    merge_chip_draw_opts(self, ctx, {}, false)))
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
        SLIDE_HOST.attach_panel_sizing(widget, spec, MODES, layout_opts)
    end

    if spec.init then
        spec.init(widget, MODES)
    end

    return widget
end

--- Slide-out surface for embedding mode multiswitch in a bespoke toolbar widget.
--- Returns layout/draw/hit/slide sizing helpers bound to modes + prefix.
function M.bind_slide_out(spec)
    return SLIDE_HOST.bind(spec)
end

return M
