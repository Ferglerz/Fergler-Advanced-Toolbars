-- window_manager.lua
local SettingsWindow = require "settings_window"
local ColorEditor = require "color_editor"
local ToolbarSettings = require "toolbar_settings"
local FontIconSelector = require "font_icon_selector"
local ButtonContextMenuManager = require "button_context_menu_manager"
local ColorManager = require "color_manager"
local ConfigManager = require "config_manager"

local WindowManager = {}
WindowManager.__index = WindowManager

function WindowManager.new(reaper, button_system, button_group, helpers)
    local self = setmetatable({}, WindowManager)
    self.r = reaper
    self.ButtonSystem = button_system
    self.ButtonGroup = button_group
    self.helpers = helpers
    self.createPropertyKey = button_system.createPropertyKey

    -- Initialize state
    self.currentToolbarIndex = tonumber(self.r.GetExtState("AdvancedToolbars", "last_toolbar_index")) or 1
    self.is_open = true
    self.button_editing_mode = false
    self.last_dock_state = nil
    self.toolbars = nil
    self.button_manager = nil
    self.button_renderer = nil
    self.last_min_width = CONFIG.SIZES.MIN_WIDTH

    -- Initialize managers
    self.settings_window = SettingsWindow.new(reaper, helpers)
    self.color_editor = ColorEditor.new(reaper, helpers)
    self.toolbar_settings = ToolbarSettings.new(reaper, helpers)
    self.button_context_manager = ButtonContextMenuManager.new(reaper, helpers, self.createPropertyKey)
    self.color_manager = ColorManager.new(reaper, helpers)
    self.config_manager = ConfigManager.new(reaper)

    self.fontIconSelector = FontIconSelector.new(reaper)
    self.fontIconSelector.saveConfigCallback = function()
        self:saveConfig()
    end
    self.fontIconSelector.focusArrangeCallback = function()
        self:focusArrangeWindow()
    end

    self.drag_state = {
        active_separator = nil,
        initial_x = 0,
        initial_width = 0
    }

    return self
end

function WindowManager:initialize(toolbars, button_manager, button_renderer, menu_path, global_config)
    self.toolbars = toolbars
    self.button_manager = button_manager
    self.button_renderer = button_renderer
    self.menu_path = menu_path
    self.global_config = global_config
    self.is_mouse_down = false
    self.was_mouse_down = false
    self.ctx = nil
end

-- Update saveConfig method
function WindowManager:saveConfig()
    self.config_manager:saveConfig(self.toolbars[self.currentToolbarIndex], self.toolbars, self.global_config)
end

function WindowManager:isOpen()
    return self.is_open
end

function WindowManager:handleDockingState(ctx)
    local current_dock = self.r.ImGui_GetWindowDockID(ctx)
    if current_dock == self.last_dock_state then
        return
    end

    self.config_manager:saveDockState(current_dock)
    self.last_dock_state = current_dock
end

function WindowManager:toggleDocking(ctx, current_dock, is_docked)
    if is_docked then
        self.last_dock_state = current_dock
        self.config_manager:saveDockState(0)
        local mouse_x, mouse_y = self.r.ImGui_GetMousePos(ctx)
        self.r.ImGui_SetNextWindowPos(ctx, mouse_x, mouse_y)
    else
        local target_dock = self.last_dock_state
        if not target_dock or target_dock == 0 then
            target_dock = -1
        end
        self.config_manager:saveDockState(target_dock)
    end
end

function WindowManager:renderToolbarSelector(ctx)
    self.r.ImGui_SetNextWindowSizeConstraints(ctx, 500, 0, 800, 2000)
    if not self.r.ImGui_BeginPopup(ctx, "toolbar_selector_menu") then
        return
    end

    -- Render settings window
    self.settings_window:render(
        ctx,
        function()
            self:saveConfig()
        end,
        function(open)
            self.color_editor.is_open = open
        end,
        function(current_dock, is_docked)
            self:toggleDocking(ctx, current_dock, is_docked)
        end,
        function(value, get_only)
            if get_only then
                return self.button_editing_mode
            else
                self.button_editing_mode = value
                return value
            end
        end
    )

    -- Render toolbar settings
    self.toolbar_settings:render(
        ctx,
        self.toolbars,
        self.currentToolbarIndex,
        function(index)
            self.currentToolbarIndex = index
            self.config_manager:saveToolbarIndex(index)
        end,
        function()
            self:saveConfig()
        end
    )

    self.r.ImGui_EndPopup(ctx)
end

function WindowManager:initializeRenderState(ctx)
    self.r.ImGui_Spacing(ctx)
    local window_x, window_y = self.r.ImGui_GetWindowPos(ctx)
    local window_pos = {x = window_x, y = window_y}
    local draw_list = self.r.ImGui_GetWindowDrawList(ctx)
    local start_pos = {
        x = self.r.ImGui_GetCursorPosX(ctx),
        y = self.r.ImGui_GetCursorPosY(ctx)
    }
    return window_pos, draw_list, start_pos
end

function WindowManager:updateButtonWidthCache()
    if self.last_min_width == CONFIG.SIZES.MIN_WIDTH then
        return
    end

    for _, button in ipairs(self.toolbars[self.currentToolbarIndex].buttons) do
        button.cached_width = nil
    end
    self.last_min_width = CONFIG.SIZES.MIN_WIDTH
end

function WindowManager:updateFlashState(ctx)
    local flash_interval = CONFIG.FLASH_INTERVAL or 0.5
    local current_time = self.r.time_precise()
    return math.floor(current_time / (flash_interval / 2)) % 2 == 0
end

function WindowManager:setupButtonCallbacks(ctx, button, group)
    button.on_context_menu = function()
        self.clicked_button = button
        self.active_group = group
        self.r.ImGui_OpenPopup(ctx, "context_menu_" .. button.id)
    end
end

function WindowManager:renderToolbarContent(ctx, icon_font)
    local currentToolbar = self.toolbars[self.currentToolbarIndex]
    if not currentToolbar then
        return false
    end

    local window_pos, draw_list, start_pos = self:initializeRenderState(ctx)
    local current_x = start_pos.x
    local flash_state = self:updateFlashState(ctx)
    self:updateButtonWidthCache()
    local popup_open = false

    if self.drag_state.active_separator then
        if self.r.ImGui_IsMouseDown(ctx, 0) then
            local delta_x = self.r.ImGui_GetMousePos(ctx) - self.drag_state.initial_x
            self.drag_state.active_separator.width = math.max(4, self.drag_state.initial_width + delta_x)
        else
            self:saveConfig()
            self.drag_state.active_separator = nil
        end
    end

    for i, group in ipairs(currentToolbar.groups) do
        if i > 1 then
            current_x = current_x + CONFIG.SIZES.SEPARATOR_WIDTH
        end

        for _, button in ipairs(group.buttons) do
            self.button_manager:updateButtonState(button, self.r.GetArmedCommand(), flash_state)
            self:setupButtonCallbacks(ctx, button, group)
        end

        current_x =
            current_x +
            self.button_renderer:renderGroup(ctx, group, current_x, start_pos.y, window_pos, draw_list, icon_font, self.button_editing_mode)

        -- Handle mouse clicks - modified to open context menu in editing mode
        if self.r.ImGui_IsMouseClicked(ctx, 1) or (self.button_editing_mode and self.r.ImGui_IsMouseClicked(ctx, 0)) then
            for _, button in ipairs(group.buttons) do
                if button.is_hovered then
                    if self.r.ImGui_IsKeyDown(ctx, self.r.ImGui_Mod_Ctrl()) or 
                       (self.button_editing_mode and self.r.ImGui_IsMouseClicked(ctx, 0)) then
                        -- Open context menu if Ctrl key is pressed or if in editing mode with left click
                        self.clicked_button = button
                        self.active_group = group
                        self.r.ImGui_OpenPopup(ctx, "context_menu_" .. button.id)
                    else
                        -- Normal right-click behavior
                        self.button_manager:buttonClicked(button, true)
                    end
                    break
                end
            end
        end

        for _, button in ipairs(group.buttons) do
            local menu_open =
                self.button_context_manager:handleButtonContextMenu(
                ctx,
                button,
                self.active_group,
                self.fontIconSelector,
                self.color_manager,
                self.button_manager,
                self.toolbars[self.currentToolbarIndex],
                self.menu_path,
                function()
                    self:saveConfig()
                end,
                function()
                    self:focusArrangeWindow(true)
                end
            )

            if menu_open then
                popup_open = true
            end
        end
    end

    return popup_open
end

function WindowManager:render(ctx, font, icon_font)
    if not self.toolbars then
        return
    end

    self.ctx = ctx

    self.r.ImGui_PushFont(ctx, font)

    local windowBg = self.helpers.hexToImGuiColor(CONFIG.COLORS.WINDOW_BG)
    self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_WindowBg(), windowBg)
    self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_PopupBg(), windowBg)
    
    self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_SliderGrab(), 0x888888FF)       -- Medium grey
    self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_SliderGrabActive(), 0xAAAAAAFF) -- Lighter grey when active
    self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_FrameBg(), 0x555555FF)  

    self.r.ImGui_SetNextWindowSize(ctx, 800, 60, self.r.ImGui_Cond_FirstUseEver())
    local window_flags =
        self.r.ImGui_WindowFlags_NoScrollbar() | self.r.ImGui_WindowFlags_NoDecoration() |
        self.r.ImGui_WindowFlags_NoScrollWithMouse() |
        self.r.ImGui_WindowFlags_NoFocusOnAppearing()

    local visible, open = self.r.ImGui_Begin(ctx, "Dynamic Toolbar", true, window_flags)

    self.is_open = open

    if visible then
        self:handleDockingState(ctx)

        -- Handle Escape key to close windows
        if self.r.ImGui_IsKeyPressed(ctx, self.r.ImGui_Key_Escape()) then
            if self.color_editor.is_open or self.fontIconSelector.is_open then
                self.color_editor.is_open = false
                self.fontIconSelector.is_open = false
                self:focusArrangeWindow(true) -- Force delay when closing via Escape
            end
        end

        if
            self.r.ImGui_IsWindowHovered(ctx) and not self.r.ImGui_IsAnyItemHovered(ctx) and
                self.r.ImGui_IsMouseClicked(ctx, 1)
         then
            self.r.ImGui_OpenPopup(ctx, "toolbar_selector_menu")
        end

        local popup_open = false

        if #self.toolbars > 0 then
            popup_open = self.r.ImGui_IsPopupOpen(ctx, "toolbar_selector_menu") or popup_open
            self:renderToolbarSelector(ctx)
            self:renderToolbarContent(ctx, icon_font)
        else
            self.r.ImGui_Text(ctx, "No toolbars found in reaper-menu.ini")
        end

        popup_open = self.fontIconSelector:renderGrid(ctx, icon_font) or popup_open

        if self.color_editor.is_open then
            popup_open = true
            self.color_editor:render(
                ctx,
                function()
                    self:saveConfig()
                end,
                function()
                    self:focusArrangeWindow(true)
                end
            )
        end

        -- Track mouse button state
        self.is_mouse_down = self.r.ImGui_IsMouseDown(ctx, 0) or self.r.ImGui_IsMouseDown(ctx, 1)

        -- If mouse was down but is now up, focus the arrange window (unless a popup is open)
        if self.was_mouse_down and not self.is_mouse_down and not popup_open then
            self:focusArrangeWindow(true) -- Always use delay when triggered by mouse release
        end

        self.was_mouse_down = self.is_mouse_down
    end

    self.r.ImGui_End(ctx)
    self.r.ImGui_PopStyleColor(ctx, 5)
    self.r.ImGui_PopFont(ctx)
end

function WindowManager:cleanup()
    if self.button_manager then
        self.button_manager:cleanup()
    end
    if self.color_editor then
        self.color_editor.is_open = false
    end
    if self.fontIconSelector then
        self.fontIconSelector:cleanup()
    end
    if self.color_manager then
        self.color_manager:cleanup()
    end
end

function WindowManager:focusArrangeWindow(force_delay)
    -- Skip focusing if any of our popups or windows are open
    if
        self.color_editor.is_open or self.fontIconSelector.is_open or
            self.r.ImGui_IsPopupOpen(
                self.ctx,
                "context_menu_" .. (self.clicked_button and self.clicked_button.id or "")
            ) or
            self.r.ImGui_IsPopupOpen(self.ctx, "toolbar_selector_menu")
     then
        return
    end

    -- Use a delayed focus to avoid conflicts with other scripts
    local function delayedFocus()
        local cmd_id = self.r.NamedCommandLookup("_BR_FOCUS_ARRANGE_WND")
        if cmd_id and cmd_id ~= 0 then
            self.r.Main_OnCommand(cmd_id, 0)
        else
            -- Try alternate command format
            cmd_id = self.r.NamedCommandLookup("_SWS_FOCUSARRANGE")
            if cmd_id and cmd_id ~= 0 then
                self.r.Main_OnCommand(cmd_id, 0)
            end
        end
    end

    -- Use defer with a delay of 200ms
    if force_delay then
        self.r.defer(
            function()
                self.r.defer(delayedFocus)
            end
        ) -- Two defers = ~200ms delay
    else
        delayedFocus()
    end
end

function WindowManager:handleCtrlRightClick(ctx, button, group)
    if
        self.r.ImGui_IsKeyDown(ctx, self.r.ImGui_Key_LeftCtrl()) or
            self.r.ImGui_IsKeyDown(ctx, self.r.ImGui_Key_RightCtrl())
     then
        self.clicked_button = button
        self.active_group = group
        self.r.ImGui_OpenPopup(ctx, "context_menu_" .. button.id)
        return true
    else
        self.button_manager:buttonClicked(button, true)
    end
    return false
end

return {
    new = function(reaper, button_system, button_group, helpers)
        return WindowManager.new(reaper, button_system, button_group, helpers)
    end
}
