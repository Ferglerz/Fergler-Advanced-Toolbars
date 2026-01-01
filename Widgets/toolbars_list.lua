-- widgets/toolbars_list.lua
local widget = {
    name = "Toolbars List",
    update_interval = 2.0,
    type = "dropdown",
    width = 200,
    placeholder = "Select Toolbar...",
    label = "Toolbars",
    description = "Switch between different toolbar configurations",
    selected_text = "Toolbars",
    
    dropdown_menu = {},
    current_toolbar = nil,
    
    scanToolbars = function(self)
        local toolbars_path = UTILS.joinPath(SCRIPT_PATH, "User", "toolbar_configs")
        local toolbars = {}
        
        if not reaper.file_exists(toolbars_path) then
            self.dropdown_menu = toolbars
            return
        end
        
        local files = UTILS.getFilesInDirectory(toolbars_path)
        
        for _, file in ipairs(files) do
            if file:match("%.lua$") then
                local toolbar_name = file:gsub("%.lua$", "")
                local full_path = UTILS.joinPath(toolbars_path, file)
                
                table.insert(toolbars, {
                    name = toolbar_name,
                    action_id = "",
                    toolbar_path = full_path
                })
            end
        end
        
        -- Sort toolbars alphabetically
        table.sort(toolbars, function(a, b) return a.name < b.name end)
        
        self.dropdown_menu = toolbars
    end,
    
    getValue = function(self)
        -- Scan toolbars periodically
        if not self.last_scan_time or (reaper.time_precise() - self.last_scan_time) > self.update_interval then
            self:scanToolbars()
            self.last_scan_time = reaper.time_precise()
        end
        
        -- Try to determine current toolbar name
        if not self.current_toolbar then
            -- This is a simplified approach - in a real implementation you might
            -- want to track the current toolbar more precisely
            self.current_toolbar = "Current Toolbar"
        end
        
        return self.current_toolbar
    end,
    
    onSelect = function(self, selected_item)
        if not selected_item then return end
        
        if selected_item.toolbar_path and reaper.file_exists(selected_item.toolbar_path) then
            -- Load the selected toolbar configuration
            -- Note: This would require integration with the toolbar loading system
            -- For now, we'll just update the display
            self.current_toolbar = selected_item.name
            self.selected_text = selected_item.name
            
            -- In a full implementation, you would call something like:
            -- C.ToolbarLoader:loadToolbar(selected_item.toolbar_path)
            
            reaper.ShowConsoleMsg("Loading toolbar: " .. selected_item.name .. "\n")
        end
        
        -- Reset display text back to default after a delay
        -- self.selected_text = "Toolbars"
    end
}

return widget
