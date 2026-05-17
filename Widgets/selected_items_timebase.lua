-- Widgets/selected_items_timebase.lua
-- Timebase for selected media items (C_BEATATTACHMODE); disabled when nothing is selected.

local ROW = require("Renderers._Widgets_chip_row")
local CHIP_MS = require("Utils.chip_multiswitch")
local CHIP_HIT = require("Utils.chip_hit_prefix")
local PREVIEW_FB = require("Utils.widget_preview_fallback")

local MODES = {
    { id = "def", short_label = "Def", label = "Project / track default", api = -1 },
    { id = "time", label = "Time", api = 0 },
    { id = "beats_all", short_label = "B+LR", label = "Beats (position, length, rate)", api = 1 },
    { id = "beats_pos", short_label = "B.pos", label = "Beats (position only)", api = 2 },
}

CHIP_MS.normalize_chip_entries(MODES)

local PREFIX = "itb_"

local function mode_by_id(id)
    for _, m in ipairs(MODES) do
        if m.id == id then
            return m
        end
    end
    return nil
end

local function id_from_api(v)
    v = math.floor((v or -1) + 0.5)
    for _, m in ipairs(MODES) do
        if m.api == v then
            return m.id
        end
    end
    return "def"
end

local function aggregate_selection()
    local n = reaper.CountSelectedMediaItems(0)
    if n < 1 then
        return nil, false, true
    end
    local first = nil
    for i = 0, n - 1 do
        local it = reaper.GetSelectedMediaItem(0, i)
        local v = math.floor(reaper.GetMediaItemInfo_Value(it, "C_BEATATTACHMODE") + 0.5)
        if first == nil then
            first = v
        elseif first ~= v then
            return nil, true, false
        end
    end
    return first, false, false
end

local function apply_to_selection(api_val)
    local n = reaper.CountSelectedMediaItems(0)
    if n < 1 then
        return
    end
    reaper.Undo_BeginBlock()
    for i = 0, n - 1 do
        local it = reaper.GetSelectedMediaItem(0, i)
        reaper.SetMediaItemInfo_Value(it, "C_BEATATTACHMODE", api_val)
    end
    reaper.UpdateArrange()
    reaper.Undo_EndBlock("Set item timebase", -1)
end

local PREVIEW_IDS = { "def", "time", "beats_all" }

local widget = {
    name = "Selected Items Timebase",
    category = "Items & selection",
    type = "display",
    update_interval = 0.15,
    description = "Timebase for selected items: default (follow project/track), time, or beats. Empty selection dims the row.",
    label = "",
    chip_widget = true,
    suppress_tooltip = true,
    width = 260,
    _active_id = nil,
    _mixed = false,
    _empty = true,
}

function widget.getLayoutWidth(self, ctx)
    local natural = ROW.default_layout_width(ctx, #MODES, { base_width = self.width or 260, min_chip_w = 22 })
    return ROW.apply_preview_width_cap(self, natural)
end

function widget.getLayoutHeight(self, ctx, _inner_w, is_vertical_toolbar)
    if not is_vertical_toolbar then
        return CONFIG.SIZES.HEIGHT
    end
    return ROW.vertical_toolbar_height(ctx, #MODES, {})
end

function widget.getValue(self)
    local v, mixed, empty = aggregate_selection()
    self._mixed = mixed
    self._empty = empty
    if empty then
        self._active_id = nil
    elseif mixed then
        self._active_id = nil
    else
        self._active_id = id_from_api(v)
    end
    return 0
end

function widget.hitTestSubcontrols(self, ctx, coords, rel_x, rel_y, render_width, layout)
    if self._empty then
        return nil
    end
    local mx, my = coords:getRelativeMouse()
    local chips = ROW.layout_entries(ctx, rel_x, rel_y, render_width, layout, MODES, { min_chip_w = 22 })
    return ROW.hit_test_chips(mx, my, coords, chips, PREFIX)
end

function widget.onSubcontrolClick(self, sub_id)
    if self._empty then
        return false
    end
    local id = CHIP_HIT.strip(PREFIX, sub_id)
    if not id then
        return false
    end
    local m = mode_by_id(id)
    if not m then
        return false
    end
    apply_to_selection(m.api)
    self._active_id = id
    self._mixed = false
    return true
end

local function render_preview(ctx, self, rel_x, rel_y, render_width, coords, draw_list, btn_txt, btn_bg)
    self._active_id = self._active_id or "def"
    local h = CONFIG.SIZES.HEIGHT
    local mx, my = coords:getRelativeMouse()
    local chips = ROW.preview_entries_row(ctx, rel_x, rel_y, render_width, PREVIEW_IDS, MODES, { min_chip_w = 22 })
    if PREVIEW_FB.when(ctx, not chips, "Items timebase", rel_x, rel_y, render_width, h, coords, draw_list, btn_txt, 0) then
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
    local chips = ROW.layout_entries(ctx, rel_x, rel_y, render_width, layout, MODES, { min_chip_w = 22 })
    local mx, my = coords:getRelativeMouse()
    local vert = layout and layout.is_vertical
    local enabled = not self._empty
    local mixed = self._mixed

    local function label_for_chip(c)
        return CHIP_MS.label_for_orientation(ctx, c.mode, c.w, vert, 4)
    end

    CHIP_MULTISWITCH.draw(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, {
        mx = mx,
        my = my,
        enabled = enabled,
        mixed = mixed,
        chip_round = ROW.CHIP_ROUND,
        vertical = vert,
        label_for = label_for_chip,
        is_selected_segment = function(c)
            return self._active_id == c.mode.id
        end,
    })
end

return widget
