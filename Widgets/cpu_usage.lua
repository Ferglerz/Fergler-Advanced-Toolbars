-- widgets/cpu_usage.lua
-- Note: Reaper does not expose CPU load through its API, so we use system-level monitoring
local widget = {
    name = "CPU Usage Display",
    -- Update every 2 seconds (expensive shell call but acceptable at low rate)
    update_interval = 2.0,
    type = "display",
    width = 120,
    format = "%.0f%%",
    label = "CPU",
    description = "Shows system and Reaper CPU usage. Click to open performance meter.",
    
    -- Cache for CPU values
    cached_system_cpu = 0,
    cached_reaper_cpu = 0,
    last_update = 0,
    
    getValue = function(self)
        local current_time = reaper.time_precise()
        local interval = self.update_interval or 2.0

        -- Throttle expensive shell calls
        if current_time - self.last_update < interval then
            return self.cached_system_cpu
        end

        self.last_update = current_time

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
                    self.cached_system_cpu = tonumber(sys_cpu) or self.cached_system_cpu
                end
                if reaper_cpu then
                    self.cached_reaper_cpu = tonumber(reaper_cpu) or self.cached_reaper_cpu
                end
            end
        end

        return self.cached_system_cpu
    end,
    
    onClick = function()
        -- Launch performance meter (action 40240)
        reaper.Main_OnCommand(40240, 0)
    end,
    
    renderCustom = function(ctx, self, rel_x, rel_y, render_width, coords, draw_list, text_color)
        local height = CONFIG.SIZES.HEIGHT
        
        -- Format as "DAW / SYS %"
        local cpu_text = string.format("%.1f / %.1f %%", self.cached_reaper_cpu, self.cached_system_cpu)
        local text_width = reaper.ImGui_CalcTextSize(ctx, cpu_text)
        local text_x = rel_x + (render_width - text_width) / 2
        local text_y = rel_y + (height - reaper.ImGui_GetTextLineHeight(ctx)) / 2 + 7
        
        local text_draw_x, text_draw_y = coords:relativeToDrawList(text_x, text_y)
        reaper.ImGui_DrawList_AddText(draw_list, text_draw_x, text_draw_y, text_color, cpu_text)
        
        -- Draw label at the top center
        if self.label and self.label ~= "" then
            local label_color = COLOR_UTILS.toImGuiColor(CONFIG.COLORS.GROUP.LABEL)
            local label_width = reaper.ImGui_CalcTextSize(ctx, self.label)
            local label_x = rel_x + (render_width - label_width) / 2
            local label_y = rel_y + 1
            
            local label_draw_x, label_draw_y = coords:relativeToDrawList(label_x, label_y)
            reaper.ImGui_DrawList_AddText(draw_list, label_draw_x, label_draw_y, label_color, self.label)
        end
    end
}

return widget
