-- Widgets/Under Development/track_automation_modes.lua
-- Chip selector for selected-track automation mode.

local CHIP_MODE = require("Utils.chip_mode_widget")
local CHIP_MS = require("Utils.chip_multiswitch")
local CHIP_ROW = require("Renderers.Widgets.chip_row")
local CHIP_HIT = require("Utils.chip_hit_prefix")
local PREVIEW_FB = require("Utils.widget_preview_fallback")
local WIDGET_TITLE = require("Utils.widget_title")

local MODES = {
    { id = "trim", label = "Trim", value = 0, command_id = 40400 },
    { id = "read", label = "Read", value = 1, command_id = 40401 },
    { id = "touch", label = "Touch", value = 2, command_id = 40402 },
    { id = "write", label = "Write", value = 3, command_id = 40403 },
    { id = "latch", label = "Latch", value = 4, command_id = 40404 },
    { id = "preview", short_label = "L.Pre", label = "Latch preview", value = 5, command_id = 42023 },
}

local PREFIX = "tam_ms_"
local MIN_CHIP = 28
local PREVIEW_MODE_IDS = { "read", "write", "touch" }

local function mode_id_for_value(mode_value)
    if mode_value == nil then
        return nil
    end
    for _, m in ipairs(MODES) do
        if m.value == mode_value then
            return m.id
        end
    end
    return nil
end

local function selected_mode_id(self)
    if not self._has_selection or self._mixed or self._selected_mode == nil then
        return nil
    end
    return mode_id_for_value(self._selected_mode)
end

local function get_selection_mode_state()
    local count = reaper.CountSelectedTracks(0)
    if count <= 0 then
        return nil, false, false
    end

    local first = reaper.GetSelectedTrack(0, 0)
    if not first then
        return nil, false, false
    end
    local mode = math.floor(reaper.GetMediaTrackInfo_Value(first, "I_AUTOMODE") + 0.5)
    local mixed = false
    for i = 1, count - 1 do
        local tr = reaper.GetSelectedTrack(0, i)
        if tr then
            local m = math.floor(reaper.GetMediaTrackInfo_Value(tr, "I_AUTOMODE") + 0.5)
            if m ~= mode then
                mixed = true
                break
            end
        end
    end
    return mode, mixed, true
end

local function set_selected_tracks_mode(mode_value)
    local count = reaper.CountSelectedTracks(0)
    if count <= 0 then
        return false
    end
    for i = 0, count - 1 do
        local tr = reaper.GetSelectedTrack(0, i)
        if tr then
            reaper.SetMediaTrackInfo_Value(tr, "I_AUTOMODE", mode_value)
        end
    end
    reaper.TrackList_AdjustWindows(false)
    return true
end

local function automation_chip_draw_opts(self, ctx, vert)
    return {
        grid_layout = true,
        slide_namespace = "tam_ms",
        label_for = function(c)
            if not c.mode then
                return ""
            end
            return CHIP_MS.label_for_orientation(ctx, c.mode, c.w, vert == true, 4)
        end,
        is_selected_segment = function(c)
            if c.blank or self._mixed or not c.mode then
                return false
            end
            local sel_id = selected_mode_id(self)
            return sel_id ~= nil and sel_id == c.mode.id
        end,
    }
end

return CHIP_MODE.new({
    name = "Track Automation Modes",
    display_name = "Track Automation",
    category = "Under Development",
    update_interval = 0.1,
    type = "display",
    width = 340,
    label = "",
    description = "Chip selector for selected-track automation modes. Follows current track selection and shows mixed-state feedback.",
    slide_out = true,
    slide_namespace = "tam_ms",
    slide_multi_toggle = false,
    modes = MODES,
    prefix = PREFIX,
    min_chip_w = MIN_CHIP,
    set_active_on_apply = false,
    state = {
        _selected_mode = nil,
        _mixed = false,
        _has_selection = false,
    },
    toolbar_label = function(self)
        if not self._has_selection then
            return "No track"
        end
        if self._mixed then
            return "Mixed"
        end
        local id = selected_mode_id(self)
        local m = id and CHIP_MODE.mode_by_id(MODES, id)
        return m and CHIP_MS.chip_caption(m) or "Read"
    end,
    slide_out_can_interact = function(self)
        return self._has_selection
    end,
    get_draw_state = function(self)
        return { enabled = self._has_selection, mixed = self._mixed }
    end,
    is_selected = function(self, mode)
        local sel_id = selected_mode_id(self)
        return sel_id ~= nil and sel_id == mode.id
    end,
    getValue = function(self)
        local mode, mixed, has_selection = get_selection_mode_state()
        self._selected_mode = mode
        self._mixed = mixed
        self._has_selection = has_selection
        return mode or -1
    end,
    apply = function(self, mode)
        if mode.command_id then
            reaper.Main_OnCommand(mode.command_id, 0)
        elseif not set_selected_tracks_mode(mode.value) then
            return
        end
        self._selected_mode = mode.value
        self._mixed = false
        self._has_selection = reaper.CountSelectedTracks(0) > 0
    end,
    resolve_click_id = function(sub_id)
        return CHIP_HIT.strip("mode_", sub_id)
    end,
    chip_draw_opts = automation_chip_draw_opts,
    render_preview = function(ctx, self, rel_x, rel_y, render_width, coords, draw_list, btn_txt, btn_bg)
        local h = CONFIG.SIZES.HEIGHT
        local mx, my = coords:getRelativeMouse()
        local chips = CHIP_ROW.layout_multiswitch_grid(ctx, rel_x, rel_y, render_width, { is_vertical = false }, CHIP_MODE.preview_mode_entries(PREVIEW_MODE_IDS, MODES), {
            min_chip_w = MIN_CHIP,
            pad_x = 4,
        })
        if PREVIEW_FB.when(ctx, not chips or #chips < 1, "Automation", rel_x, rel_y, render_width, h, coords, draw_list, btn_txt, 0) then
            return
        end
        CHIP_MS.draw(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, {
            mx = mx,
            my = my,
            enabled = self._has_selection,
            mixed = self._mixed,
            chip_round = CHIP_ROW.CHIP_ROUND,
            grid_layout = true,
            slide_namespace = "tam_ms",
            label_for = function(c)
                if not c.mode then
                    return ""
                end
                return CHIP_MS.label_for_orientation(ctx, c.mode, c.w, false, 4)
            end,
            is_selected_segment = function(c)
                if c.blank or self._mixed or not c.mode then
                    return false
                end
                local sel_id = selected_mode_id(self)
                return sel_id ~= nil and sel_id == c.mode.id
            end,
        })
    end,
    getLayoutWidth = function(self, ctx, is_vertical_toolbar)
        local natural = self.width or 340
        if not ctx or not reaper.ImGui_CalcTextSize then
            return natural
        end
        if not is_vertical_toolbar then
            local R = CHIP_ROW.button_rounding_content_pad()
            local label
            if not self._has_selection then
                label = "No track"
            elseif self._mixed then
                label = "Mixed"
            else
                local m = CHIP_MODE.mode_by_id(MODES, selected_mode_id(self))
                label = m and CHIP_MS.chip_caption(m) or "Read"
            end
            natural = math.max(72, CHIP_ROW.toolbar_chip_width(ctx, label) + (4 + R) * 2)
            natural = math.max(natural, WIDGET_TITLE.required_width(ctx, self, false))
        elseif reaper.ImGui_GetTextLineHeight then
            local _, _, _, cols = CHIP_ROW.slide_out_multiswitch_metrics(ctx, MODES, {
                pad_x = 4,
                chip_pad_h = 6,
                min_chip_w = MIN_CHIP,
            }, true)
            natural = math.max(natural, CHIP_ROW.uniform_multiswitch_width(ctx, MODES, cols, {
                pad_x = 4,
                chip_pad_h = 6,
                min_chip_w = MIN_CHIP,
            }))
            natural = math.max(natural, WIDGET_TITLE.required_width(ctx, self, true))
        end
        return CHIP_ROW.apply_preview_width_cap(self, natural)
    end,
    getLayoutHeight = function(self, ctx, inner_w, is_vertical_toolbar)
        if not is_vertical_toolbar or not ctx or not reaper.ImGui_GetTextLineHeight then
            return CONFIG.SIZES.HEIGHT
        end
        return CONFIG.SIZES.HEIGHT
    end,
})
