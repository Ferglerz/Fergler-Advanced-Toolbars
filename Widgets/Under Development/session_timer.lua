-- widgets/session_timer.lua
-- Elapsed time since project load or last click; break reminder every 45 minutes (click resets).

local BREAK_SEC = 45 * 60

local widget = {
    name = "Session Timer",
    category = "Under Development",
    update_interval = 0.5,
    type = "display",
    width = 118,
    label = "Session",
    description = "Time in this project session. Break reminder after 45 minutes; click the widget to reset the timer. Opening another project resets the session.",
    session_start = nil,
    last_bucket = -1,
    _proj_path = nil,
}

local function format_hms(total_sec)
    total_sec = math.max(0, math.floor(total_sec + 0.5))
    local h = math.floor(total_sec / 3600)
    local m = math.floor((total_sec % 3600) / 60)
    local s = total_sec % 60
    if h > 0 then
        return string.format("%d:%02d:%02d", h, m, s)
    end
    return string.format("%02d:%02d", m, s)
end

function widget.getValue(self)
    local path = reaper.GetProjectPath("") or ""
    if self._proj_path ~= path then
        self._proj_path = path
        self.session_start = reaper.time_precise()
        self.last_bucket = -1
    end
    if not self.session_start then
        self.session_start = reaper.time_precise()
    end

    local elapsed = reaper.time_precise() - self.session_start
    local bucket = math.floor(elapsed / BREAK_SEC)

    if bucket > (self.last_bucket or -1) and bucket >= 1 then
        self.last_bucket = bucket
        reaper.ShowMessageBox(
            "You have been in this session for " .. tostring(bucket * 45) .. " minutes.\n\nTake a short break.\n\nClick the session timer on the toolbar to reset.",
            "Break reminder",
            0
        )
    end

    local next_at = (bucket + 1) * BREAK_SEC
    self._elapsed = elapsed
    self._remain = math.max(0, next_at - elapsed)
    return elapsed
end

function widget.onClick(self)
    self.session_start = reaper.time_precise()
    self.last_bucket = -1
    self._proj_path = reaper.GetProjectPath("") or ""
end

function widget.renderCustom(ctx, self, rel_x, rel_y, render_width, coords, draw_list, text_color, _layout, _bg_color)
    local height = CONFIG.SIZES.HEIGHT
    local elapsed = self._elapsed or 0
    local line
    if elapsed >= BREAK_SEC then
        text_color = 0xFF8888FF
        line = format_hms(elapsed) .. " · break overdue"
    else
        line = format_hms(elapsed) .. " · " .. format_hms(self._remain or 0) .. " left"
    end

    DRAWING.drawWidgetCenteredLabel(ctx, self, rel_x, rel_y, render_width, coords, draw_list, rel_y + 1)
    local pad = 6
    local span = math.max(20, render_width - pad * 2)
    if reaper.ImGui_CalcTextSize(ctx, line) > span then
        while #line > 2 and reaper.ImGui_CalcTextSize(ctx, line .. "…") > span do
            line = line:sub(1, -2)
        end
        line = line .. "…"
    end
    DRAWING.drawWidgetCenteredValueText(ctx, line, rel_x, rel_y, render_width, height, coords, draw_list, text_color, 7)
end

return widget
