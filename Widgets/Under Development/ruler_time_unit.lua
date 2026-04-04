-- Widgets/Under Development/ruler_time_unit.lua
-- Primary ruler time-unit chips (View: Time unit for ruler: … actions).

local ROW = require("Renderers._Widgets_chip_row")
local CHIP_MS = require("Utils.chip_multiswitch")

local MODES = {
    { id = "ms", short_label = "M:S", label = "Minutes:Seconds", command_id = 40365 },
    { id = "mb_ms", short_label = "M:B/M:S", label = "Measures:Beats / Minutes:Seconds", command_id = 40366 },
    { id = "sec", short_label = "Sec", label = "Seconds", command_id = 40368 },
    { id = "smp", short_label = "Smp", label = "Samples", command_id = 40369 },
    { id = "tc", short_label = "TC", label = "Timecode", command_id = 40370 },
    { id = "mbmin", short_label = "M:B+", label = "Measures:Beats (minimal)", command_id = 41916 },
    { id = "afrm", short_label = "A.Frm", label = "Audio Frames", command_id = 41973 },
}

CHIP_MS.normalize_chip_entries(MODES)

local PREFIX = "ruler_"

local widget = {
    name = "Ruler Time Unit",
    category = "Under Development",
    update_interval = 0.2,
    type = "display",
    width = 520,
    label = "",
    description = "",
    suppress_tooltip = true,
    chip_widget = true,
    _active_id = nil,
    _last_click_id = nil,
}

local function mode_by_id(id)
    for _, m in ipairs(MODES) do
        if m.id == id then
            return m
        end
    end
    return nil
end

local function detect_active_mode_id()
    for _, m in ipairs(MODES) do
        local ok, st = pcall(reaper.GetToggleCommandState, m.command_id)
        if ok and st == 1 then
            return m.id
        end
    end
    return nil
end

function widget.getLayoutWidth(self, ctx)
    local natural = ROW.default_layout_width(ctx, #MODES, { base_width = self.width or 520, min_chip_w = 24 })
    return ROW.apply_preview_width_cap(self, natural)
end

function widget.getLayoutHeight(self, ctx, _inner_w, is_vertical_toolbar)
    if not is_vertical_toolbar or not ctx or not reaper.ImGui_GetTextLineHeight then
        return CONFIG.SIZES.HEIGHT
    end
    return ROW.vertical_toolbar_height(ctx, #MODES, {})
end

local function layout_chips(self, ctx, rel_x, rel_y, render_width, layout)
    return ROW.layout_entries(ctx, rel_x, rel_y, render_width, layout, MODES, { min_chip_w = 24 })
end

function widget.getValue(self)
    local from_reaper = detect_active_mode_id()
    if from_reaper then
        self._active_id = from_reaper
    elseif self._last_click_id then
        self._active_id = self._last_click_id
    else
        self._active_id = nil
    end
    return 0
end

function widget.hitTestSubcontrols(self, ctx, coords, rel_x, rel_y, render_width, layout)
    local mx, my = coords:getRelativeMouse()
    local chips = layout_chips(self, ctx, rel_x, rel_y, render_width, layout)
    return ROW.hit_test_chips(mx, my, coords, chips, PREFIX)
end

function widget.onSubcontrolClick(self, sub_id)
    local id = sub_id and sub_id:match("^ruler_(.+)$")
    if not id then
        return false
    end
    local m = mode_by_id(id)
    if not m or not m.command_id then
        return false
    end
    reaper.Main_OnCommand(m.command_id, 0)
    self._last_click_id = id
    self._active_id = id
    return true
end

local PREVIEW_MODE_IDS = { "ms", "sec", "tc" }

local function render_preview(ctx, self, rel_x, rel_y, render_width, coords, draw_list, btn_txt, btn_bg)
    local h = CONFIG.SIZES.HEIGHT
    local mx, my = coords:getRelativeMouse()
    local chips = ROW.preview_entries_row(ctx, rel_x, rel_y, render_width, PREVIEW_MODE_IDS, MODES, { min_chip_w = 24 })
    if not chips then
        DRAWING.drawWidgetCenteredValueText(ctx, "Ruler time", rel_x, rel_y, render_width, h, coords, draw_list, btn_txt, 0)
        return
    end
    CHIP_MULTISWITCH.draw(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, {
        mx = mx,
        my = my,
        enabled = true,
        mixed = false,
        chip_round = ROW.CHIP_ROUND,
        is_selected_segment = function(c)
            return self._active_id == c.mode.id
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
    local chips = layout_chips(self, ctx, rel_x, rel_y, render_width, layout)
    local mx, my = coords:getRelativeMouse()
    local vert = layout and layout.is_vertical

    local function label_for_chip(c)
        return CHIP_MS.label_for_orientation(ctx, c.mode, c.w, vert, 4)
    end

    CHIP_MULTISWITCH.draw(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, {
        mx = mx,
        my = my,
        enabled = true,
        mixed = false,
        chip_round = ROW.CHIP_ROUND,
        vertical = vert,
        label_for = label_for_chip,
        is_selected_segment = function(c)
            return self._active_id == c.mode.id
        end,
    })
end

return widget
