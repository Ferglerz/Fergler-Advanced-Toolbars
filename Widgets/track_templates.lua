-- Widgets/track_templates.lua
local widget = {
    name = "Track Templates",
    update_interval = 5.0,
    type = "dropdown",
    width = 200,
    placeholder = "Select Template...",
    label = "Templates",
    description = "Insert track from template",
    selected_text = "Track Templates",
    
    dropdown_menu = {},
    
    scanTemplates = function(self)
        local templates_path = reaper.GetResourcePath() .. "/TrackTemplates"
        local templates = {}
        
        -- Helper function to scan directory recursively
        local function scanDirectory(path, prefix)
            prefix = prefix or ""
            
            if not reaper.file_exists(path) then
                return
            end
            
            local files = UTILS.getFilesInDirectory(path)
            
            for _, file in ipairs(files) do
                local full_path = UTILS.joinPath(path, file)
                
                if file:match("%.RTrackTemplate$") then
                    -- It's a track template file
                    local template_name = file:gsub("%.RTrackTemplate$", "")
                    local display_name = prefix .. template_name
                    
                    table.insert(templates, {
                        name = display_name,
                        action_id = "",
                        template_path = full_path
                    })
                elseif not file:match("%.") and reaper.file_exists(full_path) then
                    -- It's a directory, scan recursively
                    scanDirectory(full_path, prefix .. file .. "/")
                end
            end
        end
        
        -- Check if TrackTemplates directory exists
        if reaper.file_exists(templates_path) then
            scanDirectory(templates_path)
        end
        
        -- Sort templates alphabetically
        table.sort(templates, function(a, b) return a.name < b.name end)
        
        self.dropdown_menu = templates
    end,
    
    getValue = function(self)
        -- Scan templates periodically
        if not self.last_scan_time or (reaper.time_precise() - self.last_scan_time) > self.update_interval then
            self:scanTemplates()
            self.last_scan_time = reaper.time_precise()
        end
        
        local template_count = #self.dropdown_menu
        return "Templates (" .. template_count .. ")"
    end,
    
    onSelect = function(self, selected_item)
        if not selected_item then return end
        
        if selected_item.template_path and reaper.file_exists(selected_item.template_path) then
            -- Use reaper.Main_openProject to load the track template
            reaper.Main_openProject(selected_item.template_path)
        end
        
        -- Reset display text back to default (don't keep template name)
        self.selected_text = "Track Templates"
    end
}

return widget