-- Widgets/project_timebase.lua
-- Project timebase via GetSetProjectInfo (0–3); SWS/action fallback when API cannot set.

local CHIP_MODE = require("Utils.chip_mode_widget")
local CHIP_MS = require("Utils.chip_multiswitch")

local CMD_BEATS_AUTOSTRETCH = 43640

local MODES = {
    { id = "time", label = "Time", proj = 0 },
    { id = "beats_all", short_label = "B+LR", label = "Beats (position, length, rate)", proj = 1 },
    { id = "beats_pos", short_label = "B.pos", label = "Beats (position only)", proj = 2 },
    {
        id = "beats_stretch",
        short_label = "B+AS",
        label = "Beats (auto-stretch at tempo changes)",
        proj = 3,
        cmd = CMD_BEATS_AUTOSTRETCH,
    },
}

local SWS_FALLBACK = {
    [0] = "_SWS_AWTBASETIME",
    [1] = "_SWS_AWTBASEBEATALL",
    [2] = "_SWS_AWTBASEBEATPOS",
}

local function read_project_timebase()
    return math.floor(reaper.GetSetProjectInfo(0, "PROJECT_TIMEBASE", 0, false) + 0.5)
end

local function apply_project_timebase(proj_val, cmd_fallback)
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

return CHIP_MODE.new({
    name = "Project Timebase",
    category = "Items & selection",
    update_interval = 0.2,
    description = "Project default timebase: time, beats (position/length/rate), beats (position only), or beats (auto-stretch at tempo changes). Toolbar shows current mode; hover for full multiswitch. Uses project API; action 43640 / SWS as fallback.",
    width = 200,
    slide_out = true,
    slide_namespace = "ptb_ms",
    slide_multi_toggle = false,
    toolbar_fallback = "Timebase",
    modes = MODES,
    prefix = "ptb_",
    min_chip_w = 28,
    preview_ids = { "time", "beats_all", "beats_pos", "beats_stretch" },
    preview_title = "Proj. timebase",
    default_active_id = "time",
    toolbar_label = function(self)
        local m = CHIP_MODE.mode_by_id(MODES, self._active_id)
        return m and CHIP_MS.chip_caption(m) or "Timebase"
    end,
    getValue = function(self)
        local v = read_project_timebase()
        if v < 0 or v > 3 then
            v = 0
        end
        self._active_id = MODES[1].id
        for _, m in ipairs(MODES) do
            if m.proj == v then
                self._active_id = m.id
                break
            end
        end
        return v
    end,
    apply = function(_self, mode)
        apply_project_timebase(mode.proj, mode.cmd)
    end,
})
