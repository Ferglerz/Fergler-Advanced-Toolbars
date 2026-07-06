-- Widgets/project_timebase.lua
-- Gold template: mode multiswitch + slide-out (tier 2 — WIDGET.CHIP_MODE.new).
-- Project timebase via GetSetProjectInfo (0–3); SWS/action fallback when API cannot set.

local WIDGET = require("Utils.Widget.widget_factory")
local TIMEBASE = require("Utils.Reaper.timebase_modes")

return WIDGET.CHIP_MODE.new({
    name = "Project Timebase",
    category = "Items & selection",
    update_interval = 0.2,
    description = "Project default timebase: time, beats (position/length/rate), beats (position only), or beats (auto-stretch at tempo changes). Toolbar shows current mode; hover for full multiswitch. Uses project API; action 43640 / SWS as fallback.",
    width = 200,
    slide_out = true,
    slide_namespace = "ptb_ms",
    slide_multi_toggle = false,
    toolbar_fallback = "Timebase",
    modes = TIMEBASE.PROJECT_MODES,
    prefix = "ptb_",
    min_chip_w = 28,
    preview_toolbar_chip = true,
    preview_active_id = function(self)
        if self.getValue then
            self.getValue(self)
        end
    end,
    default_active_id = "time",
    toolbar_label = function(self)
        local m = WIDGET.CHIP_MODE.mode_by_id(TIMEBASE.PROJECT_MODES, self._active_id)
        return m and WIDGET.CHIP_MS.chip_caption(m) or "Timebase"
    end,
    getValue = function(self)
        local v = TIMEBASE.read_project_timebase()
        self._active_id = TIMEBASE.project_mode_at(v).id
        return v
    end,
    apply = function(_self, mode)
        TIMEBASE.apply_project_timebase(mode.proj, mode.cmd)
    end,
})
