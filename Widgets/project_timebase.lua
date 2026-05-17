-- Widgets/project_timebase.lua
-- Project timebase (Time / Beats+length+rate / Beats position only) via GetSetProjectInfo; SWS fallback if needed.

local ROW = require("Renderers._Widgets_chip_row")
local CHIP_MS = require("Utils.chip_multiswitch")
local CHIP_HIT = require("Utils.chip_hit_prefix")
local PREVIEW_FB = require("Utils.widget_preview_fallback")

local MODES = {
    { id = "time", label = "Time", proj = 0 },
    { id = "beats_all", short_label = "B+LR", label = "Beats (position, length, rate)", proj = 1 },
    { id = "beats_pos", short_label = "B.pos", label = "Beats (position only)", proj = 2 },
}

CHIP_MS.normalize_chip_entries(MODES)

local SWS_FALLBACK = {
    [0] = "_SWS_AWTBASETIME",
    [1] = "_SWS_AWTBASEBEATALL",
    [2] = "_SWS_AWTBASEBEATPOS",
}

local PREFIX = "ptb_"

local function read_project_timebase()
    return math.floor(reaper.GetSetProjectInfo(0, "PROJECT_TIMEBASE", 0, false) + 0.5)
end

local function mode_by_id(id)
    for _, m in ipairs(MODES) do
        if m.id == id then
            return m
        end
    end
    return nil
end

local function apply_project_timebase(proj_val)
    reaper.GetSetProjectInfo(0, "PROJECT_TIMEBASE", proj_val, true)
    local now = math.floor(reaper.GetSetProjectInfo(0, "PROJECT_TIMEBASE", 0, false) + 0.5)
    if now == proj_val then
        return
    end
    local sws = SWS_FALLBACK[proj_val]
    if not sws then
        return
    end
    local cmd = reaper.NamedCommandLookup(sws)
    if cmd and cmd > 0 then
        reaper.Main_OnCommand(cmd, 0)
    end
end

local PREVIEW_IDS = { "time", "beats_all", "beats_pos" }

local widget = {
    name = "Project Timebase",
    category = "Items & selection",
    type = "display",
    update_interval = 0.2,
    description = "Project default timebase: time, beats (position/length/rate), or beats (position only). Uses project API; SWS actions as fallback if the API cannot set timebase.",
    label = "",
    chip_widget = true,
    suppress_tooltip = true,
    width = 200,
    _active_id = nil,
}

function widget.getLayoutWidth(self, ctx)
    local natural = ROW.default_layout_width(ctx, #MODES, { base_width = self.width or 200, min_chip_w = 28 })
    return ROW.apply_preview_width_cap(self, natural)
end

function widget.getLayoutHeight(self, ctx, _inner_w, is_vertical_toolbar)
    if not is_vertical_toolbar then
        return CONFIG.SIZES.HEIGHT
    end
    return ROW.vertical_toolbar_height(ctx, #MODES, {})
end

function widget.getValue(self)
    local v = read_project_timebase()
    if v < 0 or v > 2 then
        v = 0
    end
    self._active_id = MODES[1].id
    for _, m in ipairs(MODES) do
        if m.proj == v then
            self._active_id = m.id
            break
        end
    end
    return v
end

function widget.hitTestSubcontrols(self, ctx, coords, rel_x, rel_y, render_width, layout)
    local mx, my = coords:getRelativeMouse()
    local chips = ROW.layout_entries(ctx, rel_x, rel_y, render_width, layout, MODES, { min_chip_w = 28 })
    return ROW.hit_test_chips(mx, my, coords, chips, PREFIX)
end

function widget.onSubcontrolClick(self, sub_id)
    local id = CHIP_HIT.strip(PREFIX, sub_id)
    if not id then
        return false
    end
    local m = mode_by_id(id)
    if not m then
        return false
    end
    apply_project_timebase(m.proj)
    self._active_id = id
    return true
end

local function render_preview(ctx, self, rel_x, rel_y, render_width, coords, draw_list, btn_txt, btn_bg)
    self._active_id = self._active_id or "time"
    local h = CONFIG.SIZES.HEIGHT
    local mx, my = coords:getRelativeMouse()
    local chips = ROW.preview_entries_row(ctx, rel_x, rel_y, render_width, PREVIEW_IDS, MODES, { min_chip_w = 28 })
    if PREVIEW_FB.when(ctx, not chips, "Proj. timebase", rel_x, rel_y, render_width, h, coords, draw_list, btn_txt, 0) then
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
    local chips = ROW.layout_entries(ctx, rel_x, rel_y, render_width, layout, MODES, { min_chip_w = 28 })
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
