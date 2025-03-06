-- window_manager.lua
local SettingsWindow = require "settings_window"
local ToolbarSettings = require "toolbar_settings"
local FontIconSelector = require "font_icon_selector"
local ButtonContextMenuManager = require "button_context_menu_manager"
local ColorUtils = require "color_utils"
local GlobalColorEditor = require "global_color_editor"
local ButtonColorEditor = require "button_color_editor"
local ConfigManager = require "config_manager"
local DropdownRenderer = require "dropdown_renderer"

local WindowManager = {}
WindowManager.__index = WindowManager

function WindowManager:preloadIconFonts(ctx)
    -- Ensure we have a fontIconSelector
    if not self.fontIconSelector then
        return
    end

    -- Get current toolbar
    local currentToolbar = self.toolbars[self.currentToolbarIndex]
    if not currentToolbar then
        return
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
                            if not table.contains(self.fontIconSelector.fonts_to_load, i) then
                                table.insert(self.fontIconSelector.fonts_to_load, i)
                            end
                        end
                        break
                    end
                end
            end
        end
    end
end

function WindowManager.new(reaper, ButtonSystem, ButtonGroup, helpers)
    local self = setmetatable({}, WindowManager)
    self.r = reaper
    self.ButtonSystem = ButtonSystem
    self.ButtonGroup = ButtonGroup
    self.helpers = helpers
    self.ColorUtils = ColorUtils
    self.createPropertyKey = ButtonSystem.createPropertyKey

    -- Initialize state
    self.currentToolbarIndex = tonumber(self.r.GetExtState("AdvancedToolbars", "last_toolbar_index")) or 1
    self.is_open = true
    self.button_editing_mode = false
    self.last_dock_state = nil
    self.toolbars = nil
    self.button_state = nil
    self.button_renderer = nil
    self.last_min_width = CONFIG.SIZES.MIN_WIDTH

    -- Initialize managers
    self.settings_window = SettingsWindow.new(reaper, helpers)
    self.color_editor = GlobalColorEditor.new(reaper, helpers)
    self.toolbar_settings = ToolbarSettings.new(reaper, helpers)
    self.button_context_manager = ButtonContextMenuManager.new(reaper, helpers, self.createPropertyKey)
    self.button_color_editor = ButtonColorEditor.new(reaper, helpers)
    self.config_manager = ConfigManager.new(reaper)
    self.dropdown_renderer = DropdownRenderer.new(reaper, helpers)
    self.dropdown_editor_open = false
    self.dropdown_editor_button = nil

    self.fontIconSelector = FontIconSelector.new(reaper, helpers)
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

function WindowManager:initialize(toolbars, button_state, button_renderer, menu_path, global_config)
    self.toolbars = toolbars
    self.button_state = button_state
    self.button_renderer = button_renderer
    self.menu_path = menu_path
    self.global_config = global_config
    self.is_mouse_down = false
    self.was_mouse_down = false
    self.ctx = nil

    -- Ensure fontIconSelector is available to button_renderer
    self.button_renderer.icon_font_selector = self.fontIconSelector

    -- Initialize button manager if needed
    if not self.button_state then
        self.button_state = self.ButtonSystem.ButtonState.new(reaper)
    end
end

function WindowManager:saveConfig()
    self.config_manager:saveConfig(self.toolbars[self.currentToolbarIndex], self.toolbars, self.global_config)
end

function WindowManager:isOpen()
    return self.is_open
end

function WindowManager:handleDockingState(ctx)
    local current_dock = self.r.ImGui_GetWindowDockID(ctx)
    if current_dock ~= self.last_dock_state then
        self.config_manager:saveDockState(current_dock)
        self.last_dock_state = current_dock
    end
end

function WindowManager:toggleDocking(ctx, current_dock, is_docked)
    if is_docked then
        self.last_dock_state = current_dock
        self.config_manager:saveDockState(0)
        local mouse_x, mouse_y = self.r.ImGui_GetMousePos(ctx)
        self.r.ImGui_SetNextWindowPos(ctx, mouse_x, mouse_y)
    else
        local target_dock = self.last_dock_state ~= 0 and self.last_dock_state or -1
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
            end
            self.button_editing_mode = value
            return value
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
    return {x = window_x, y = window_y}, self.r.ImGui_GetWindowDrawList(ctx), {
        x = self.r.ImGui_GetCursorPosX(ctx),
        y = self.r.ImGui_GetCursorPosY(ctx)
    }
end

function WindowManager:updateButtonWidthCache()
    if self.last_min_width ~= CONFIG.SIZES.MIN_WIDTH then
        for _, button in ipairs(self.toolbars[self.currentToolbarIndex].buttons) do
            button.cached_width = nil
        end
        self.last_min_width = CONFIG.SIZES.MIN_WIDTH
    end
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
    local popup_open = false

    -- Update button states before rendering
    self.button_state:updateArmedCommand()
    self:updateButtonWidthCache()

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
            self.button_state:updateButtonState(button)
            self:setupButtonCallbacks(ctx, button, group)
        end

        current_x =
            current_x +
            self.button_renderer:renderGroup(
                ctx,
                group,
                current_x,
                start_pos.y,
                window_pos,
                draw_list,
                icon_font,
                self.button_editing_mode,
                self.fontIconSelector
            )

        if self.r.ImGui_IsMouseClicked(ctx, 1) or (self.button_editing_mode and self.r.ImGui_IsMouseClicked(ctx, 0)) then
            for _, button in ipairs(group.buttons) do
                if button.is_hovered then
                    if
                        self.r.ImGui_IsKeyDown(ctx, self.r.ImGui_Mod_Ctrl()) or
                            (self.button_editing_mode and self.r.ImGui_IsMouseClicked(ctx, 0))
                     then
                        self.clicked_button = button
                        self.active_group = group
                        self.r.ImGui_OpenPopup(ctx, "context_menu_" .. button.id)
                    else
                        -- Check for dropdown behavior
                        if button.right_click == "dropdown" and self.r.ImGui_IsMouseClicked(ctx, 1) then
                            local mouse_x, mouse_y = self.r.ImGui_GetMousePos(ctx)
                            self.dropdown_renderer:show(button, {x = mouse_x, y = mouse_y})
                        else
                            self.button_state:buttonClicked(button, true)
                        end
                    end
                    break
                end
            end
        end

        for _, button in ipairs(group.buttons) do
            if
                self.button_context_manager:handleButtonContextMenu(
                    ctx,
                    button,
                    self.active_group,
                    self.fontIconSelector,
                    self.button_color_editor,
                    self.button_state,
                    self.toolbars[self.currentToolbarIndex],
                    self.menu_path,
                    function()
                        self:saveConfig()
                    end,
                    function()
                        self:focusArrangeWindow(true)
                    end
                )
             then
                popup_open = true
            end
        end
    end

    return popup_open
end

function WindowManager:render(ctx, font)
    if not self.toolbars then
        return
    end

    self.ctx = ctx

    -- Prepare fonts before rendering
    if self.fontIconSelector then
        -- First call to preload required fonts
        if not self.fonts_preloaded then
            self:preloadIconFonts(ctx)
            self.fonts_preloaded = true
        end

        -- Then prepare the next frame (loads queued fonts)
        self.fontIconSelector:prepareNextFrame(ctx)
    end

    self.r.ImGui_PushFont(ctx, font)

    local windowBg = self.ColorUtils.hexToImGuiColor(CONFIG.COLORS.WINDOW_BG)
    self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_WindowBg(), windowBg)
    self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_PopupBg(), windowBg)

    self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_SliderGrab(), 0x888888FF) -- Medium grey
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

        if
            self.r.ImGui_IsKeyPressed(ctx, self.r.ImGui_Key_Escape()) and
                (self.color_editor.is_open or self.fontIconSelector.is_open or self.dropdown_editor_open)
         then
            self.color_editor.is_open = false
            self.fontIconSelector.is_open = false
            self.dropdown_editor_open = false
            self:focusArrangeWindow(true)
        end

        if
            self.r.ImGui_IsWindowHovered(ctx) and not self.r.ImGui_IsAnyItemHovered(ctx) and
                self.r.ImGui_IsMouseClicked(ctx, 1)
         then
            self.r.ImGui_OpenPopup(ctx, "toolbar_selector_menu")
        end

        local popup_open = false

        if #self.toolbars > 0 then
            popup_open = self.r.ImGui_IsPopupOpen(ctx, "toolbar_selector_menu")
            self:renderToolbarSelector(ctx)
            popup_open = self:renderToolbarContent(ctx) or popup_open
        else
            self.r.ImGui_Text(ctx, "No toolbars found in reaper-menu.ini")
        end

        popup_open = self.fontIconSelector:renderGrid(ctx) or popup_open

        -- Handle dropdown rendering
        popup_open = self.dropdown_renderer:renderDropdown(ctx) or popup_open

        -- Handle dropdown editor
        if self.button_context_manager.show_dropdown_editor then
            self.dropdown_editor_open = true
            self.dropdown_editor_button = self.button_context_manager.dropdown_edit_button
            self.button_context_manager.show_dropdown_editor = false
        end

        if self.dropdown_editor_open and self.dropdown_editor_button then
            self.dropdown_editor_open =
                self.dropdown_renderer:renderDropdownEditor(
                ctx,
                self.dropdown_editor_button,
                function()
                    self:saveConfig()
                end
            )
            popup_open = popup_open or self.dropdown_editor_open
        end

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

        self.is_mouse_down = self.r.ImGui_IsMouseDown(ctx, 0) or self.r.ImGui_IsMouseDown(ctx, 1)

        -- Check if any dropdown is active before auto-focusing arrange window
        local dropdown_active = self.dropdown_renderer and self.dropdown_renderer.is_open
        
        -- Only auto-focus if no popups are open and dropdown is not active
        if self.was_mouse_down and not self.is_mouse_down and not popup_open and not dropdown_active then
            self:focusArrangeWindow(true)
        end

        self.was_mouse_down = self.is_mouse_down
    end

    self.r.ImGui_End(ctx)
    self.r.ImGui_PopStyleColor(ctx, 5)
    self.r.ImGui_PopFont(ctx)
end

function WindowManager:cleanup()
    if self.button_state then
        self.button_state:cleanup()
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
    if self.config_manager then
        self.config_manager:cleanup()
    end
end

function WindowManager:focusArrangeWindow(force_delay)
    local allow_this_function = true
    if allow_this_function then
        if
            self.color_editor.is_open or self.fontIconSelector.is_open or self.dropdown_editor_open or
                self.r.ImGui_IsPopupOpen(
                    self.ctx,
                    "context_menu_" .. (self.clicked_button and self.clicked_button.id or "")
                ) or
                self.r.ImGui_IsPopupOpen(self.ctx, "toolbar_selector_menu")
         then
            return
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
    end

    -- Check for dropdown behavior
    if button.right_click == "dropdown" then
        local mouse_x, mouse_y = self.r.ImGui_GetMousePos(ctx)
        self.dropdown_renderer:show(button, {x = mouse_x, y = mouse_y})
        return true
    end

    self.button_state:buttonClicked(button, true)
    return false
end

return {
    new = function(reaper, button_system, button_group, helpers)
        return WindowManager.new(reaper, button_system, button_group, helpers)
    end
}
