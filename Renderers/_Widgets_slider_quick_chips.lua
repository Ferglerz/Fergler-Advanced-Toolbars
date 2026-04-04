-- Renderers/_Widgets_slider_quick_chips.lua
-- Optional preset chip row for pan/spread-style sliders (-100 … 100).

local ROW = require("Renderers._Widgets_chip_row")
local CHIP_MS = require("Utils.chip_multiswitch")

local M = {}

M.PREFIX = "iqv_"
M.GAP_SLIDER_CHIPS = 6

local ENTRIES = {
    { id = "m100", short_label = "-100", value = -100 },
    { id = "m50", short_label = "-50", value = -50 },
    { id = "z", short_label = "0", value = 0 },
    { id = "p50", short_label = "50", value = 50 },
    { id = "p100", short_label = "100", value = 100 },
}

CHIP_MS.normalize_chip_entries(ENTRIES)

function M.entry_by_id(id)
    for _, e in ipairs(ENTRIES) do
        if e.id == id then
            return e
        end
    end
    return nil
end

--- layout: button layout with .is_vertical (toolbar orientation).
function M.effective_show(widget, layout)
    local mode = widget.quick_values_mode or "auto"
    if mode == "on" then
        return true
    end
    if mode == "off" then
        return false
    end
    return layout and layout.is_vertical
end

function M.effective_show_for_toolbar(widget, is_vertical_toolbar)
    local mode = widget.quick_values_mode or "auto"
    if mode == "on" then
        return true
    end
    if mode == "off" then
        return false
    end
    return is_vertical_toolbar == true
end

function M.min_chips_stripe_width(ctx)
    local inset = ROW.button_rounding_content_pad()
    local min_chip = 20
    local gap = ROW.CHIP_GAP
    local pad = 8 + inset * 2
    return pad + #ENTRIES * min_chip + gap * math.max(0, #ENTRIES - 1)
end

--- Total button width: base widget.width plus inline chip stripe when horizontal toolbar.
function M.get_layout_width(widget, ctx, is_vertical_toolbar)
    local base = widget.width or 120
    if not M.effective_show_for_toolbar(widget, is_vertical_toolbar) then
        return base
    end
    if is_vertical_toolbar then
        return math.max(base, M.min_chips_stripe_width(ctx))
    end
    return base + M.GAP_SLIDER_CHIPS + M.min_chips_stripe_width(ctx)
end

function M.get_layout_height(widget, ctx, _inner_w, is_vertical_toolbar)
    if not M.effective_show_for_toolbar(widget, is_vertical_toolbar) or not is_vertical_toolbar then
        return CONFIG.SIZES.HEIGHT
    end
    local chip_h = ROW.chip_line_height(ctx)
    return CONFIG.SIZES.HEIGHT + ROW.CHIP_GAP + chip_h
end

function M.mouse_over_chips(coords, chips)
    if not chips or #chips == 0 then
        return false
    end
    local mx, my = coords:getRelativeMouse()
    for _, c in ipairs(chips) do
        if coords:pointInRelativeRect(mx, my, c.x, c.y, c.w, c.h) then
            return true
        end
    end
    return false
end

--- Returns { slider_rel_x, slider_rel_y, slider_render_width, chips } or nil.
function M.compute_layout(ctx, widget, rel_x, rel_y, render_width, layout)
    if not widget.slider_quick_chips or not M.effective_show(widget, layout) then
        return nil
    end

    local H = CONFIG.SIZES.HEIGHT

    if layout and layout.is_vertical then
        local chips_y = rel_y + H + ROW.CHIP_GAP
        local chips = ROW.layout_entries_horizontal(ctx, rel_x, chips_y, render_width, ENTRIES, {
            min_chip_w = 20,
            pad_x = 4,
        })
        return {
            slider_rel_x = rel_x,
            slider_rel_y = rel_y,
            slider_render_width = render_width,
            chips = chips,
        }
    end

    local want_chips = M.min_chips_stripe_width(ctx)
    local gap = M.GAP_SLIDER_CHIPS
    local slider_rw = render_width - want_chips - gap
    if slider_rw < 52 then
        slider_rw = 52
        want_chips = math.max(36, render_width - slider_rw - gap)
    end

    local chips_x = rel_x + slider_rw + gap
    local chips = ROW.layout_entries_horizontal(ctx, chips_x, rel_y, want_chips, ENTRIES, {
        min_chip_w = 16,
        pad_x = 2,
    })

    return {
        slider_rel_x = rel_x,
        slider_rel_y = rel_y,
        slider_render_width = slider_rw,
        chips = chips,
    }
end

function M.draw_chips(ctx, widget, coords, draw_list, btn_txt, btn_bg, qlayout, mx, my)
    if not qlayout or not qlayout.chips or #qlayout.chips == 0 then
        return
    end
    local enabled = not (widget.is_disabled and widget.is_disabled())
    local CMS = require("Utils.chip_multiswitch")
    CMS.draw(ctx, widget, qlayout.chips, coords, draw_list, btn_txt, btn_bg, {
        mx = mx,
        my = my,
        enabled = enabled,
        multi_toggle = true,
        chip_round = ROW.CHIP_ROUND,
        label_for = function(c)
            return CHIP_MS.chip_caption(c.mode)
        end,
        is_selected_segment = function(c)
            local v = c.mode and c.mode.value
            if v == nil then
                return false
            end
            return math.abs((widget.value or 0) - v) < 0.51
        end,
    })
end

function M.hit_test_subcontrol(ctx, widget, coords, rel_x, rel_y, render_width, layout)
    if not widget.slider_quick_chips or not M.effective_show(widget, layout) then
        return nil
    end
    local ql = M.compute_layout(ctx, widget, rel_x, rel_y, render_width, layout)
    if not ql or not ql.chips then
        return nil
    end
    local mx, my = coords:getRelativeMouse()
    return ROW.hit_test_chips(mx, my, coords, ql.chips, M.PREFIX)
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

function M.apply_persisted(widget, opts)
    widget.quick_values_mode = "auto"
    if type(opts) == "table" and (opts.quick_values_mode == "on" or opts.quick_values_mode == "off") then
        widget.quick_values_mode = opts.quick_values_mode
    end
end

function M.export_persisted(widget)
    local m = widget.quick_values_mode
    if m == "on" or m == "off" then
        return { quick_values_mode = m }
    end
    return {}
end

local function mark_layout_dirty(button)
    if not button then
        return
    end
    button:clearLayoutCache()
    button:saveChanges()
end

--- ImGui popup (same pattern as playback_rate draw_rates_context): opened from onRightClick / onRightClickSubcontrol.
function M.draw_quick_values_context(self, ctx, button)
    local key = "##item_slider_qv_" .. tostring(button and button.instance_id or self._button_instance_id or "x")
    if self._open_quick_values_ctx then
        reaper.ImGui_OpenPopup(ctx, key)
        self._open_quick_values_ctx = false
    end

    if not reaper.ImGui_BeginPopup(ctx, key) then
        return
    end

    reaper.ImGui_TextDisabled(ctx, "Show quick values")
    local mode = self.quick_values_mode or "auto"
    local changed = false
    if reaper.ImGui_MenuItem(ctx, "Default (vertical toolbars only)", nil, mode == "auto") then
        self.quick_values_mode = "auto"
        changed = true
    end
    if reaper.ImGui_MenuItem(ctx, "Always show", nil, mode == "on") then
        self.quick_values_mode = "on"
        changed = true
    end
    if reaper.ImGui_MenuItem(ctx, "Always hide", nil, mode == "off") then
        self.quick_values_mode = "off"
        changed = true
    end
    reaper.ImGui_EndPopup(ctx)

    if changed then
        mark_layout_dirty(button or self._context_button)
    end
end

function M.attach(widget)
    widget.slider_quick_chips = true
    widget.quick_values_mode = widget.quick_values_mode or "auto"
    widget._open_quick_values_ctx = false

    widget.applyPersistedOptions = function(self, opts)
        M.apply_persisted(self, opts)
    end

    widget.exportPersistedOptions = function(self)
        return M.export_persisted(self)
    end

    widget.getLayoutWidth = function(self, ctx, is_vertical_toolbar)
        return M.get_layout_width(self, ctx, is_vertical_toolbar)
    end

    widget.getLayoutHeight = function(self, ctx, inner_w, is_vertical_toolbar)
        return M.get_layout_height(self, ctx, inner_w, is_vertical_toolbar)
    end

    widget.hitTestSubcontrols = function(self, ctx, coords, rel_x, rel_y, render_width, layout)
        return M.hit_test_subcontrol(ctx, self, coords, rel_x, rel_y, render_width, layout)
    end

    widget.onSubcontrolClick = function(self, sub_id)
        return M.on_subcontrol_click(self, sub_id)
    end

    widget.onRightClick = function(self, button)
        self._open_quick_values_ctx = true
        self._context_button = button
    end

    widget.onRightClickSubcontrol = function(_self, _sub_id, button)
        _self._open_quick_values_ctx = true
        _self._context_button = button
    end

    widget.onWidgetFrame = function(self, ctx, button)
        M.draw_quick_values_context(self, ctx, button)
    end
end

return M
