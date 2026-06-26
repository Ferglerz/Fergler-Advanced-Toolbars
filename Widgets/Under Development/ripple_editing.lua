-- Widgets/Under Development/ripple_editing.lua
-- Ripple editing: "Ripple" label chip (toggle on/off) plus Track | All multiswitch. Set actions 40309–40311; scope persisted per button.

local CHIP_MS = require("Utils.chip_multiswitch")
local CHIP_ROW = require("Renderers.Widgets.chip_row")
local CHIP_HIT = require("Utils.chip_hit_prefix")
local DRAWING = require("Utils.drawing")

local CHIP_GAP = 6
local CHIP_ROUND = CHIP_ROW.CHIP_ROUND
local TOGGLE_PAD_H = 10
local SCOPE_INNER_GAP = 3

-- Set actions (idempotent); toggle IDs 41990/41991 only for reading state.
local CMD_OFF = 40309
local CMD_PER_TRACK = 40310
local CMD_ALL_TRACKS = 40311

local TOGGLE_PER_TRACK = 41990
local TOGGLE_ALL_TRACKS = 41991

local TOGGLE_LABEL = "Ripple"

local SUB_TOGGLE = "ripple_toggle"
local SCOPE_PREFIX = "ripple_s_"

local SCOPE_MODES = {
    { id = "per_track", label = "Track" },
    { id = "all_tracks", label = "All" },
}

CHIP_MS.normalize_chip_entries(SCOPE_MODES)

local widget = {
    name = "Ripple Editing",
    category = "Under Development",
    type = "display",
    update_interval = 0.2,
    description = "Ripple editing: Click Ripple to turn ripple off (scope is remembered) or on (restores saved Track vs All). Track and All switch scope directly.",
    label = "",
    chip_widget = true,
    suppress_tooltip = true,
    width = 132,
    _active_id = nil,
    _last_click_id = nil,
}

local function apply_preview_width_cap(self, natural_w)
    return CHIP_ROW.apply_preview_width_cap(self, natural_w)
end

local function store_bucket()
    CONFIG.WIDGET_SAVED_STATES = CONFIG.WIDGET_SAVED_STATES or {}
    CONFIG.WIDGET_SAVED_STATES.ripple_editing = CONFIG.WIDGET_SAVED_STATES.ripple_editing or {}
    return CONFIG.WIDGET_SAVED_STATES.ripple_editing
end

local function instance_key(self)
    return tostring(self._button_instance_id or "ripple_editing")
end

local function get_saved_scope(self)
    local b = store_bucket()
    local st = b[instance_key(self)]
    if type(st) == "table" and (st.scope == "per_track" or st.scope == "all_tracks") then
        return st.scope
    end
    return "per_track"
end

local function set_saved_scope(self, scope)
    if scope ~= "per_track" and scope ~= "all_tracks" then
        return
    end
    local b = store_bucket()
    local k = instance_key(self)
    b[k] = b[k] or {}
    b[k].scope = scope
end

local function detect_active_mode_id()
    local ok_a, st_a = pcall(reaper.GetToggleCommandState, TOGGLE_PER_TRACK)
    local ok_b, st_b = pcall(reaper.GetToggleCommandState, TOGGLE_ALL_TRACKS)
    if ok_a and st_a == 1 then
        return "per_track"
    end
    if ok_b and st_b == 1 then
        return "all_tracks"
    end
    return nil
end

local function chip_line_height(ctx)
    return CHIP_ROW.chip_line_height(ctx) + 2
end

local function layout_scope_chips(ctx, x, y, total_w, modes)
    return CHIP_ROW.layout_chip_strip(ctx, x, y, total_w, modes, {
        chip_pad_h = 6,
        chip_gap = SCOPE_INNER_GAP,
        min_chip_w = 24,
    })
end

--- Returns toggle rect and array of two scope chips (Track | All).
local function layout_all(ctx, rel_x, rel_y, render_width, layout)
    local h = CONFIG.SIZES.HEIGHT
    local chip_h = chip_line_height(ctx)
    local vert = layout and layout.is_vertical
    local R = CHIP_ROW.button_rounding_content_pad()
    local pad_x = 4 + R
    local pad_y = 4 + R

    local toggle_w = reaper.ImGui_CalcTextSize(ctx, TOGGLE_LABEL) + TOGGLE_PAD_H * 2
    toggle_w = math.max(toggle_w, 44)

    if vert then
        local usable_w = math.max(40, render_width - pad_x * 2)
        local y = rel_y + pad_y
        local toggle = {
            x = rel_x + pad_x,
            y = y,
            w = usable_w,
            h = chip_h,
        }
        y = y + chip_h + CHIP_GAP
        local scope_chips = layout_scope_chips(ctx, rel_x + pad_x, y, usable_w, SCOPE_MODES)
        return toggle, scope_chips
    end

    local row_y = rel_y + (h - chip_h) / 2
    local toggle = {
        x = rel_x + pad_x,
        y = row_y,
        w = toggle_w,
        h = chip_h,
    }
    local scope_x = toggle.x + toggle.w + CHIP_GAP
    local scope_w = math.max(40, rel_x + render_width - scope_x - pad_x)
    local scope_chips = layout_scope_chips(ctx, scope_x, row_y, scope_w, SCOPE_MODES)
    return toggle, scope_chips
end

function widget.getLayoutWidth(self, ctx)
    local natural = self.width or 132
    if ctx and reaper.ImGui_CalcTextSize then
        local toggle_w = reaper.ImGui_CalcTextSize(ctx, TOGGLE_LABEL) + TOGGLE_PAD_H * 2
        toggle_w = math.max(toggle_w, 44)
        local R = CHIP_ROW.button_rounding_content_pad()
        local scope_w = CHIP_ROW.uniform_chip_row_width(ctx, SCOPE_MODES, {
            pad_x = 0,
            chip_gap = SCOPE_INNER_GAP,
            chip_pad_h = 6,
            min_chip_w = 24,
        })
        natural = math.max(natural, 4 + R + toggle_w + CHIP_GAP + scope_w + 4 + R)
    end
    return apply_preview_width_cap(self, natural)
end

function widget.getLayoutHeight(self, ctx, _inner_w, is_vertical_toolbar)
    if not is_vertical_toolbar then
        return CONFIG.SIZES.HEIGHT
    end
    if not ctx or not reaper.ImGui_GetTextLineHeight then
        return CONFIG.SIZES.HEIGHT
    end
    local chip_h = chip_line_height(ctx)
    local R = CHIP_ROW.button_rounding_content_pad()
    return (4 + R) * 2 + chip_h * 2 + CHIP_GAP
end

function widget.getValue(self)
    local from_reaper = detect_active_mode_id()
    if self._last_click_id == "off" then
        self._active_id = nil
        if from_reaper == nil then
            self._last_click_id = nil
        end
    elseif from_reaper then
        self._active_id = from_reaper
        set_saved_scope(self, from_reaper)
        self._last_click_id = nil
    elseif self._last_click_id == "per_track" or self._last_click_id == "all_tracks" then
        self._active_id = self._last_click_id
    else
        self._active_id = nil
    end
    return 0
end

local function scope_selection_id(self)
    if self._preview_mode then
        return "per_track"
    end
    local active = detect_active_mode_id()
    if active then
        return active
    end
    return get_saved_scope(self)
end

local function apply_scope_click(self, id)
    if id == "per_track" then
        if detect_active_mode_id() == "per_track" then
            return true
        end
        reaper.Main_OnCommand(CMD_PER_TRACK, 0)
        set_saved_scope(self, "per_track")
        self._last_click_id = "per_track"
        self._active_id = "per_track"
        return true
    end
    if id == "all_tracks" then
        if detect_active_mode_id() == "all_tracks" then
            return true
        end
        reaper.Main_OnCommand(CMD_ALL_TRACKS, 0)
        set_saved_scope(self, "all_tracks")
        self._last_click_id = "all_tracks"
        self._active_id = "all_tracks"
        return true
    end
    return false
end

function widget.hitTestSubcontrols(self, ctx, coords, rel_x, rel_y, render_width, layout)
    local mx, my = coords:getRelativeMouse()
    local toggle, scope_chips = layout_all(ctx, rel_x, rel_y, render_width, layout)
    if coords:pointInRelativeRect(mx, my, toggle.x, toggle.y, toggle.w, toggle.h) then
        return SUB_TOGGLE
    end
    for _, c in ipairs(scope_chips) do
        if coords:pointInRelativeRect(mx, my, c.x, c.y, c.w, c.h) then
            return SCOPE_PREFIX .. c.id
        end
    end
    return nil
end

function widget.onSubcontrolClick(self, sub_id)
    if sub_id == SUB_TOGGLE then
        local active = detect_active_mode_id()
        if active ~= nil then
            set_saved_scope(self, active)
            reaper.Main_OnCommand(CMD_OFF, 0)
            self._last_click_id = "off"
            self._active_id = nil
        else
            local scope = get_saved_scope(self)
            if scope == "all_tracks" then
                reaper.Main_OnCommand(CMD_ALL_TRACKS, 0)
                self._last_click_id = "all_tracks"
                self._active_id = "all_tracks"
            else
                reaper.Main_OnCommand(CMD_PER_TRACK, 0)
                self._last_click_id = "per_track"
                self._active_id = "per_track"
            end
        end
        return true
    end
    local sid = CHIP_HIT.strip(SCOPE_PREFIX, sub_id)
    if sid then
        return apply_scope_click(self, sid)
    end
    return false
end

local function render_inner(ctx, self, rel_x, rel_y, render_width, coords, draw_list, btn_txt, btn_bg, layout)
    local mx, my = coords:getRelativeMouse()
    local toggle, scope_chips = layout_all(ctx, rel_x, rel_y, render_width, layout)

    local ripple_on = self._preview_mode and true or (detect_active_mode_id() ~= nil)
    local toggle_hover = coords:pointInRelativeRect(mx, my, toggle.x, toggle.y, toggle.w, toggle.h)
    DRAWING.drawWidgetPillChip(ctx, coords, draw_list, toggle, TOGGLE_LABEL, btn_txt, btn_bg, {
        active = ripple_on,
        filled = true,
        hover = toggle_hover and not ripple_on,
        disabled = false,
        rounding = CHIP_ROW.CHIP_ROUND,
    })

    local sel = scope_selection_id(self)
    CHIP_MS.draw(ctx, self, scope_chips, coords, draw_list, btn_txt, btn_bg, {
        mx = mx,
        my = my,
        enabled = true,
        mixed = false,
        chip_round = CHIP_ROUND,
        is_selected_segment = function(c)
            return c.mode.id == sel
        end,
    })
end

function widget.renderCustom(ctx, self, rel_x, rel_y, render_width, coords, draw_list, text_color, layout, bg_color)
    local btn_txt, btn_bg = COLOR_UTILS.widgetButtonColors(text_color, bg_color)
    render_inner(ctx, self, rel_x, rel_y, render_width, coords, draw_list, btn_txt, btn_bg, layout)
end

return widget
