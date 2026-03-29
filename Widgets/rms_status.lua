-- widgets/rms_status.lua
-- Track status indicator with Record-arm / Mute / Solo chips.

local CHIP_SIZE = 22
local CHIP_GAP = 3
local CHIP_ROUND = 4
local CHIP_STROKE = 1.0
local HOVER_ALPHA = 0x3A
local LABEL_TEXT = { "R", "M", "S" }
local LABEL_COL = 0xFFFFFFFF
local LABEL_SIZE_BOOST = 1
local BG_IDLE = 0x101010FF
local RED = 0xCC3333FF
local YELLOW = 0xD4AF37FF
local CHIP_COL = { RED, RED, YELLOW }

local widget = {
    name = "RMS Status",
    update_interval = 0.1,
    type = "display",
    width = 78,
    label = "",
    description = "Shows global track status for Record-arm, Mute, and Solo.",
    _any_armed = false,
    _any_muted = false,
    _any_soloed = false,
}

local function any_tracks_state()
    local count = reaper.CountTracks(0)
    local any_armed, any_muted, any_soloed = false, false, false

    for i = 0, count - 1 do
        local tr = reaper.GetTrack(0, i)
        if tr then
            if not any_armed and reaper.GetMediaTrackInfo_Value(tr, "I_RECARM") > 0.5 then
                any_armed = true
            end
            if not any_muted and reaper.GetMediaTrackInfo_Value(tr, "B_MUTE") > 0.5 then
                any_muted = true
            end
            if not any_soloed and reaper.GetMediaTrackInfo_Value(tr, "I_SOLO") > 0.5 then
                any_soloed = true
            end
        end

        if any_armed and any_muted and any_soloed then
            break
        end
    end

    return any_armed, any_muted, any_soloed
end

local function chip_start_xy(rel_x, rel_y, render_width)
    local h = CONFIG.SIZES.HEIGHT
    local total_w = CHIP_SIZE * 3 + CHIP_GAP * 2
    local start_x = rel_x + math.floor((render_width - total_w) / 2)
    local start_y = rel_y + math.floor((h - CHIP_SIZE) / 2)
    return start_x, start_y
end

local function clear_all_for_state(sub_id)
    local count = reaper.CountTracks(0)
    for i = 0, count - 1 do
        local tr = reaper.GetTrack(0, i)
        if tr then
            if sub_id == "r" then
                reaper.SetMediaTrackInfo_Value(tr, "I_RECARM", 0)
            elseif sub_id == "m" then
                reaper.SetMediaTrackInfo_Value(tr, "B_MUTE", 0)
            elseif sub_id == "s" then
                reaper.SetMediaTrackInfo_Value(tr, "I_SOLO", 0)
            end
        end
    end
    reaper.TrackList_AdjustWindows(false)
end

function widget.getValue(self)
    self._any_armed, self._any_muted, self._any_soloed = any_tracks_state()
    return 0
end

function widget.hitTestSubcontrols(_ctx, coords, rel_x, rel_y, render_width)
    local mx, my = coords:getRelativeMouse()
    local start_x, start_y = chip_start_xy(rel_x, rel_y, render_width)
    for i = 1, 3 do
        local chip_rel_x = start_x + (i - 1) * (CHIP_SIZE + CHIP_GAP)
        if coords:pointInRelativeRect(mx, my, chip_rel_x, start_y, CHIP_SIZE, CHIP_SIZE) then
            if i == 1 then return "r" end
            if i == 2 then return "m" end
            return "s"
        end
    end
    return nil
end

function widget.onSubcontrolClick(self, sub_id)
    if sub_id == "r" then
        clear_all_for_state("r")
        self._any_armed = false
    elseif sub_id == "m" then
        clear_all_for_state("m")
        self._any_muted = false
    elseif sub_id == "s" then
        clear_all_for_state("s")
        self._any_soloed = false
    end
end

function widget.renderCustom(ctx, self, rel_x, rel_y, render_width, coords, draw_list, _text_color)
    local start_x, start_y = chip_start_xy(rel_x, rel_y, render_width)
    local mx, my = coords:getRelativeMouse()
    local pushed_font = false
    local current_font = reaper.ImGui_GetFont(ctx)
    local label_font_size = (CONFIG.SIZES.TEXT or 12) + LABEL_SIZE_BOOST
    if current_font then
        reaper.ImGui_PushFont(ctx, current_font, label_font_size)
        pushed_font = true
    end

    local active = {
        self._any_armed == true,
        self._any_muted == true,
        self._any_soloed == true,
    }

    for i = 1, 3 do
        local chip_rel_x = start_x + (i - 1) * (CHIP_SIZE + CHIP_GAP)
        local chip_rel_y = start_y
        local x1, y1 = coords:relativeToDrawList(chip_rel_x, chip_rel_y)
        local x2, y2 = coords:relativeToDrawList(chip_rel_x + CHIP_SIZE, chip_rel_y + CHIP_SIZE)
        local col = CHIP_COL[i]
        local is_hover = coords:pointInRelativeRect(mx, my, chip_rel_x, chip_rel_y, CHIP_SIZE, CHIP_SIZE)
        local hover_col = (col & 0xFFFFFF00) | HOVER_ALPHA

        if active[i] then
            reaper.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, col, CHIP_ROUND)
            if is_hover then
                reaper.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, hover_col, CHIP_ROUND)
            end
        else
            reaper.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, BG_IDLE, CHIP_ROUND)
            reaper.ImGui_DrawList_AddRect(draw_list, x1, y1, x2, y2, col, CHIP_ROUND, 0, CHIP_STROKE)
            if is_hover then
                reaper.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, hover_col, CHIP_ROUND)
            end
        end

        local txt = LABEL_TEXT[i]
        local tw = reaper.ImGui_CalcTextSize(ctx, txt)
        local tx = chip_rel_x + (CHIP_SIZE - tw) / 2
        local ty = chip_rel_y + (CHIP_SIZE - reaper.ImGui_GetTextLineHeight(ctx)) / 2
        local tdx, tdy = coords:relativeToDrawList(tx, ty)
        reaper.ImGui_DrawList_AddText(draw_list, tdx, tdy, LABEL_COL, txt)
    end

    if pushed_font then
        reaper.ImGui_PopFont(ctx)
    end
end

return widget
