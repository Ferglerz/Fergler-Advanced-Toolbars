-- widgets/tempo_display.lua
local widget = {
    name = "Tempo",
    category = "Time, grid & tempo",
    update_interval = 0.1,
    type = "display",
    width = 86,
    format = "%.1f BPM",
    display_style = "centered",
    description = "Shows current tempo. Click to tap tempo. Hover to see TAP mode.",

    tap_times = {},
    is_hovering = false,

    getValue = function(self)
        if self.is_hovering then
            return "TAP"
        end
        return reaper.Master_GetTempo()
    end,

    onHover = function(self)
        self.is_hovering = true
    end,

    onClick = function(self)
        local current_time = reaper.time_precise()

        table.insert(self.tap_times, current_time)

        if #self.tap_times > 4 then
            table.remove(self.tap_times, 1)
        end

        if #self.tap_times >= 2 then
            local intervals = {}
            for i = 2, #self.tap_times do
                table.insert(intervals, self.tap_times[i] - self.tap_times[i - 1])
            end

            local total_interval = 0
            for _, interval in ipairs(intervals) do
                total_interval = total_interval + interval
            end
            local avg_interval = total_interval / #intervals

            local new_tempo = 60.0 / avg_interval
            new_tempo = math.max(60, math.min(300, new_tempo))

            reaper.CSurf_OnTempoChange(new_tempo)
        end
    end,

    onRightClick = function()
        reaper.Main_OnCommand(40363, 0)
    end,
}

return widget
