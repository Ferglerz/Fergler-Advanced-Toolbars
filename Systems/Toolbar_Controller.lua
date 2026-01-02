-- Systems/Toolbar_Controller.lua

local ToolbarController = {}
ToolbarController.__index = ToolbarController

function ToolbarController.new(toolbar_id)
    local self = setmetatable({}, ToolbarController)

    self.currentToolbarIndex = nil
    self.button_editing_mode = false
    self.is_open = true
    self.backup_created = false

    -- Use provided ID or generate a new one
    self.toolbar_id = toolbar_id or ID_GENERATOR.generateToolbarId()

    -- Docking state
    self.current_dock_id = nil
    self.target_dock_id = nil
    self.last_dock_id = nil
    self.dock_pending = false

    self.toolbars = nil
    self.menu_path = nil
    self.ctx = nil 

    -- UI state
    self.clicked_button = nil
    self.active_group = nil
    self.is_mouse_down = false
    self.was_mouse_down = false

    self.last_min_width = CONFIG.SIZES.MIN_WIDTH
    self.last_height = CONFIG.SIZES.HEIGHT
    self.last_spacing = CONFIG.SIZES.SPACING

    return self
end

function ToolbarController:initialize(toolbars, menu_path)
    self.toolbars = toolbars
    self.menu_path = menu_path

    -- Ensure this toolbar has an entry (using tostring to handle numeric IDs)
    local toolbar_id_str = tostring(self.toolbar_id)
    
    -- Load settings for this toolbar controller
    if type(CONFIG.TOOLBAR_CONTROLLERS[toolbar_id_str]) == "table" then
        local controller_settings = CONFIG.TOOLBAR_CONTROLLERS[toolbar_id_str]
        
        -- Apply saved dock state
        if controller_settings.dock_id and controller_settings.dock_id ~= 0 then
            self.target_dock_id = controller_settings.dock_id
            self.dock_pending = true
        end
        
        -- Load saved toolbar index if available
        if controller_settings.toolbar_index and 
           tonumber(controller_settings.toolbar_index) >= 1 and 
           tonumber(controller_settings.toolbar_index) <= #toolbars then
            self.currentToolbarIndex = tonumber(controller_settings.toolbar_index)
        end
    else
        -- Create new entry in TOOLBAR_CONTROLLERS for this controller
        CONFIG.TOOLBAR_CONTROLLERS[toolbar_id_str] = {
            dock_id = 0, -- Default to undocked
            last_toolbar_index = self.currentToolbarIndex or 1
        }
        CONFIG_MANAGER:saveMainConfig()
    end
    
    -- Register buttons
    for _, toolbar in ipairs(self.toolbars) do
        for _, button in ipairs(toolbar.buttons) do
            C.ButtonManager:registerButton(button)
        end
    end

    return self
end

function ToolbarController:showDropdownEditor(button)
    if C.ButtonDropdownEditor then
        C.ButtonDropdownEditor.is_open = true
        C.ButtonDropdownEditor.current_button = button
        return true
    end
    return false
end

function ToolbarController:getCurrentToolbar()
    return self.toolbars[self.currentToolbarIndex]
end

function ToolbarController:setCurrentToolbarIndex(index)
    if index >= 1 and index <= #self.toolbars then
        self.currentToolbarIndex = index
        
        -- Save to controller-specific settings
        local toolbar_id_str = tostring(self.toolbar_id)
        if CONFIG.TOOLBAR_CONTROLLERS[toolbar_id_str] then
            CONFIG.TOOLBAR_CONTROLLERS[toolbar_id_str].last_toolbar_index = index
            CONFIG_MANAGER:saveMainConfig()
        end
        
        return true
    end
    return false
end

function ToolbarController:toggleEditingMode(value, get_only)
    if get_only then
        return self.button_editing_mode
    end

    local new_value
    if value ~= nil then
        new_value = value
    else
        new_value = not self.button_editing_mode
    end

    -- Create backup when entering edit mode
    if new_value and not self.button_editing_mode and not self.backup_created then
        local success, backup_path = C.DragDropManager:createIniBackup()
        if success then
            self.backup_created = true
            --("INI backup created: " .. backup_path .. "\n")
        else
            reaper.ShowMessageBox("Failed to create INI backup: " .. backup_path, "Warning", 0)
        end
    end

    -- Reset backup flag when exiting edit mode
    if not new_value and self.button_editing_mode then
        self.backup_created = false
    end

    self.button_editing_mode = new_value
    
    -- Sync edit mode across all toolbar controllers to enable cross-toolbar drag and drop
    if _G.TOOLBAR_CONTROLLERS then
        for _, controller_data in ipairs(_G.TOOLBAR_CONTROLLERS) do
            if controller_data.controller and controller_data.controller ~= self then
                controller_data.controller.button_editing_mode = new_value
            end
        end
    end
    
    return self.button_editing_mode
end

function ToolbarController:updateButtonStates()
    -- Update all button states via the state manager
    C.ButtonManager:updateAllButtonStates()
end

function ToolbarController:needCacheUpdate()
    local need_update = false

    -- Check for MIN_WIDTH changes
    if self.last_min_width ~= CONFIG.SIZES.MIN_WIDTH then
        need_update = true
        self.last_min_width = CONFIG.SIZES.MIN_WIDTH
    end

    -- Check for HEIGHT changes
    if self.last_height ~= CONFIG.SIZES.HEIGHT then
        need_update = true
        self.last_height = CONFIG.SIZES.HEIGHT
    end

    -- Check for SPACING changes
    if self.last_spacing ~= CONFIG.SIZES.SPACING then
        need_update = true
        self.last_spacing = CONFIG.SIZES.SPACING
    end

    return need_update
end

function ToolbarController:updateButtonCaches(toolbar)
    -- Check if caches need to be cleared due to config changes
    if not self:needCacheUpdate() or not toolbar then
        return false
    end

    -- Clear button caches
    for _, button in ipairs(toolbar.buttons) do
        button.cached_width = nil
        button.screen_coords = nil
    end

    -- Clear group caches
    for _, group in ipairs(toolbar.groups) do
        group:clearCache()
    end

    return true
end

function ToolbarController:cleanup()
    if C.ButtonManager then
        C.ButtonManager:cleanup()
    end

    -- Close all open windows
    if C.GlobalColorEditor then
        C.GlobalColorEditor.is_open = false
    end
    if C.ButtonDropdownEditor then
        C.ButtonDropdownEditor.is_open = false
    end
    if C.IconSelector then
        C.IconSelector.is_open = false
        C.IconSelector:cleanup()
    end
    if C.ButtonDropdownMenu then
        C.ButtonDropdownMenu.is_open = false
    end
    if C.ButtonSettingsMenu then
        C.ButtonSettingsMenu.is_open = false
    end
    if C.GlobalSettingsMenu then
        C.GlobalSettingsMenu.is_open = false
    end

    CONFIG_MANAGER:cleanup()

    if WIDGETS then
        C.WidgetsManager:cleanup()
    end
end

function ToolbarController:setDockState(dock_id)
    if not dock_id then
        return false
    end

    -- Store the dock ID (positive for ImGui docks, negative for REAPER dockers)
    if type(dock_id) == "number" and dock_id > 0 and dock_id <= 16 then
        -- Convert REAPER docker numbers (1-16) to negative IDs
        self.target_dock_id = -dock_id
    else
        -- Store as-is for ImGui docks or already-formatted REAPER dockers
        self.target_dock_id = dock_id
    end

    -- Mark that we need to apply the dock change
    self.dock_pending = true

    -- Save for persistence in controller-specific settings
    if CONFIG.TOOLBAR_CONTROLLERS[self.toolbar_id] then
        CONFIG.TOOLBAR_CONTROLLERS[self.toolbar_id].dock_id = self.target_dock_id
        CONFIG_MANAGER:saveMainConfig()
    end

    return true
end

function ToolbarController:updateDockState(ctx)
    -- Get the current dock ID after the window has been rendered
    local new_dock_id = reaper.ImGui_GetWindowDockID(ctx)

    -- Only update if we have a valid dock ID that changed
    if new_dock_id ~= nil and new_dock_id ~= self.current_dock_id then
        self.current_dock_id = new_dock_id

        -- Save the change if it's a user-initiated dock change
        if not self.dock_pending and CONFIG.TOOLBAR_CONTROLLERS[self.toolbar_id] then
            CONFIG.TOOLBAR_CONTROLLERS[self.toolbar_id].dock_id = new_dock_id
            CONFIG_MANAGER:saveMainConfig()
        end
    end
end

function ToolbarController:toggleDocking()
    -- If currently docked, undock
    if self.current_dock_id and self.current_dock_id ~= 0 then
        -- Remember the current dock before undocking
        self.last_dock_id = self.current_dock_id
        self:setDockState(0) -- 0 = undocked
    else
        -- If undocked, dock to last known docker or default
        local dock_target = self.last_dock_id or -1 -- Default to REAPER docker 1
        self:setDockState(dock_target)
    end

    return true
end

function ToolbarController:applyDockState(ctx)
    if self.dock_pending and self.target_dock_id ~= nil then
        -- Apply the dock state at the appropriate time in the ImGui frame
        reaper.ImGui_SetNextWindowDockID(ctx, self.target_dock_id)
        self.dock_pending = false
        return true
    end
    return false
end

function ToolbarController:isOpen()
    return self.is_open
end

function ToolbarController:setOpen(is_open)
    self.is_open = is_open
end

return ToolbarController.new(...)