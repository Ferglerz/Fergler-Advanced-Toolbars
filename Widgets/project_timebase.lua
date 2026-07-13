-- Widgets/project_timebase.lua
-- Gold template: mode multiswitch + slide-out (tier 2 — WIDGET.CHIP_MODE.new).
-- Project timebase via GetSetProjectInfo (0–3); SWS/action fallback when API cannot set.

local WIDGET = require("Utils.Widget.widget_factory")
local TIMEBASE = require("Utils.Reaper.timebase_modes")

return WIDGET.CHIP_MODE.new(WIDGET.CHIP_MODE.with_slide_out_toolbar({
    name = "Project Timebase",
    category = "Items & selection",
    update_interval = 0.2,
    description = "Project default timebase: time, beats (position/length/rate), beats (position only), or beats (auto-stretch at tempo changes). Toolbar shows current mode; hover for full multiswitch. Uses project API; action 43640 / SWS as fallback.",
    width = 200,
    slide_namespace = "ptb_ms",
    toolbar_fallback = "Timebase",
    modes = TIMEBASE.PROJECT_MODES,
    prefix = "ptb_",
    default_active_id = "time",
    getValue = function(self)
        local v = TIMEBASE.read_project_timebase()
        self._active_id = TIMEBASE.project_mode_at(v).id
        return v
    end,
    apply = function(_self, mode)
        TIMEBASE.apply_project_timebase(mode.proj, mode.cmd)
    end,
}))
