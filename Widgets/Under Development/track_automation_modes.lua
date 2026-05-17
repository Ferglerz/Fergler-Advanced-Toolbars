-- Widgets/Under Development/track_automation_modes.lua
-- Chip selector for selected-track automation mode.

local CHIP_MS = require("Utils.chip_multiswitch")
local CHIP_ROW = require("Renderers._Widgets_chip_row")
local CHIP_HIT = require("Utils.chip_hit_prefix")
local PREVIEW_FB = require("Utils.widget_preview_fallback")

local MODES = {
    { id = "trim", label = "Trim", value = 0, command_id = 40400 },
    { id = "read", label = "Read", value = 1, command_id = 40401 },
    { id = "touch", label = "Touch", value = 2, command_id = 40402 },
    { id = "write", label = "Write", value = 3, command_id = 40403 },
    { id = "latch", label = "Latch", value = 4, command_id = 40404 },
    { id = "preview", short_label = "L.Pre", label = "Latch preview", value = 5, command_id = 42023 },
}

CHIP_MS.normalize_chip_entries(MODES)

local widget = {
    name = "Track Automation Modes",
    category = "Under Development",
    update_interval = 0.1,
    type = "display",
    width = 340,
    label = "",
    description = "Chip selector for selected-track automation modes. Follows current track selection and shows mixed-state feedback.",
    chip_widget = true,
    _selected_mode = nil,
    _mixed = false,
    _has_selection = false,
}

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

local function mode_by_id(id)
    for _, m in ipairs(MODES) do
        if m.id == id then
            return m
        end
    end
    return nil
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

local function horizontal_multiswitch_cols(ctx, n)
    if not ctx or not reaper.ImGui_GetTextLineHeight or n < 1 then
        return math.max(1, n)
    end
    local chip_h = CHIP_ROW.chip_line_height(ctx)
    local gap = CHIP_ROW.CHIP_GAP
    local btn_h = tonumber(CONFIG.SIZES.HEIGHT) or chip_h
    local rows = (2 * chip_h + gap <= btn_h) and 2 or 1
    return math.ceil(n / rows)
end

local function layout_chips(ctx, rel_x, rel_y, render_width, layout)
    return CHIP_ROW.layout_multiswitch_grid(ctx, rel_x, rel_y, render_width, layout, MODES, {
        min_chip_w = 28,
        pad_x = 4,
    })
end

local function preview_mode_entries(mode_ids)
    local list = {}
    for _, pid in ipairs(mode_ids) do
        local m = mode_by_id(pid)
        if m then
            list[#list + 1] = m
        end
    end
    return list
end

local function draw_automation_multiswitch(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, enabled, mixed, mx, my, vert)
    CHIP_MS.draw(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, {
        mx = mx,
        my = my,
        enabled = enabled,
        mixed = mixed,
        chip_round = CHIP_ROW.CHIP_ROUND,
        grid_layout = true,
        slide_namespace = "tam_ms",
        label_for = function(c)
            if not c.mode then
                return ""
            end
            return CHIP_MS.label_for_orientation(ctx, c.mode, c.w, vert == true, 4)
        end,
        is_selected_segment = function(c)
            if c.blank or mixed then
                return false
            end
            return self._selected_mode == c.mode.value
        end,
    })
end

function widget.getLayoutWidth(self, ctx)
    local natural = self.width or 340
    if ctx and reaper.ImGui_GetTextLineHeight then
        local cols = horizontal_multiswitch_cols(ctx, #MODES)
        local R = CHIP_ROW.button_rounding_content_pad()
        local pad = 8 + R * 2
        local gap = CHIP_ROW.CHIP_GAP
        local min_per = 28
        local computed = pad + cols * min_per + gap * math.max(0, cols - 1)
        natural = math.max(natural, computed)
    end
    local cap = tonumber(self._preview_width_cap)
    if cap and cap > 0 then
        return math.min(natural, cap)
    end
    return natural
end

function widget.getLayoutHeight(self, ctx, inner_w, is_vertical_toolbar)
    local base = CONFIG.SIZES.HEIGHT
    if not is_vertical_toolbar or not ctx or not reaper.ImGui_GetTextLineHeight then
        return base
    end
    local iw = tonumber(inner_w, nil) or tonumber(self.width, nil) or 340
    local _, ms_h = CHIP_ROW.layout_multiswitch_grid(ctx, 0, 0, math.max(40, iw), { is_vertical = true }, MODES, {
        min_chip_w = 28,
        pad_x = 4,
    })
    local status_band = 18
    local R = CHIP_ROW.button_rounding_content_pad()
    return ms_h + status_band + 4 + R
end

function widget.getValue(self)
    local mode, mixed, has_selection = get_selection_mode_state()
    self._selected_mode = mode
    self._mixed = mixed
    self._has_selection = has_selection
    return mode or -1
end

function widget.hitTestSubcontrols(self, ctx, coords, rel_x, rel_y, render_width, layout)
    if not self._has_selection then
        return nil
    end
    local mx, my = coords:getRelativeMouse()
    local chips = layout_chips(ctx, rel_x, rel_y, render_width, layout)
    return CHIP_ROW.hit_test_chips(mx, my, coords, chips, "mode_")
end

function widget.onSubcontrolClick(self, sub_id)
    local id = CHIP_HIT.strip("mode_", sub_id)
    if not id then
        return false
    end
    local m = mode_by_id(id)
    if not m then
        return false
    end
    if m.command_id then
        reaper.Main_OnCommand(m.command_id, 0)
    else
        if not set_selected_tracks_mode(m.value) then
            return false
        end
    end
    self._selected_mode = m.value
    self._mixed = false
    self._has_selection = reaper.CountSelectedTracks(0) > 0
    return true
end

local PREVIEW_MODE_IDS = { "read", "write", "touch" }

local function render_preview(ctx, self, rel_x, rel_y, render_width, coords, draw_list, btn_txt, btn_bg)
    local h = CONFIG.SIZES.HEIGHT
    local mx, my = coords:getRelativeMouse()
    local enabled = self._has_selection

    local chips = CHIP_ROW.layout_multiswitch_grid(ctx, rel_x, rel_y, render_width, { is_vertical = false }, preview_mode_entries(PREVIEW_MODE_IDS), {
        min_chip_w = 28,
        pad_x = 4,
    })
    if PREVIEW_FB.when(ctx, not chips or #chips < 1, "Automation", rel_x, rel_y, render_width, h, coords, draw_list, btn_txt, 0) then
        return
    end

    draw_automation_multiswitch(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, enabled, self._mixed, mx, my, false)
end

function widget.renderCustom(ctx, self, rel_x, rel_y, render_width, coords, draw_list, text_color, layout, bg_color)
    local btn_txt = text_color or 0xFFFFFFFF
    local btn_bg = bg_color or 0x000000FF
    if self._preview_mode then
        render_preview(ctx, self, rel_x, rel_y, render_width, coords, draw_list, btn_txt, btn_bg)
        return
    end
    local chips = layout_chips(ctx, rel_x, rel_y, render_width, layout)
    local mx, my = coords:getRelativeMouse()
    local enabled = self._has_selection
    local vert = layout and layout.is_vertical

    draw_automation_multiswitch(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, enabled, self._mixed, mx, my, vert)

    local status
    if not enabled then
        status = "No selected track"
    elseif self._mixed then
        status = "Mixed automation modes"
    end
    if status then
        local dim = btn_txt & 0xFFFFFF00 | 0xAA
        local line_h = reaper.ImGui_GetTextLineHeight(ctx)
        local sw = reaper.ImGui_CalcTextSize(ctx, status)
        local sy
        local sx
        if vert then
            sy = rel_y + (layout and layout.height or CONFIG.SIZES.HEIGHT) - line_h - 4
            sx = rel_x + (render_width - sw) / 2
        else
            sx = rel_x + render_width - sw - 4
            sy = rel_y + 1
        end
        local dx, dy = coords:relativeToDrawList(sx, sy)
        reaper.ImGui_DrawList_AddText(draw_list, dx, dy, dim, status)
    end
end

return widget
