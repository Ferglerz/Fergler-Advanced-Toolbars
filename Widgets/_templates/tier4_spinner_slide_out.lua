-- Spinner with presets. Replace command IDs and the project value API.
local WIDGET = require("Utils.Widget.widget_factory")

local MODES = {
    { id = "1", rate = 1.0, default_on = true, short_label = "1x" },
    { id = "2", rate = 2.0, default_on = true, short_label = "2x" },
}

return WIDGET.SpinnerSlideOut.new({
    name = "My Spinner",
    category = "General",
    description = "Choose a preset or adjust the value.",
    modes = MODES,
    cmd_spinner_up = 0,   -- TODO: REAPER command ID
    cmd_spinner_down = 0, -- TODO: REAPER command ID
    cmd_pitch_toggle = 0, -- TODO: REAPER command ID
    getValue = function(self)
        return self._play_rate or 1.0 -- TODO: read project value
    end,
    on_mode_select = function(self, mode)
        self._play_rate = mode.rate -- TODO: write project value
        self._active_ms_id = mode.id
    end,
})
