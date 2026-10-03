-- widgets/cpu_usage.lua
-- Note: Reaper does not expose CPU load through its API, so we use system-level monitoring
-- All cloned instances share one sample; opening another toolbar must not run ps again.
local sample = {system = 0, reaper = 0, at = nil}
local SAMPLE_INTERVAL = 3.0
local widget = {
    name = "CPU Usage Display",
    category = "Project & surfaces",
    update_interval = SAMPLE_INTERVAL,
    type = "display",
    width = 120,
    title = "CPU",
    description = "Shows system and Reaper CPU usage. Click to open performance meter.",
    display_truncate = true,

    -- Cache for CPU values
    cached_system_cpu = 0,
    cached_reaper_cpu = 0,

    getValue = function(self)
        local current_time = reaper.time_precise()
        if sample.at and current_time - sample.at < SAMPLE_INTERVAL then
            self.cached_system_cpu, self.cached_reaper_cpu = sample.system, sample.reaper
            return sample.system
        end

        sample.at = current_time

        -- macOS-only: use a single ps+awk call instead of two top calls
        local os_str = (reaper.GetOS() or ""):lower()
        if os_str:find("osx") or os_str:find("mac") then
            local cmd = [[ps -A -o %cpu=,comm= | awk '{
                sys+=$1;
                lc=tolower($2);
                if (lc ~ /reaper/) reaper+=$1;
            } END {printf "%.1f\n%.1f\n", sys, reaper}']]

            local handle = io.popen(cmd)
            if handle then
                local result = handle:read("*a") or ""
                handle:close()

                local sys_cpu, reaper_cpu = result:match("([%d%.]+)%s+([%d%.]+)")
                if sys_cpu then
                    sample.system = tonumber(sys_cpu) or sample.system
                end
                if reaper_cpu then
                    sample.reaper = tonumber(reaper_cpu) or sample.reaper
                end
            end
        end

        self.cached_system_cpu, self.cached_reaper_cpu = sample.system, sample.reaper
        return sample.system
    end,

    display_text = function(self)
        return string.format("%.1f / %.1f %%", self.cached_reaper_cpu, self.cached_system_cpu)
    end,

    onClick = function()
        -- Launch performance meter (action 40240)
        reaper.Main_OnCommand(40240, 0)
    end,
}

return widget
