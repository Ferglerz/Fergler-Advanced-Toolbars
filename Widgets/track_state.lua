-- widgets/track_state.lua
-- Track state indicator with Record-arm / Mute / Solo square cells, plus Solo dim chip.

local CELL_SIZE = 22
local CELL_GAP = 3
local CELL_ROUND = 4
local CELL_STROKE = 1.0
local HOVER_ALPHA = 0x3A
local LABEL_TEXT = { "R", "M", "S" }
local LABEL_COL = 0xFFFFFFFF
local LABEL_SIZE_BOOST = 1
local BG_IDLE = 0x101010FF
local RED = 0xCC3333FF
local YELLOW = 0xD4AF37FF
local LAVENDER = 0xB57EDCFF
local DIM_LABEL = "Dim"
local DIM_CELL_W = 34
local STATE_COLORS = { RED, RED, YELLOW }

-- Options: Solo dim (toggle)
local SOLO_DIM_CMD = 40745

local widget = {
    name = "Track State",
    category = "Project & surfaces",
    update_interval = 0.1,
    type = "display",
    width = 116,
    label = "",
    description = "Shows global track status for Record-arm, Mute, and Solo; Solo dim on/off (action 40745) on the Dim chip. Click Dim toggles that action.",
    _any_armed = false,
    _any_muted = false,
    _any_soloed = false,
    _solo_dim_on = false,
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

local function solo_dim_toggle_state()
    local ok, st = pcall(reaper.GetToggleCommandState, SOLO_DIM_CMD)
    return ok and st == 1
end

local function strip_total_width(ctx)
    local dim_w = DIM_CELL_W
    if ctx and reaper.ImGui_GetFont then
        local f = reaper.ImGui_GetFont(ctx)
        if f then
            local sz = (CONFIG.SIZES.TEXT or 12) + LABEL_SIZE_BOOST
            reaper.ImGui_PushFont(ctx, f, sz)
            dim_w = math.max(DIM_CELL_W, math.ceil(reaper.ImGui_CalcTextSize(ctx, DIM_LABEL) + 10))
            reaper.ImGui_PopFont(ctx)
        end
    end
    return CELL_SIZE * 3 + CELL_GAP * 3 + dim_w
end

local function cell_strip_origin(rel_x, rel_y, render_width, ctx)
    local h = CONFIG.SIZES.HEIGHT
    local total_w = strip_total_width(ctx)
    local start_x = rel_x + math.floor((render_width - total_w) / 2)
    local start_y = rel_y + math.floor((h - CELL_SIZE) / 2)
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
    self._solo_dim_on = solo_dim_toggle_state()
    return 0
end

function widget.getLayoutWidth(self, ctx)
    local R = math.max(0, math.floor(tonumber(CONFIG.SIZES.ROUNDING) or 0))
    local inner = strip_total_width(ctx)
    return math.max(self.width or 0, inner + R * 2 + 10)
end

function widget.hitTestSubcontrols(_self, ctx, coords, rel_x, rel_y, render_width)
    local mx, my = coords:getRelativeMouse()
    local start_x, start_y = cell_strip_origin(rel_x, rel_y, render_width, ctx)
    for i = 1, 3 do
        local cell_rel_x = start_x + (i - 1) * (CELL_SIZE + CELL_GAP)
        if coords:pointInRelativeRect(mx, my, cell_rel_x, start_y, CELL_SIZE, CELL_SIZE) then
            if i == 1 then return "r" end
            if i == 2 then return "m" end
            return "s"
        end
    end
    local dim_x = start_x + 3 * (CELL_SIZE + CELL_GAP)
    local dim_w_cell = strip_total_width(ctx) - 3 * (CELL_SIZE + CELL_GAP)
    dim_w_cell = math.max(DIM_CELL_W, dim_w_cell)
    if coords:pointInRelativeRect(mx, my, dim_x, start_y, dim_w_cell, CELL_SIZE) then
        return "d"
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
    elseif sub_id == "d" then
        reaper.Main_OnCommand(SOLO_DIM_CMD, 0)
    end
end

function widget.renderCustom(ctx, self, rel_x, rel_y, render_width, coords, draw_list, _text_color, _layout, _bg_color)
    local start_x, start_y = cell_strip_origin(rel_x, rel_y, render_width, ctx)
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
        local cell_rel_x = start_x + (i - 1) * (CELL_SIZE + CELL_GAP)
        local cell_rel_y = start_y
        local x1, y1 = coords:relativeToDrawList(cell_rel_x, cell_rel_y)
        local x2, y2 = coords:relativeToDrawList(cell_rel_x + CELL_SIZE, cell_rel_y + CELL_SIZE)
        local col = STATE_COLORS[i]
        local is_hover = coords:pointInRelativeRect(mx, my, cell_rel_x, cell_rel_y, CELL_SIZE, CELL_SIZE)
        local hover_col = (col & 0xFFFFFF00) | HOVER_ALPHA

        if active[i] then
            reaper.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, col, CELL_ROUND)
            if is_hover then
                reaper.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, hover_col, CELL_ROUND)
            end
        else
            reaper.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, BG_IDLE, CELL_ROUND)
            reaper.ImGui_DrawList_AddRect(draw_list, x1, y1, x2, y2, col, CELL_ROUND, 0, CELL_STROKE)
            if is_hover then
                reaper.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, hover_col, CELL_ROUND)
            end
        end

        local txt = LABEL_TEXT[i]
        local tw = reaper.ImGui_CalcTextSize(ctx, txt)
        local tx = cell_rel_x + (CELL_SIZE - tw) / 2
        local ty = cell_rel_y + (CELL_SIZE - reaper.ImGui_GetTextLineHeight(ctx)) / 2
        local tdx, tdy = coords:relativeToDrawList(tx, ty)
        reaper.ImGui_DrawList_AddText(draw_list, tdx, tdy, LABEL_COL, txt)
    end

    -- Dim chip (Solo dim)
    local dim_x = start_x + 3 * (CELL_SIZE + CELL_GAP)
    local dim_w_cell = strip_total_width(ctx) - 3 * (CELL_SIZE + CELL_GAP)
    dim_w_cell = math.max(DIM_CELL_W, dim_w_cell)
    local dim_rel_y = start_y
    local dx1, dy1 = coords:relativeToDrawList(dim_x, dim_rel_y)
    local dx2, dy2 = coords:relativeToDrawList(dim_x + dim_w_cell, dim_rel_y + CELL_SIZE)
    local dim_on = self._solo_dim_on == true
    local dim_hover = coords:pointInRelativeRect(mx, my, dim_x, dim_rel_y, dim_w_cell, CELL_SIZE)
    local dim_hover_col = (LAVENDER & 0xFFFFFF00) | HOVER_ALPHA

    if dim_on then
        reaper.ImGui_DrawList_AddRectFilled(draw_list, dx1, dy1, dx2, dy2, LAVENDER, CELL_ROUND)
        if dim_hover then
            reaper.ImGui_DrawList_AddRectFilled(draw_list, dx1, dy1, dx2, dy2, dim_hover_col, CELL_ROUND)
        end
    else
        reaper.ImGui_DrawList_AddRectFilled(draw_list, dx1, dy1, dx2, dy2, BG_IDLE, CELL_ROUND)
        reaper.ImGui_DrawList_AddRect(draw_list, dx1, dy1, dx2, dy2, LAVENDER, CELL_ROUND, 0, CELL_STROKE)
        if dim_hover then
            reaper.ImGui_DrawList_AddRectFilled(draw_list, dx1, dy1, dx2, dy2, dim_hover_col, CELL_ROUND)
        end
    end

    local dtw = reaper.ImGui_CalcTextSize(ctx, DIM_LABEL)
    local dtx = dim_x + (dim_w_cell - dtw) / 2
    local dty = dim_rel_y + (CELL_SIZE - reaper.ImGui_GetTextLineHeight(ctx)) / 2
    local ddx, ddy = coords:relativeToDrawList(dtx, dty)
    reaper.ImGui_DrawList_AddText(draw_list, ddx, ddy, LABEL_COL, DIM_LABEL)

    if pushed_font then
        reaper.ImGui_PopFont(ctx)
    end
end

return widget
