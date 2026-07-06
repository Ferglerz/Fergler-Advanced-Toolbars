-- Utils/Reaper/timebase_modes.lua — shared project timebase mode defs and API helpers.

local M = {}

M.CMD_BEATS_AUTOSTRETCH = 43640

M.PROJECT_MODES = {
    { id = "time", label = "Time", proj = 0 },
    { id = "beats_all", short_label = "B+LR", label = "Beats (position, length, rate)", proj = 1 },
    { id = "beats_pos", short_label = "B.pos", label = "Beats (position only)", proj = 2 },
    {
        id = "beats_stretch",
        short_label = "B+AS",
        label = "Beats (auto-stretch at tempo changes)",
        proj = 3,
        cmd = M.CMD_BEATS_AUTOSTRETCH,
    },
}

local SWS_FALLBACK = {
    [0] = "_SWS_AWTBASETIME",
    [1] = "_SWS_AWTBASEBEATALL",
    [2] = "_SWS_AWTBASEBEATPOS",
}

function M.read_project_timebase()
    return math.floor(reaper.GetSetProjectInfo(0, "PROJECT_TIMEBASE", 0, false) + 0.5)
end

function M.project_mode_at(proj_val)
    local v = proj_val
    if v < 0 or v > 3 then
        v = 0
    end
    for _, m in ipairs(M.PROJECT_MODES) do
        if m.proj == v then
            return m
        end
    end
    return M.PROJECT_MODES[1]
end

function M.apply_project_timebase(proj_val, cmd_fallback)
    reaper.GetSetProjectInfo(0, "PROJECT_TIMEBASE", proj_val, true)
    local now = math.floor(reaper.GetSetProjectInfo(0, "PROJECT_TIMEBASE", 0, false) + 0.5)
    if now == proj_val then
        return
    end
    if cmd_fallback then
        reaper.Main_OnCommand(cmd_fallback, 0)
        return
    end
    local sws = SWS_FALLBACK[proj_val]
    if not sws then
        return
    end
    local cmd = reaper.NamedCommandLookup(sws)
    if cmd and cmd > 0 then
        reaper.Main_OnCommand(cmd, 0)
    end
end

return M
