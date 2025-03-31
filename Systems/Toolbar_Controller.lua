-- Systems/Toolbar_Controller.lua

local ToolbarController = {}
ToolbarController.__index = ToolbarController

function ToolbarController.new(Interactions)
    local self = setmetatable({}, ToolbarController)

    self.interactions = Interactions

    -- Initialize state
    self.currentToolbarIndex = tonumber(reaper.GetExtState("AdvancedToolbars", "last_toolbar_index")) or 1
    self.button_editing_mode = false
    self.is_open = true
    
    -- Docking state
    self.current_dock_id = nil
    self.target_dock_id = nil
    self.last_dock_id = nil
    self.dock_pending = false

    self.toolbars = nil
    self.menu_path = nil
    self.ctx = nil -- Store ImGui context

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

function ToolbarController:showDropdownEditor(button)
    if C.ButtonDropdownEditor then
        C.ButtonDropdownEditor.is_open = true
        C.ButtonDropdownEditor.current_button = button
        return true
    end
    return false
end

function ToolbarController:initialize(toolbars, menu_path)
    self.toolbars = toolbars
    self.menu_path = menu_path

    -- Load saved dock state if available
    if CONFIG_MANAGER and CONFIG_MANAGER.loadDockState then
        local saved_dock = CONFIG_MANAGER:loadDockState()
        if saved_dock and saved_dock ~= 0 then
            self.target_dock_id = saved_dock
            self.dock_pending = true
        end
    end
    
    -- Register all buttons with the state manager
    for _, toolbar in ipairs(self.toolbars) do
        for _, button in ipairs(toolbar.buttons) do
            C.ButtonManager:registerButton(button)
        end
    end

    return self
end

function ToolbarController:trackMouseState(ctx, popup_open)
    -- Track mouse state for auto-focusing arrange window
    local is_mouse_down = reaper.ImGui_IsMouseDown(ctx, 0) or reaper.ImGui_IsMouseDown(ctx, 1)
    local dropdown_active = C.ButtonDropdownMenu and C.ButtonDropdownMenu.is_open

    if self.was_mouse_down and not is_mouse_down and not popup_open and not dropdown_active then
        UTILS.focusArrangeWindow(true)
    end

    -- Store for next frame
    self.was_mouse_down = is_mouse_down
    self.is_mouse_down = is_mouse_down
end

function ToolbarController:getCurrentToolbar()
    return self.toolbars[self.currentToolbarIndex]
end

function ToolbarController:setCurrentToolbarIndex(index)
    if index >= 1 and index <= #self.toolbars then
        self.currentToolbarIndex = index
        CONFIG_MANAGER:saveToolbarIndex(index)
        return true
    end
    return false
end

function ToolbarController:toggleEditingMode(value, get_only)
    if get_only then
        return self.button_editing_mode
    end

    if value ~= nil then
        self.button_editing_mode = value
    else
        self.button_editing_mode = not self.button_editing_mode
    end

    return self.button_editing_mode
end

function ToolbarController:showToolbarRenameDialog(toolbar)
    if not toolbar then
        return false
    end

    local current_name = toolbar.custom_name or toolbar.name
    local retval, new_name = reaper.GetUserInputs("Rename Toolbar", 1, "New Name:,extrawidth=100", current_name)

    if retval then
        toolbar:updateName(new_name)
        self:saveToolbarConfig(toolbar)
        return true
    end

    return false
end

function ToolbarController:resetToolbarName(toolbar)
    if not toolbar then
        return false
    end

    if toolbar.custom_name then
        toolbar.custom_name = nil
        toolbar:updateName(nil)
        self:saveMainConfig()
        return true
    end

    return false
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

function ToolbarController:preloadIconFonts(toolbar)
    -- Ensure we have a iconSelector
    if not C.IconSelector or not toolbar then
        return false
    end

    -- Collect all unique icon fonts used by buttons
    local requiredFonts = {}

    -- Check all buttons in all groups
    for _, group in ipairs(toolbar.groups) do
        for _, button in ipairs(group.buttons) do
            if button.icon_font and not requiredFonts[button.icon_font] then
                requiredFonts[button.icon_font] = true

                -- Find the font index based on the path
                for i, font_map in ipairs(C.IconSelector.font_maps) do
                    if font_map.path == button.icon_font then
                        -- Schedule this font for loading if not already in cache
                        local font_path = SCRIPT_PATH .. font_map.path
                        if
                            not C.IconSelector.font_cache[font_path] and
                                not UTILS.tableContains(C.IconSelector.fonts_to_load, i)
                         then
                            table.insert(C.IconSelector.fonts_to_load, i)
                        end
                        break
                    end
                end
            end
        end
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
    if not dock_id then return false end
    
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
    
    -- Save for persistence
    if CONFIG_MANAGER and CONFIG_MANAGER.saveDockState then
        CONFIG_MANAGER:saveDockState(self.target_dock_id)
    end
    
    return true
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

function ToolbarController:updateDockState(ctx)
    -- Get the current dock ID after the window has been rendered
    local new_dock_id = reaper.ImGui_GetWindowDockID(ctx)
    
    -- Only update if we have a valid dock ID that changed
    if new_dock_id ~= nil and new_dock_id ~= self.current_dock_id then
        self.current_dock_id = new_dock_id
        
        -- Save the change if it's a user-initiated dock change
        if not self.dock_pending and CONFIG_MANAGER and CONFIG_MANAGER.saveDockState then
            CONFIG_MANAGER:saveDockState(new_dock_id)
        end
    end
end

function ToolbarController:isOpen()
    return self.is_open
end

function ToolbarController:setOpen(is_open)
    self.is_open = is_open
end

return {
    new = function(...)
        return ToolbarController.new(...)
    end
}
