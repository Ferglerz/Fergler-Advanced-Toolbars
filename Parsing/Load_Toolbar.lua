local ToolbarLoader = {}
ToolbarLoader.__index = ToolbarLoader

function ToolbarLoader.new(ToolbarController)
    local self = setmetatable({}, ToolbarLoader)

    self.toolbar_controller = ToolbarController

    return self
end

function ToolbarLoader:loadToolbars()
    -- Store the current toolbar index to restore it after loading
    local current_index = self.toolbar_controller.currentToolbarIndex
    
    -- Store controller ID for configuration lookup
    local toolbar_id_str = tostring(self.toolbar_controller.toolbar_id)
    local saved_index = nil
    
    -- Get the saved index from configuration if it exists
    if CONFIG.TOOLBAR_CONTROLLERS[toolbar_id_str] and 
       CONFIG.TOOLBAR_CONTROLLERS[toolbar_id_str].last_toolbar_index then
        saved_index = tonumber(CONFIG.TOOLBAR_CONTROLLERS[toolbar_id_str].last_toolbar_index)
    end
    
    -- Load and validate menu.ini
    local menu_content, menu_path = C.ParseToolbars:loadMenuIni()
    if not menu_content then
        reaper.ShowMessageBox("Failed to load reaper-menu.ini", "Error", 0)
        return false
    end
    
    -- Parse toolbars and get state manager
    local toolbars, state = C.ParseToolbars:parseToolbars(menu_content)
    if #toolbars == 0 then
        reaper.ShowMessageBox("No toolbars found in reaper-menu.ini", "Error", 0)
        return false
    end
    
    -- Update the controller with new toolbars and state
    self.toolbar_controller.toolbars = toolbars
    self.toolbar_controller.button_manager = state
    
    -- Re-initialize the controller with the new toolbars
    self.toolbar_controller:initialize(toolbars, menu_path)
    
    if saved_index and saved_index >= 1 and saved_index <= #toolbars then
        self.toolbar_controller.currentToolbarIndex = saved_index
    -- Fall back to the previously active index if valid
    elseif current_index and current_index >= 1 and current_index <= #toolbars then
        self.toolbar_controller.currentToolbarIndex = current_index
    -- Last resort: use the first toolbar
    else
        self.toolbar_controller.currentToolbarIndex = 1
    end
    
    -- Clear any cached data
    self:clearCaches()
    
    return true
end

function ToolbarLoader:clearCaches()
    -- Clear button caches
    local currentToolbar = self.toolbar_controller:getCurrentToolbar()
    if currentToolbar then
        for _, button in ipairs(currentToolbar.buttons) do
            if button.clearCache then
                button:clearCache()
            end
        end

        -- Clear group caches
        for _, group in ipairs(currentToolbar.groups) do
            if group.clearCache then
                group:clearCache()
            end
        end
    end

    -- Reset button state caches
    if self.toolbar_controller.button_manager then
        self.toolbar_controller.button_manager.command_state_cache = {}
    end
end

function ToolbarLoader:checkForFileChanges()
    local menu_path = reaper.GetResourcePath() .. "/reaper-menu.ini"

    -- Get current file size
    local file = io.open(menu_path, "r")
    if not file then
        return false
    end

    -- Get current file size
    local current_size = file:seek("end")
    file:close()

    -- Initialize last known size if not set
    if not self.last_file_size then
        self.last_file_size = current_size
        return false
    end

    -- Check if file size has changed
    if current_size ~= self.last_file_size then
        -- Update stored value
        self.last_file_size = current_size
        return true -- File has changed
    end

    return false -- No changes detected
end

return {
    new = function(...)
        return ToolbarLoader.new(...)
    end
}
