-- toolbar_controller.lua
-- Handles the application logic and state for the toolbar system

local GeneralUtils = require("general_utils")

local ToolbarController = {}
ToolbarController.__index = ToolbarController

function ToolbarController.new(reaper, modules)
    local self = setmetatable({}, ToolbarController)
    self.r = reaper

    -- Store module references
    self.state = modules.state
    self.config = modules.config
    self.presets = modules.presets
    self.dropdown_renderer = modules.dropdown_renderer
    self.color_editor = modules.global_color_editor
    self.fontIconSelector = modules.font_icon_selector
    self.button_renderer = modules.button_renderer

    -- Initialize state
    self.currentToolbarIndex = tonumber(self.r.GetExtState("AdvancedToolbars", "last_toolbar_index")) or 1
    self.button_editing_mode = false
    self.is_open = true
    self.last_dock_state = nil
    self.toolbars = nil
    self.menu_path = nil
    self.global_config = nil
    self.ctx = nil -- Store ImGui context

    -- UI state
    self.clicked_button = nil
    self.active_group = nil
    self.dropdown_editor_open = false
    self.dropdown_editor_button = nil
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

function ToolbarController:initialize(toolbars, menu_path, global_config)
    self.toolbars = toolbars
    self.menu_path = menu_path
    self.global_config = global_config

    -- Make sure button renderer has access to necessary components
    if self.button_renderer then
        self.button_renderer.state = self.state
        self.button_renderer.icon_font_selector = self.fontIconSelector
        self.button_renderer.preset_renderer = self.preset_renderer
    end

    -- Register all buttons with the state manager
    for _, toolbar in ipairs(self.toolbars) do
        for _, button in ipairs(toolbar.buttons) do
            self.state:registerButton(button)
        end
    end

    -- Configure callbacks for font icon selector
    if self.fontIconSelector then
        self.fontIconSelector.saveConfigCallback = function()
            self:saveConfig()
        end
        self.fontIconSelector.focusArrangeCallback = function()
            self:focusArrangeWindow(true)
        end
    end

    return self
end

function ToolbarController:getCurrentToolbar()
    return self.toolbars[self.currentToolbarIndex]
end

function ToolbarController:setCurrentToolbarIndex(index)
    if index >= 1 and index <= #self.toolbars then
        self.currentToolbarIndex = index
        self.config:saveToolbarIndex(index)
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

function ToolbarController:showToolbarRenameDialog()
    local current_toolbar = self:getCurrentToolbar()
    if not current_toolbar then
        return false
    end

    local current_name = current_toolbar.custom_name or current_toolbar.name
    local retval, new_name = self.r.GetUserInputs("Rename Toolbar", 1, "New Name:,extrawidth=100", current_name)

    if retval then
        current_toolbar:updateName(new_name)
        self:saveConfig()
        return true
    end

    return false
end

function ToolbarController:resetToolbarName()
    local current_toolbar = self:getCurrentToolbar()
    if not current_toolbar then
        return false
    end

    if current_toolbar.custom_name then
        current_toolbar.custom_name = nil
        current_toolbar:updateName(nil)
        self:saveConfig()
        return true
    end

    return false
end

function ToolbarController:saveConfig()
    return self.config:saveConfig(self:getCurrentToolbar(), self.toolbars, self.global_config)
end

function ToolbarController:saveDockState(dock_id)
    self.last_dock_state = dock_id
    self.config:saveDockState(dock_id)
end

function ToolbarController:showContextMenu(button, group)
    self.clicked_button = button
    self.active_group = group
    return button
end

function ToolbarController:handleButtonAction(button, is_right_click)
    -- Don't trigger normal actions for slider presets on left click
    if button.preset and button.preset.type == "slider" and not is_right_click then
        return false
    end

    -- For right-click, check dropdown behavior
    if is_right_click and button.right_click == "dropdown" then
        local position = {x = self.r.ImGui_GetMousePosX(self.ctx), y = self.r.ImGui_GetMousePosY(self.ctx)}
        self.dropdown_renderer:show(button, position)
        return true
    end

    -- Otherwise handle normal button action
    return self.state:handleButtonClick(button, is_right_click)
end

function ToolbarController:openDropdownEditor(button)
    self.dropdown_editor_open = true
    self.dropdown_editor_button = button
    return true
end

function ToolbarController:showColorEditor(show)
    if self.color_editor then
        self.color_editor.is_open = show
        return true
    end
    return false
end

function ToolbarController:showIconSelector(button)
    if self.fontIconSelector then
        self.fontIconSelector:show(button)
        return true
    end
    return false
end

function ToolbarController:preloadIconFonts()
    -- Ensure we have a fontIconSelector
    if not self.fontIconSelector then
        return false
    end

    -- Get current toolbar
    local currentToolbar = self:getCurrentToolbar()
    if not currentToolbar then
        return false
    end

    -- Collect all unique icon fonts used by buttons
    local requiredFonts = {}

    -- Check all buttons in all groups
    for _, group in ipairs(currentToolbar.groups) do
        for _, button in ipairs(group.buttons) do
            if button.icon_font and not requiredFonts[button.icon_font] then
                requiredFonts[button.icon_font] = true

                -- Find the font index based on the path
                for i, font_map in ipairs(self.fontIconSelector.font_maps) do
                    if font_map.path == button.icon_font then
                        -- Schedule this font for loading if not already in cache
                        local font_path = SCRIPT_PATH .. font_map.path
                        if not self.fontIconSelector.font_cache[font_path] then
                            if not GeneralUtils.tableContains(self.fontIconSelector.fonts_to_load, i) then
                                table.insert(self.fontIconSelector.fonts_to_load, i)
                            end
                        end
                        break
                    end
                end
            end
        end
    end

    return true
end

function ToolbarController:updateButtonStates()
    -- Update all button states via the state manager
    self.state:updateAllButtonStates()
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

function ToolbarController:updateButtonCaches()
    -- Check if caches need to be cleared due to config changes
    if not self:needCacheUpdate() then
        return false
    end

    local currentToolbar = self:getCurrentToolbar()
    if not currentToolbar then
        return false
    end

    -- Clear button caches
    for _, button in ipairs(currentToolbar.buttons) do
        button.cached_width = nil
        button.screen_coords = nil
    end

    -- Clear group caches
    for _, group in ipairs(currentToolbar.groups) do
        group:clearCache()
    end

    return true
end

function ToolbarController:focusArrangeWindow(force_delay)
    -- Ignore if certain UI elements are active
    if
        not self.ctx or self.color_editor.is_open or self.fontIconSelector.is_open or self.dropdown_editor_open or
            self.r.ImGui_IsPopupOpen(
                self.ctx,
                "context_menu_" .. (self.clicked_button and self.clicked_button.id or "")
            ) or
            self.r.ImGui_IsPopupOpen(self.ctx, "toolbar_selector_menu")
     then
        return false
    end

    local function delayedFocus()
        local cmd_id = self.r.NamedCommandLookup("_BR_FOCUS_ARRANGE_WND")
        if cmd_id and cmd_id ~= 0 then
            self.r.Main_OnCommand(cmd_id, 0)
        else
            self.r.SetCursorContext(1)
            if cmd_id and cmd_id ~= 0 then
                self.r.Main_OnCommand(cmd_id, 0)
            end
        end
    end

    if force_delay then
        self.r.defer(
            function()
                self.r.defer(delayedFocus)
            end
        )
    else
        delayedFocus()
    end

    return true
end

function ToolbarController:cleanup()
    if self.state then
        self.state:cleanup()
    end
    if self.color_editor then
        self.color_editor.is_open = false
    end
    if self.fontIconSelector then
        self.fontIconSelector:cleanup()
    end
    if self.dropdown_renderer then
        self.dropdown_renderer = nil
    end
    if self.config then
        self.config:cleanup()
    end
    if self.presets then
        self.presets:cleanup()
    end
end

function ToolbarController:isOpen()
    return self.is_open
end

function ToolbarController:setOpen(is_open)
    self.is_open = is_open
end

return {
    new = function(reaper, managers)
        return ToolbarController.new(reaper, managers)
    end
}
