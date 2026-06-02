local ToolbarLoader = {}
ToolbarLoader.__index = ToolbarLoader

function ToolbarLoader.new(ToolbarController)
    local self = setmetatable({}, ToolbarLoader)

    self.toolbar_controller = ToolbarController

    return self
end

function ToolbarLoader:attachSharedToolbars(toolbars, menu_path)
    if not toolbars or #toolbars == 0 then
        return false
    end

    local controller = self.toolbar_controller
    local current_index = controller.currentToolbarIndex
    local toolbar_id_str = tostring(controller.toolbar_id)
    local saved_index = nil

    if CONFIG.TOOLBAR_CONTROLLERS[toolbar_id_str] and CONFIG.TOOLBAR_CONTROLLERS[toolbar_id_str].last_toolbar_index then
        saved_index = tonumber(CONFIG.TOOLBAR_CONTROLLERS[toolbar_id_str].last_toolbar_index)
    end

    controller.toolbars = toolbars
    controller:initialize(toolbars, menu_path)
    controller:ensureToolbarSwitchWidget()

    if saved_index and saved_index >= 1 and saved_index <= #toolbars then
        controller.currentToolbarIndex = saved_index
    elseif current_index and current_index >= 1 and current_index <= #toolbars then
        controller.currentToolbarIndex = current_index
    else
        controller.currentToolbarIndex = 1
    end

    self:clearCaches()

    return true
end

function ToolbarLoader:loadToolbars()
    self.toolbar_controller:unregisterAllButtons()

    local toolbars, menu_path = C.SharedToolbars:ensureLoaded()
    if not toolbars or #toolbars == 0 then
        reaper.ShowMessageBox("No toolbars found in toolbar configs", "Error", 0)
        return false
    end

    if not self:attachSharedToolbars(toolbars, menu_path) then
        reaper.ShowMessageBox("Failed to initialize toolbar configs structure", "Error", 0)
        return false
    end

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
