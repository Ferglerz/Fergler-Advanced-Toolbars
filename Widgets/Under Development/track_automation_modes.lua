-- Widgets/Under Development/track_automation_modes.lua
-- Chip selector for selected-track automation mode.

local CHIP_GAP = 4
local CHIP_V_PAD = 3
local CHIP_ROUND = 3

local MODES = {
    { id = "trim", label = "Trim", value = 0, command_id = 40400 },
    { id = "read", label = "Read", value = 1, command_id = 40401 },
    { id = "touch", label = "Touch", value = 2, command_id = 40402 },
    { id = "write", label = "Write", value = 3, command_id = 40403 },
    { id = "latch", label = "Latch", value = 4, command_id = 40404 },
    { id = "preview", label = "L.Pre", value = 5, command_id = 42023 },
}

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

function widget.getLayoutWidth(self, ctx)
    local natural = self.width or 340
    if ctx and reaper.ImGui_GetTextLineHeight then
        local total = #MODES
        local per_min = 28
        local computed = 8 + total * per_min + CHIP_GAP * (total - 1)
        natural = math.max(natural, computed)
    end
    local cap = tonumber(self._preview_width_cap)
    if cap and cap > 0 then
        return math.min(natural, cap)
    end
    return natural
end

local function chip_layout(ctx, rel_x, rel_y, render_width)
    local h = CONFIG.SIZES.HEIGHT
    local chip_h = reaper.ImGui_GetTextLineHeight(ctx) + CHIP_V_PAD * 2
    local row_y = rel_y + (h - chip_h) / 2
    local total = #MODES
    local usable_w = math.max(30, render_width - 8)
    local per_w = math.floor((usable_w - CHIP_GAP * (total - 1)) / total)
    per_w = math.max(28, per_w)
    local x = rel_x + 4
    local chips = {}
    for _, m in ipairs(MODES) do
        chips[#chips + 1] = {
            id = m.id,
            x = x,
            y = row_y,
            w = per_w,
            h = chip_h,
            mode = m,
        }
        x = x + per_w + CHIP_GAP
    end
    return chips
end

--- Preview: three segments, same grouped layout as main when width allows.
local function preview_chip_layout(ctx, rel_x, rel_y, render_width, mode_ids)
    local h = CONFIG.SIZES.HEIGHT
    local chip_h = reaper.ImGui_GetTextLineHeight(ctx) + CHIP_V_PAD * 2
    local row_y = rel_y + (h - chip_h) / 2
    local chips = {}
    for _, pid in ipairs(mode_ids) do
        local m = mode_by_id(pid)
        if m then
            chips[#chips + 1] = { id = m.id, mode = m }
        end
    end
    local total = #chips
    if total <= 0 then
        return {}
    end
    local usable_w = math.max(30, render_width - 8)
    local per_w = math.floor((usable_w - CHIP_GAP * (total - 1)) / total)
    per_w = math.max(28, per_w)
    local row_w = total * per_w + CHIP_GAP * (total - 1)
    if row_w > render_width - 8 then
        return nil
    end
    local x = rel_x + (render_width - row_w) / 2
    for _, c in ipairs(chips) do
        c.x = x
        c.y = row_y
        c.w = per_w
        c.h = chip_h
        x = x + per_w + CHIP_GAP
    end
    return chips
end

local function draw_automation_multiswitch(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, enabled, mixed, mx, my)
    CHIP_MULTISWITCH.draw(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, {
        mx = mx,
        my = my,
        enabled = enabled,
        mixed = mixed,
        chip_round = CHIP_ROUND,
        is_selected_segment = function(c)
            return self._selected_mode == c.mode.value
        end,
    })
end

function widget.getValue(self)
    local mode, mixed, has_selection = get_selection_mode_state()
    self._selected_mode = mode
    self._mixed = mixed
    self._has_selection = has_selection
    return mode or -1
end

function widget.hitTestSubcontrols(self, ctx, coords, rel_x, rel_y, render_width)
    if not self._has_selection then
        return nil
    end
    local mx, my = coords:getRelativeMouse()
    local chips = chip_layout(ctx, rel_x, rel_y, render_width)
    for _, chip in ipairs(chips) do
        if coords:pointInRelativeRect(mx, my, chip.x, chip.y, chip.w, chip.h) then
            return "mode_" .. chip.id
        end
    end
    return nil
end

function widget.onSubcontrolClick(self, sub_id)
    local id = sub_id and sub_id:match("^mode_(.+)$")
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

    local chips = preview_chip_layout(ctx, rel_x, rel_y, render_width, PREVIEW_MODE_IDS)
    if not chips then
        DRAWING.drawWidgetCenteredValueText(ctx, "Automation", rel_x, rel_y, render_width, h, coords, draw_list, btn_txt, 0)
        return
    end

    draw_automation_multiswitch(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, enabled, self._mixed, mx, my)
end

function widget.renderCustom(ctx, self, rel_x, rel_y, render_width, coords, draw_list, text_color, _layout, bg_color)
    local btn_txt = text_color or 0xFFFFFFFF
    local btn_bg = bg_color or 0x000000FF
    if self._preview_mode then
        render_preview(ctx, self, rel_x, rel_y, render_width, coords, draw_list, btn_txt, btn_bg)
        return
    end
    local chips = chip_layout(ctx, rel_x, rel_y, render_width)
    local mx, my = coords:getRelativeMouse()
    local enabled = self._has_selection

    draw_automation_multiswitch(ctx, self, chips, coords, draw_list, btn_txt, btn_bg, enabled, self._mixed, mx, my)

    local status
    if not enabled then
        status = "No selected track"
    elseif self._mixed then
        status = "Mixed automation modes"
    end
    if status then
        local sw = reaper.ImGui_CalcTextSize(ctx, status)
        local sx = rel_x + render_width - sw - 4
        local sy = rel_y + 1
        local dx, dy = coords:relativeToDrawList(sx, sy)
        local dim = btn_txt & 0xFFFFFF00 | 0xAA
        reaper.ImGui_DrawList_AddText(draw_list, dx, dy, dim, status)
    end
end

return widget
