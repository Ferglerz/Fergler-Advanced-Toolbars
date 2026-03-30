-- widgets/last_touched_param.lua
-- Last touched FX parameter: click toggles automation lane visibility; right-click toggles Write arm;
-- right-hand "Learn" opens MIDI learn for that parameter.

local LEARN_PAD = 4
local LEARN_RIGHT_PAD = LEARN_PAD + 2
local LEARN_INSET_H = 4
local LEARN_INSET_V = 3
local LEARN_ROUND = 3
local LEARN_BG = 0x141414FF
local LEARN_BG_HOVER = 0x222222FF
local LEARN_TEXT = 0xCCCCCCFF
local LEARN_TEXT_HOVER = 0xEEEEEEFF

local AUTOMODE_READ = 1
local AUTOMODE_WRITE = 4

local widget = {
    name = "Last Touched Param",
    update_interval = 0.2,
    type = "display",
    width = 248,
    label = "Last param",
    description = "Shows the last touched FX parameter. Click: toggle its automation lane visibility in the TCP. Right-click: toggle track automation mode between Read and Write. Learn: open MIDI learn for this parameter.",
    _ctx = nil,
    _line = "",
}

local function resolve_last_touched()
    local rv, tracknumber, fxnumber, paramnumber = reaper.GetLastTouchedFX()
    if not rv then
        return nil
    end

    local tr_idx = tracknumber & 0xFFFF
    local item_1based = (tracknumber >> 16) & 0xFFFF

    local track
    if tr_idx == 0 then
        track = reaper.GetMasterTrack(0)
    else
        track = reaper.GetTrack(0, tr_idx - 1)
    end
    if not track then
        return nil
    end

    if item_1based == 0 then
        local fx = fxnumber & 0xFFFFFF
        return {
            track = track,
            take = nil,
            fx = fx,
            param = paramnumber,
            is_take = false,
        }
    end

    local item = reaper.GetTrackMediaItem(track, item_1based - 1)
    if not item then
        return nil
    end
    local take_1based = (fxnumber >> 16) & 0xFFFF
    local fx = fxnumber & 0xFFFF
    local take = reaper.GetMediaItemTake(item, take_1based - 1)
    if not take then
        return nil
    end
    return {
        track = track,
        take = take,
        fx = fx,
        param = paramnumber,
        is_take = true,
    }
end

function widget.getValue(self)
    local ctx = resolve_last_touched()
    self._ctx = ctx
    if not ctx then
        self._line = "—"
        return 0
    end

    local fx_name, param_name
    if ctx.is_take then
        _, fx_name = reaper.TakeFX_GetFXName(ctx.take, ctx.fx)
        _, param_name = reaper.TakeFX_GetParamName(ctx.take, ctx.fx, ctx.param)
    else
        _, fx_name = reaper.TrackFX_GetFXName(ctx.track, ctx.fx)
        _, param_name = reaper.TrackFX_GetParamName(ctx.track, ctx.fx, ctx.param)
    end
    fx_name = fx_name or "FX"
    param_name = param_name or "param"
    self._line = fx_name .. ": " .. param_name
    return 0
end

local function toggle_envelope_lane_visible(env)
    local ret, chunk = reaper.GetEnvelopeStateChunk(env, "", false)
    if not ret or not chunk or chunk == "" then
        return
    end
    local new_chunk, reps = chunk:gsub("(VIS%s+)(%d)", function(vis_prefix, d)
        return vis_prefix .. (d == "1" and "0" or "1")
    end, 1)
    if reps > 0 and new_chunk ~= chunk then
        reaper.SetEnvelopeStateChunk(env, new_chunk, false)
    end
end

local function toggle_envelope_lane(ctx)
    if ctx.is_take and ctx.take then
        local env = reaper.TakeFX_GetEnvelope(ctx.take, ctx.fx, ctx.param, false)
        if not env then
            reaper.TakeFX_GetEnvelope(ctx.take, ctx.fx, ctx.param, true)
        else
            toggle_envelope_lane_visible(env)
        end
    else
        local env = reaper.GetFXEnvelope(ctx.track, ctx.fx, ctx.param, false)
        if not env then
            reaper.GetFXEnvelope(ctx.track, ctx.fx, ctx.param, true)
        else
            toggle_envelope_lane_visible(env)
        end
    end
    reaper.TrackList_AdjustWindows(false)
end

local function focus_context(ctx)
    reaper.SetOnlyTrackSelected(ctx.track)
    if ctx.is_take and ctx.take then
        local item = reaper.GetMediaItemTake_Item(ctx.take)
        if item then
            reaper.SelectAllMediaItems(0, false)
            reaper.SetMediaItemSelected(item, true)
        end
    end
end

function widget.onClick(self)
    local ctx = self._ctx
    if not ctx or not ctx.track then
        return
    end
    focus_context(ctx)
    toggle_envelope_lane(ctx)
end

function widget.onRightClick(self)
    local ctx = self._ctx
    if not ctx or not ctx.track then
        return
    end
    focus_context(ctx)
    local mode = math.floor(reaper.GetMediaTrackInfo_Value(ctx.track, "I_AUTOMODE") + 0.5)
    if mode == AUTOMODE_WRITE then
        reaper.SetMediaTrackInfo_Value(ctx.track, "I_AUTOMODE", AUTOMODE_READ)
    else
        reaper.SetMediaTrackInfo_Value(ctx.track, "I_AUTOMODE", AUTOMODE_WRITE)
    end
    reaper.TrackList_AdjustWindows(false)
end

function widget.onLearn(self)
    local ctx = self._ctx
    if not ctx or not ctx.track then
        return
    end
    focus_context(ctx)
    -- Main: FX: Set MIDI learn for last touched FX parameter
    reaper.Main_OnCommand(41144, 0)
end

function widget.onSubcontrolClick(self, sub_id)
    if sub_id == "learn" then
        self:onLearn()
    end
end

local function learn_chip_geometry(ctx, rel_x, rel_y, render_width)
    local bx, by, bw, bh = DRAWING.getRightAlignedTextChipRect(
        ctx,
        rel_x,
        rel_y,
        render_width,
        "Learn",
        LEARN_RIGHT_PAD,
        LEARN_INSET_H,
        LEARN_INSET_V
    )
    return bx, by, bw, bh
end

function widget.hitTestSubcontrols(ctx, coords, rel_x, rel_y, render_width)
    local bx, by, bw, bh = learn_chip_geometry(ctx, rel_x, rel_y, render_width)
    local mx, my = coords:getRelativeMouse()
    if coords:pointInRelativeRect(mx, my, bx, by, bw, bh) then
        return "learn"
    end
    return nil
end

function widget.renderCustom(ctx, self, rel_x, rel_y, render_width, coords, draw_list, text_color)
    local height = CONFIG.SIZES.HEIGHT
    local pad = 6
    local bx, by, bw, bh = learn_chip_geometry(ctx, rel_x, rel_y, render_width)
    local value_span = math.max(20, render_width - pad * 2 - bw - LEARN_PAD)
    local text = self._line or "—"
    if reaper.ImGui_CalcTextSize(ctx, text) > value_span then
        while #text > 2 and reaper.ImGui_CalcTextSize(ctx, text .. "…") > value_span do
            text = text:sub(1, -2)
        end
        text = text .. "…"
    end
    DRAWING.drawWidgetCenteredLabel(ctx, self, rel_x, rel_y, render_width, coords, draw_list, rel_y + 1)
    DRAWING.drawWidgetCenteredValueText(ctx, text, rel_x, rel_y, value_span, height, coords, draw_list, text_color, 7)

    local learn_lbl = "Learn"
    local bg = LEARN_BG
    local lcol = LEARN_TEXT
    if coords:mouseOverRelative(bx, by, bw, bh) then
        bg = LEARN_BG_HOVER
        lcol = LEARN_TEXT_HOVER
    end
    DRAWING.drawTextChip(
        ctx,
        coords,
        draw_list,
        bx,
        by,
        bw,
        bh,
        learn_lbl,
        {
            bg_color = bg,
            text_color = lcol,
            rounding = LEARN_ROUND
        }
    )
end

return widget
