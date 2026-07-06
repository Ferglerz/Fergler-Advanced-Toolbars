-- widgets/last_touched_param.lua
-- Last touched FX parameter readout on host; Learn, Lane, TCP in slide-out.

local WIDGET = require("Utils.Widget.widget_factory")
local OPT = WIDGET.OPTIONS_SLIDE_OUT

local EMPTY_TEXT = "Last param"
local CMD_LEARN = 41144
local CMD_TCP = 41141

local SLIDE_CHIPS = {
    { id = "learn", short_label = "Learn", label = "Learn last touched FX parameter" },
    { id = "lane", short_label = "Lane", label = "Toggle automation lane visibility" },
    { id = "tcp", short_label = "TCP", label = "Show in TCP controls" },
}
WIDGET.CHIP_MS.normalize_chip_entries(SLIDE_CHIPS)

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

local function refresh_line(self)
    local ctx = resolve_last_touched()
    self._fx_ctx = ctx
    if not ctx then
        self._line = EMPTY_TEXT
        return
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

local function toggle_envelope_lane(fx_ctx)
    if fx_ctx.is_take and fx_ctx.take then
        local env = reaper.TakeFX_GetEnvelope(fx_ctx.take, fx_ctx.fx, fx_ctx.param, false)
        if not env then
            reaper.TakeFX_GetEnvelope(fx_ctx.take, fx_ctx.fx, fx_ctx.param, true)
        else
            toggle_envelope_lane_visible(env)
        end
    else
        local env = reaper.GetFXEnvelope(fx_ctx.track, fx_ctx.fx, fx_ctx.param, false)
        if not env then
            reaper.GetFXEnvelope(fx_ctx.track, fx_ctx.fx, fx_ctx.param, true)
        else
            toggle_envelope_lane_visible(env)
        end
    end
    reaper.TrackList_AdjustWindows(false)
end

local function focus_context(fx_ctx)
    reaper.SetOnlyTrackSelected(fx_ctx.track)
    if fx_ctx.is_take and fx_ctx.take then
        local item = reaper.GetMediaItemTake_Item(fx_ctx.take)
        if item then
            reaper.SelectAllMediaItems(0, false)
            reaper.SetMediaItemSelected(item, true)
        end
    end
end

local function envelope_lane_visible(fx_ctx)
    local env
    if fx_ctx.is_take and fx_ctx.take then
        env = reaper.TakeFX_GetEnvelope(fx_ctx.take, fx_ctx.fx, fx_ctx.param, false)
    else
        env = reaper.GetFXEnvelope(fx_ctx.track, fx_ctx.fx, fx_ctx.param, false)
    end
    if not env then
        return false
    end
    local ret, chunk = reaper.GetEnvelopeStateChunk(env, "", false)
    if not ret or not chunk then
        return false
    end
    local vis = chunk:match("VIS%s+(%d)")
    return vis == "1"
end

local INPUT_FX_FLAG = 0x1000000

local function track_tcp_fx_matches(fx, fxidx)
    if fxidx == fx then
        return true
    end
    if (fxidx & INPUT_FX_FLAG) ~= 0 and (fxidx & 0xFFFFFF) == fx then
        return true
    end
    return false
end

local function track_fx_parm_in_tcp(track, fx, param)
    local n = reaper.CountTCPFXParms(0, track)
    for i = 0, n - 1 do
        local ok, fxidx, parmidx = reaper.GetTCPFXParm(0, track, i)
        if ok and parmidx == param and track_tcp_fx_matches(fx, fxidx) then
            return true
        end
    end
    return false
end

local function take_fx_wak_block(take, fx)
    local item = reaper.GetMediaItemTake_Item(take)
    if not item then
        return nil
    end
    local ok, chunk = reaper.GetItemStateChunk(item, "", false)
    if not ok or chunk == "" then
        return nil
    end

    local take_idx = 0
    for i = 0, reaper.CountTakes(item) - 1 do
        if reaper.GetMediaItemTake(item, i) == take then
            take_idx = i
            break
        end
    end

    local chain_idx = 0
    local pos = 1
    while true do
        local chain_start = chunk:find("<FXCHAIN", pos, true)
        if not chain_start then
            return nil
        end
        local chain_end = chunk:find("\n>", chain_start)
        if not chain_end then
            return nil
        end
        if chain_idx == take_idx then
            local fx_idx = 0
            local block_pos = chain_start
            while block_pos <= chain_end do
                local block_start, block_end, block = chunk:find(
                    "(BYPASS %d+ %d+ %d+%s.-WAK %d+ %d+%s)",
                    block_pos
                )
                if not block_start or block_start > chain_end then
                    break
                end
                if fx_idx == fx then
                    return block
                end
                fx_idx = fx_idx + 1
                block_pos = block_end + 1
            end
            return nil
        end
        chain_idx = chain_idx + 1
        pos = chain_start + 8
    end
end

local function take_fx_parm_in_tcp(take, fx, param)
    local block = take_fx_wak_block(take, fx)
    if not block then
        return false
    end
    for line in block:gmatch("[^\r\n]+") do
        local parm = line:match("^PARM_TCP (%d+)$")
        if parm and tonumber(parm) == param then
            return true
        end
    end
    return false
end

local function tcp_control_visible(fx_ctx)
    if not fx_ctx or not fx_ctx.track then
        return false
    end
    if fx_ctx.is_take and fx_ctx.take then
        return take_fx_parm_in_tcp(fx_ctx.take, fx_ctx.fx, fx_ctx.param)
    end
    return track_fx_parm_in_tcp(fx_ctx.track, fx_ctx.fx, fx_ctx.param)
end

local function slide_chip_on(self, chip_id)
    if chip_id == "learn" then
        return false
    end
    local fx_ctx = self._fx_ctx
    if chip_id == "lane" then
        return fx_ctx and envelope_lane_visible(fx_ctx) or false
    end
    if chip_id == "tcp" then
        return fx_ctx and tcp_control_visible(fx_ctx) or false
    end
    return false
end

local function slide_chip_click(self, chip_id)
    local fx_ctx = self._fx_ctx
    if not fx_ctx or not fx_ctx.track then
        return
    end
    focus_context(fx_ctx)
    if chip_id == "learn" then
        reaper.Main_OnCommand(CMD_LEARN, 0)
    elseif chip_id == "lane" then
        toggle_envelope_lane(fx_ctx)
    elseif chip_id == "tcp" then
        reaper.Main_OnCommand(CMD_TCP, 0)
    end
end

return WIDGET.Segmented(OPT.with_slide_out({
    name = "Last Touched",
    category = "Mix & monitoring",
    update_interval = 0.2,
    width = 120,
    description = "Last touched FX parameter (compact two-line readout). Learn, Lane, and TCP in slide-out.",
    state = {
        _line = EMPTY_TEXT,
        _fx_ctx = nil,
    },

    on_update = function(self)
        refresh_line(self)
    end,

    slide_out_can_interact = function(self)
        if self._preview_mode then
            return true
        end
        return self._fx_ctx ~= nil
    end,

    rows = {
        {
            toolbar_only = true,
            segments = {
                {
                    type = "readout",
                    flex = true,
                    compact_two_line = true,
                    min_width = 48,
                    get_label = function(self)
                        if self._preview_mode then
                            return "ReaEQ: Band 1 Frequency"
                        end
                        return self._line or EMPTY_TEXT
                    end,
                },
            },
        },
        OPT.slide_toggle_chips(SLIDE_CHIPS, slide_chip_on, slide_chip_click, { min_chip_w = 40 }),
    },
}))
