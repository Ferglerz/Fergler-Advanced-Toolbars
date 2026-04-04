-- Widgets/Under Development/fx_cpu_culprit.lua
-- Highest per-instance FX CPU in the project (requires TrackFX_GetCPUUsage in your REAPER build).

local widget = {
    name = "FX CPU Culprit",
    macro_group = "Under Development",
    update_interval = 1.0,
    type = "display",
    width = 200,
    title = "FX CPU",
    description = "Shows the single FX instance using the most CPU (project-wide). Click: select that track and open its FX chain on this plugin. Requires REAPER with TrackFX_GetCPUUsage; if missing, the widget shows a hint.",
    _top = nil,
    _top_cpu = 0.0,
    _line = "",
    _no_api = false,
}

local function scan_chain(track, cpu_fn, self)
    local n = reaper.TrackFX_GetCount(track)
    for fx = 0, n - 1 do
        if reaper.TrackFX_GetOffline(track, fx) == 0 then
            local ok, v = pcall(cpu_fn, track, fx)
            if ok and type(v) == "number" and v > self._top_cpu then
                self._top_cpu = v
                self._top = { track = track, fx = fx }
            end
        end
    end
end

function widget.getValue(self)
    local cpu_fn = reaper.TrackFX_GetCPUUsage
    if type(cpu_fn) ~= "function" then
        self._no_api = true
        self._line = "CPU API N/A"
        self._top = nil
        return 0
    end

    self._no_api = false
    self._top_cpu = 0.0
    self._top = nil

    local master = reaper.GetMasterTrack(0)
    if master then
        scan_chain(master, cpu_fn, self)
    end
    local tc = reaper.CountTracks(0)
    for ti = 0, tc - 1 do
        local tr = reaper.GetTrack(0, ti)
        if tr then
            scan_chain(tr, cpu_fn, self)
        end
    end

    if not self._top then
        self._line = "—"
        return 0
    end

    local tr = self._top.track
    local fx = self._top.fx
    local _, pname = reaper.TrackFX_GetFXName(tr, fx)
    pname = pname or ("FX " .. tostring(fx))
    self._line = string.format("%.1f%% · %s", self._top_cpu, pname)
    return self._top_cpu
end

function widget.onClick(self)
    if self._no_api or not self._top or not self._top.track then
        return
    end
    local tr = self._top.track
    reaper.SetOnlyTrackSelected(tr)
    reaper.TrackFX_Show(tr, self._top.fx, 3)
end

function widget.renderCustom(ctx, self, rel_x, rel_y, render_width, coords, draw_list, text_color, _layout, _bg_color)
    local height = CONFIG.SIZES.HEIGHT
    local pad = 6
    local span = math.max(20, render_width - pad * 2)
    local text = self._line or "—"
    if reaper.ImGui_CalcTextSize(ctx, text) > span then
        while #text > 2 and reaper.ImGui_CalcTextSize(ctx, text .. "…") > span do
            text = text:sub(1, -2)
        end
        text = text .. "…"
    end
    DRAWING.drawWidgetCenteredLabel(ctx, self, rel_x, rel_y, render_width, coords, draw_list, rel_y + 1)
    DRAWING.drawWidgetCenteredValueText(ctx, text, rel_x, rel_y, render_width, height, coords, draw_list, text_color, 7)
end

return widget
