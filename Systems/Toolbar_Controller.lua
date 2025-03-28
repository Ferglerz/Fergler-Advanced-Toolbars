-- Systems/Toolbar_Controller.lua

local ToolbarController = {}
ToolbarController.__index = ToolbarController

function ToolbarController.new(
    Interactions
)
    local self = setmetatable({}, ToolbarController)

    self.interactions = Interactions

    -- Initialize state
    self.currentToolbarIndex = tonumber(reaper.GetExtState("AdvancedToolbars", "last_toolbar_index")) or 1
    self.button_editing_mode = false
    self.is_open = true
    self.last_dock_state = nil
    self.toolbars = nil
    self.menu_path = nil
    self.ctx = nil -- Store ImGui context

    -- UI state
    self.clicked_button = nil
    self.active_group = nil
    self.is_mouse_down = false
    self.was_mouse_down = false

    -- Performance tracking
    self.last_min_width = CONFIG.SIZES.MIN_WIDTH
    self.last_height = CONFIG.SIZES.HEIGHT
    self.last_spacing = CONFIG.SIZES.SPACING

    -- Drag state
    self.drag_state = {
        active_separator = nil,
        initial_x = 0,
        initial_width = 0
    }

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
        self:saveConfig(toolbar)
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
        self:saveConfig(toolbar)
        return true
    end

    return false
end

function ToolbarController:saveConfig(toolbar)
    return CONFIG_MANAGER:saveToolbarConfig(toolbar)
end

function ToolbarController:saveDockState(dock_id)
    self.last_dock_state = dock_id
    CONFIG_MANAGER:saveDockState(dock_id)
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
