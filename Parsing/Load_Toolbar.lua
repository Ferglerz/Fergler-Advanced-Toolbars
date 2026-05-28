local ToolbarLoader = {}
ToolbarLoader.__index = ToolbarLoader

function ToolbarLoader.new(ToolbarController)
    local self = setmetatable({}, ToolbarLoader)

    self.toolbar_controller = ToolbarController

    return self
end

function ToolbarLoader:loadToolbars()
    -- Drop previous toolbar rows from global ButtonManager before parse re-registers (S1)
    self.toolbar_controller:unregisterAllButtons()

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
    
    local ini_content = C.IniManager:loadContent(true)
    local menu_content = CONFIG_MANAGER:buildRuntimeIniContentFromToolbarConfigs(ini_content)
    local menu_path = UTILS.joinPath(SCRIPT_PATH, "User/toolbar_configs")
    if not menu_content then
        reaper.ShowMessageBox("Failed to initialize toolbar configs structure", "Error", 0)
        return false
    end
    
    local toolbars = C.ParseToolbars:parseToolbars(menu_content)
    if #toolbars == 0 then
        reaper.ShowMessageBox("No toolbars found in toolbar configs", "Error", 0)
        return false
    end

    local sanitized_disk = false
    for _, toolbar in ipairs(toolbars) do
        if CONFIG_MANAGER:persistToolbarConfigSanitize(toolbar) then
            sanitized_disk = true
        end
    end
    if sanitized_disk then
        menu_content = CONFIG_MANAGER:buildRuntimeIniContentFromToolbarConfigs(ini_content)
        toolbars = C.ParseToolbars:parseToolbars(menu_content)
        if #toolbars == 0 then
            reaper.ShowMessageBox("No toolbars found in toolbar configs", "Error", 0)
            return false
        end
    end

    self.toolbar_controller.toolbars = toolbars

    -- Re-initialize the controller with the new toolbars
    self.toolbar_controller:initialize(toolbars, menu_path)

    self.toolbar_controller:ensureToolbarSwitchWidget()
    
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

    if C.LayoutManager then
        C.LayoutManager:requestLayoutRecalcAfterToolbarReady()
    end

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

    if C.ButtonManager then
        C.ButtonManager.command_state_cache = {}
    end
end

return {
    new = function(...)
        return ToolbarLoader.new(...)
    end
}