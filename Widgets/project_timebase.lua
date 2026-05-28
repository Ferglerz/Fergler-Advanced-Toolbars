-- Widgets/project_timebase.lua
-- Project timebase (Time / Beats+length+rate / Beats position only) via GetSetProjectInfo; SWS fallback if needed.

local CHIP_MODE = require("Utils.chip_mode_widget")

local MODES = {
    { id = "time", label = "Time", proj = 0 },
    { id = "beats_all", short_label = "B+LR", label = "Beats (position, length, rate)", proj = 1 },
    { id = "beats_pos", short_label = "B.pos", label = "Beats (position only)", proj = 2 },
}

local SWS_FALLBACK = {
    [0] = "_SWS_AWTBASETIME",
    [1] = "_SWS_AWTBASEBEATALL",
    [2] = "_SWS_AWTBASEBEATPOS",
}

local function read_project_timebase()
    return math.floor(reaper.GetSetProjectInfo(0, "PROJECT_TIMEBASE", 0, false) + 0.5)
end

local function apply_project_timebase(proj_val)
    reaper.GetSetProjectInfo(0, "PROJECT_TIMEBASE", proj_val, true)
    local now = math.floor(reaper.GetSetProjectInfo(0, "PROJECT_TIMEBASE", 0, false) + 0.5)
    if now == proj_val then
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

return CHIP_MODE.new({
    name = "Project Timebase",
    category = "Items & selection",
    update_interval = 0.2,
    description = "Project default timebase: time, beats (position/length/rate), or beats (position only). Uses project API; SWS actions as fallback if the API cannot set timebase.",
    width = 200,
    modes = MODES,
    prefix = "ptb_",
    min_chip_w = 28,
    preview_ids = { "time", "beats_all", "beats_pos" },
    preview_title = "Proj. timebase",
    default_active_id = "time",
    getValue = function(self, modes)
        local v = read_project_timebase()
        if v < 0 or v > 2 then
            v = 0
        end
        self._active_id = modes[1].id
        for _, m in ipairs(modes) do
            if m.proj == v then
                self._active_id = m.id
                break
            end
        end
        return v
    end,
    apply = function(_self, mode)
        apply_project_timebase(mode.proj)
    end,
})
