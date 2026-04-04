-- Widgets/Under Development/region_list.lua
local widget = {
    name = "Region List",
    macro_group = "Under Development",
    update_interval = 1.0,
    type = "dropdown",
    width = 125,
    placeholder = "Select region...",
    description = "Quick jump to project regions with time display",
    selected_text = "Select region...",

    dropdown_menu = {},

    scanRegions = function(self)
        local regions = {}
        local proj = 0

        local i = 0
        while true do
            local retval, isrgn, pos, rgnend, name = reaper.EnumProjectMarkers3(proj, i)
            if retval == 0 then
                break
            end
            if isrgn then
                if not name or name == "" then
                    name = "Unnamed Region"
                end

                local minutes = math.floor(pos / 60)
                local seconds = math.floor(pos % 60)
                local time_str = string.format("%d:%02d", minutes, seconds)

                local display_name = time_str .. " - " .. name

                table.insert(regions, {
                    name = display_name,
                    action_id = "",
                    region_pos = pos,
                    region_end = rgnend,
                    region_name = name
                })
            end
            i = i + 1
        end

        table.sort(regions, function(a, b) return a.region_pos < b.region_pos end)

        self.dropdown_menu = regions
    end,

    getValue = function(self)
        UTILS.throttleScan(self, "last_scan_time", function(w)
            w:scanRegions()
        end)

        local region_count = #self.dropdown_menu
        return region_count
    end,

    onSelect = function(self, selected_item)
        if not selected_item then return end

        if selected_item.region_pos then
            reaper.SetEditCurPos(selected_item.region_pos, false, false)

            local region_length = selected_item.region_end - selected_item.region_pos
            if region_length > 0 then
                reaper.GetSet_LoopTimeRange(true, false, selected_item.region_pos, selected_item.region_end, false)
                reaper.Main_OnCommand(40730, 0)
            end

            reaper.UpdateArrange()
        end

        self.selected_text = selected_item.name or self.placeholder
    end
}

return widget
