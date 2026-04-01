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

local function draw_chip(ctx, coords, draw_list, chip, text, is_active, is_hover, enabled, btn_txt, btn_bg)
    local bg_col, text_col = COLOR_UTILS.widgetPillColors(btn_txt, btn_bg, {
        active = is_active,
        hover = is_hover and not is_active,
        disabled = not enabled,
    })
    local x1, y1 = coords:relativeToDrawList(chip.x, chip.y)
    local x2, y2 = coords:relativeToDrawList(chip.x + chip.w, chip.y + chip.h)
    reaper.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, bg_col, CHIP_ROUND)

    local tw = reaper.ImGui_CalcTextSize(ctx, text)
    local tx = chip.x + (chip.w - tw) / 2
    local ty = chip.y + (chip.h - reaper.ImGui_GetTextLineHeight(ctx)) / 2
    local dx, dy = coords:relativeToDrawList(tx, ty)
    reaper.ImGui_DrawList_AddText(draw_list, dx, dy, text_col, text)
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

--- Widget browser: three representative mode chips; label if too narrow.
local function render_preview(ctx, self, rel_x, rel_y, render_width, coords, draw_list, btn_txt, btn_bg)
    local h = CONFIG.SIZES.HEIGHT
    local chip_h = reaper.ImGui_GetTextLineHeight(ctx) + CHIP_V_PAD * 2
    local row_y = rel_y + (h - chip_h) / 2
    local mx, my = coords:getRelativeMouse()
    local enabled = self._has_selection

    local segments = {}
    local total_w = -CHIP_GAP
    for _, pid in ipairs(PREVIEW_MODE_IDS) do
        local m = mode_by_id(pid)
        if m then
            local tw = reaper.ImGui_CalcTextSize(ctx, m.label)
            local cw = math.max(28, tw + 6)
            segments[#segments + 1] = { mode = m, w = cw }
            total_w = total_w + cw + CHIP_GAP
        end
    end

    if total_w > render_width - 8 then
        DRAWING.drawWidgetCenteredValueText(ctx, "Automation", rel_x, rel_y, render_width, h, coords, draw_list, btn_txt, 0)
        return
    end

    local x = rel_x + (render_width - total_w) / 2
    for _, seg in ipairs(segments) do
        local m = seg.mode
        local chip = {
            id = m.id,
            x = x,
            y = row_y,
            w = seg.w,
            h = chip_h,
            mode = m,
        }
        local is_hover = enabled and coords:pointInRelativeRect(mx, my, chip.x, chip.y, chip.w, chip.h)
        local is_active = enabled and (not self._mixed) and (self._selected_mode == chip.mode.value)
        draw_chip(ctx, coords, draw_list, chip, chip.mode.label, is_active, is_hover, enabled, btn_txt, btn_bg)
        x = x + seg.w + CHIP_GAP
    end
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

    for _, chip in ipairs(chips) do
        local is_hover = enabled and coords:pointInRelativeRect(mx, my, chip.x, chip.y, chip.w, chip.h)
        local is_active = enabled and (not self._mixed) and (self._selected_mode == chip.mode.value)
        draw_chip(ctx, coords, draw_list, chip, chip.mode.label, is_active, is_hover, enabled, btn_txt, btn_bg)
    end

    local status
    if not enabled then
        status = "No selected track"
    elseif self._mixed then
        status = "Mixed automation modes"
    else
        status = "Selected tracks"
    end
    local sw = reaper.ImGui_CalcTextSize(ctx, status)
    local sx = rel_x + render_width - sw - 4
    local sy = rel_y + 1
    local dx, dy = coords:relativeToDrawList(sx, sy)
    local dim = btn_txt & 0xFFFFFF00 | 0xAA
    reaper.ImGui_DrawList_AddText(draw_list, dx, dy, dim, status)
end

return widget
