-- Utils/chip_mode_widget.lua
-- Factory for row-style chip multiswitch widgets (timebase, ruler unit, etc.).

local ROW = require("Renderers._Widgets_chip_row")
local CHIP_MS = require("Utils.chip_multiswitch")
local CHIP_HIT = require("Utils.chip_hit_prefix")
local PREVIEW_FB = require("Utils.widget_preview_fallback")

local M = {}

function M.mode_by_id(modes, id)
    for _, mode in ipairs(modes) do
        if mode.id == id then
            return mode
        end
    end
    return nil
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

    function widget.getLayoutWidth(self, ctx)
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
        return ROW.standard_horizontal_or_vertical_height(ctx, #MODES, is_vertical_toolbar, layout_opts)
    end

    function widget.getValue(self)
        if spec.getValue then
            return spec.getValue(self, MODES)
        end
        return 0
    end

    local function layout_entries(ctx, rel_x, rel_y, render_width, layout)
        return ROW.layout_entries(ctx, rel_x, rel_y, render_width, layout, MODES, layout_opts)
    end

    function widget.hitTestSubcontrols(self, ctx, coords, rel_x, rel_y, render_width, layout)
        if spec.can_interact and not spec.can_interact(self) then
            return nil
        end
        local mx, my = coords:getRelativeMouse()
        local chips = layout_entries(ctx, rel_x, rel_y, render_width, layout)
        return ROW.hit_test_chips(mx, my, coords, chips, PREFIX)
    end

    function widget.onSubcontrolClick(self, sub_id)
        if spec.can_interact and not spec.can_interact(self) then
            return false
        end
        local id = CHIP_HIT.strip(PREFIX, sub_id)
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

    local function render_preview(ctx, self, rel_x, rel_y, render_width, coords, draw_list, btn_txt, btn_bg)
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
        CHIP_MULTISWITCH.draw(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, {
            mx = mx,
            my = my,
            enabled = state.enabled ~= false,
            mixed = state.mixed == true,
            chip_round = ROW.CHIP_ROUND,
            is_selected_segment = function(c)
                return is_selected(self, c.mode)
            end,
        })
    end

    function widget.renderCustom(ctx, self, rel_x, rel_y, render_width, coords, draw_list, text_color, layout, bg_color)
        local btn_txt = text_color or 0xFFFFFFFF
        local btn_bg = bg_color or 0x000000FF
        if self._preview_mode then
            render_preview(ctx, self, rel_x, rel_y, render_width, coords, draw_list, btn_txt, btn_bg)
            return
        end
        local chips = layout_entries(ctx, rel_x, rel_y, render_width, layout)
        local mx, my = coords:getRelativeMouse()
        local vert = layout and layout.is_vertical
        local state = draw_state(self)

        local function label_for_chip(c)
            return CHIP_MS.label_for_orientation(ctx, c.mode, c.w, vert, 4)
        end

        CHIP_MULTISWITCH.draw(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, {
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
        })
    end

    if spec.init then
        spec.init(widget, MODES)
    end

    return widget
end

return M
