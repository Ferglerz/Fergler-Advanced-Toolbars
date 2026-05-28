-- Widgets/Under Development/ruler_time_unit.lua
-- Primary ruler time-unit chips (View: Time unit for ruler: … actions).

local CHIP_MODE = require("Utils.chip_mode_widget")

local MODES = {
    { id = "ms", short_label = "M:S", label = "Minutes:Seconds", command_id = 40365 },
    { id = "sec", short_label = "Sec", label = "Seconds", command_id = 40368 },
    { id = "smp", short_label = "Smp", label = "Samples", command_id = 40369 },
    { id = "tc", short_label = "TC", label = "Timecode", command_id = 40370 },
    { id = "mbmin", short_label = "M:B+", label = "Measures:Beats (minimal)", command_id = 41916 },
    { id = "afrm", short_label = "Abs.Frm", label = "Absolute Frames", command_id = 41973 },
}

local function detect_active_mode_id()
    for _, m in ipairs(MODES) do
        local ok, st = pcall(reaper.GetToggleCommandState, m.command_id)
        if ok and st == 1 then
            return m.id
        end
    end
    return nil
end

return CHIP_MODE.new({
    name = "Ruler Time Unit",
    category = "Under Development",
    update_interval = 0.2,
    width = 520,
    description = "Under Development: primary ruler time-unit actions; active chip may not match REAPER in every mode yet.",
    modes = MODES,
    prefix = "ruler_",
    min_chip_w = 24,
    preview_ids = { "ms", "sec", "tc" },
    preview_title = "Ruler time",
    state = { _last_click_id = nil },
    getValue = function(self)
        local from_reaper = detect_active_mode_id()
        if from_reaper then
            self._active_id = from_reaper
        elseif self._last_click_id then
            self._active_id = self._last_click_id
        else
            self._active_id = nil
        end
        return 0
    end,
    apply = function(self, mode)
        if not mode.command_id then
            return
        end
        reaper.Main_OnCommand(mode.command_id, 0)
        self._last_click_id = mode.id
    end,
})
