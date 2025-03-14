-- toolbar_window.lua
-- Handles the UI rendering and user interaction for the toolbar system

local ToolbarWindow = {}
ToolbarWindow.__index = ToolbarWindow

function ToolbarWindow.new(reaper, controller, modules)
    local self = setmetatable({}, ToolbarWindow)
    self.r = reaper
    self.controller = controller
    
    -- Import managers for UI rendering
    self.button_renderer = modules.button_renderer
    self.settings_window = modules.settings_window
    self.toolbar_settings = modules.toolbar_settings
    self.button_context_manager = modules.button_context_manager
    self.button_color_editor = modules.button_color_editor
    self.dropdown_renderer = modules.dropdown_renderer
    self.fontIconSelector = modules.font_icon_selector
    self.color_utils = modules.color_utils
    
    -- Set up the preset renderer in button renderer
    if self.button_renderer and modules.preset_renderer then
        self.button_renderer.preset_renderer = modules.preset_renderer
    end
    
    -- Set up the icon font selector in button renderer
    if self.button_renderer then
        self.button_renderer.icon_font_selector = self.fontIconSelector
    end
    
    -- State for UI rendering
    self.ctx = nil
    self.fonts_preloaded = false
    
    return self
end

function ToolbarWindow:render(ctx, font, modules)
    if not self.controller then return end
    
    self.color_utils = modules.color_utils

    self.ctx = ctx
    
    -- Store the context in the controller for functions that need it
    self.controller.ctx = ctx
    
    -- Prepare fonts before rendering
    if self.fontIconSelector then
        -- First call to preload required fonts
        if not self.fonts_preloaded then
            self.controller:preloadIconFonts()
            self.fonts_preloaded = true
        end
        
        -- Then prepare the next frame (loads queued fonts)
        self.fontIconSelector:prepareNextFrame(ctx)
    end
    
    -- Batch style operations at the beginning
    self.r.ImGui_PushFont(ctx, font)
    
    -- Batch color styles in one array for easier management
    local styles = {
        {self.r.ImGui_Col_WindowBg(), self.color_utils.hexToImGuiColor(CONFIG.COLORS.WINDOW_BG)},
        {self.r.ImGui_Col_PopupBg(), self.color_utils.hexToImGuiColor(CONFIG.COLORS.WINDOW_BG)},
        {self.r.ImGui_Col_SliderGrab(), 0x888888FF},
        {self.r.ImGui_Col_SliderGrabActive(), 0xAAAAAAFF},
        {self.r.ImGui_Col_FrameBg(), 0x555555FF}
    }
    
    -- Apply all styles at once
    for _, style in ipairs(styles) do
        self.r.ImGui_PushStyleColor(ctx, style[1], style[2])
    end
    
    self.r.ImGui_SetNextWindowSize(ctx, 800, 60, self.r.ImGui_Cond_FirstUseEver())
    
    local window_flags =
        self.r.ImGui_WindowFlags_NoScrollbar() | 
        self.r.ImGui_WindowFlags_NoDecoration() |
        self.r.ImGui_WindowFlags_NoScrollWithMouse() |
        self.r.ImGui_WindowFlags_NoFocusOnAppearing()
    
    local visible, open = self.r.ImGui_Begin(ctx, "Dynamic Toolbar", true, window_flags)
    self.controller:setOpen(open)
    
    if visible then
        -- Handle docking state changes
        self:handleDockingState(ctx)
        
        -- Handle escape key for closing UI elements
        if self.r.ImGui_IsKeyPressed(ctx, self.r.ImGui_Key_Escape()) then
            self:handleEscapeKey()
        end
        
        -- Handle right-click on empty area to open menu
        if self.r.ImGui_IsWindowHovered(ctx) and 
           not self.r.ImGui_IsAnyItemHovered(ctx) and
           self.r.ImGui_IsMouseClicked(ctx, 1) then
            self.r.ImGui_OpenPopup(ctx, "toolbar_selector_menu")
        end
        
        local popup_open = false
        
        -- Render toolbar content and handle popup windows
        local toolbars = self.controller.toolbars
        if toolbars and #toolbars > 0 then
            popup_open = self.r.ImGui_IsPopupOpen(ctx, "toolbar_selector_menu")
            self:renderToolbarSelector(ctx)
            popup_open = self:renderToolbarContent(ctx) or popup_open
        else
            self.r.ImGui_Text(ctx, "No toolbars found in reaper-menu.ini")
        end
        
        -- Render various popup UI elements
        popup_open = self:renderUIElements(ctx, popup_open)
        
        -- Track mouse state for focusing arrange window when clicking elsewhere
        self:trackMouseState(ctx, popup_open)
    end
    
    self.r.ImGui_End(ctx)
    
    -- Pop all styles at once
    self.r.ImGui_PopStyleColor(ctx, #styles)
    self.r.ImGui_PopFont(ctx)
end

function ToolbarWindow:handleDockingState(ctx)
    local current_dock = self.r.ImGui_GetWindowDockID(ctx)
    local last_dock_state = self.controller.last_dock_state
    
    if current_dock ~= last_dock_state then
        self.controller:saveDockState(current_dock)
    end
end

function ToolbarWindow:handleEscapeKey()
    if self.controller.color_editor.is_open or 
       self.controller.fontIconSelector.is_open or 
       self.controller.dropdown_editor_open then
        
        self.controller.color_editor.is_open = false
        self.controller.fontIconSelector.is_open = false
        self.controller.dropdown_editor_open = false
        self.controller:focusArrangeWindow(true)
    end
end

function ToolbarWindow:renderToolbarSelector(ctx)
    self.r.ImGui_SetNextWindowSizeConstraints(ctx, 500, 0, 800, 2000)
    if not self.r.ImGui_BeginPopup(ctx, "toolbar_selector_menu") then
        return
    end
    
    -- Render settings window
    self.settings_window:render(
        ctx,
        function()
            self.controller:saveConfig()
        end,
        function(open)
            self.controller:showColorEditor(open)
        end,
        function(value, get_only)
            return self.controller:toggleEditingMode(value, get_only)
        end
    )
    
    -- Render toolbar settings
    self.toolbar_settings:render(
        ctx,
        self.controller.toolbars,
        self.controller.currentToolbarIndex,
        function(index)
            self.controller:setCurrentToolbarIndex(index)
        end,
        function()
            self.controller:saveConfig()
        end
    )
    
    self.r.ImGui_EndPopup(ctx)
end

function ToolbarWindow:initializeRenderState(ctx)
    self.r.ImGui_Spacing(ctx)
    local window_x, window_y = self.r.ImGui_GetWindowPos(ctx)
    return {x = window_x, y = window_y}, 
           self.r.ImGui_GetWindowDrawList(ctx), 
           {
               x = self.r.ImGui_GetCursorPosX(ctx),
               y = self.r.ImGui_GetCursorPosY(ctx)
           }
end

function ToolbarWindow:renderToolbarContent(ctx)
    -- Get current toolbar
    local currentToolbar = self.controller:getCurrentToolbar()
    if not currentToolbar then
        return false
    end
    
    local window_pos, draw_list, start_pos = self:initializeRenderState(ctx)
    local current_x = start_pos.x
    local popup_open = false
    
    -- Update button states before rendering
    self.controller:updateButtonStates()
    self.controller:updateButtonCaches()
    
    -- Handle active separators
    self:handleActiveSeparator(ctx)
    
    -- Render each group
    for i, group in ipairs(currentToolbar.groups) do
        if i > 1 then
            current_x = current_x + CONFIG.SIZES.SEPARATOR_WIDTH
        end
        
        -- Set up callbacks for all buttons in the group
        for _, button in ipairs(group.buttons) do
            self:setupButtonCallbacks(ctx, button, group)
        end
        
        -- Render the group
        current_x = current_x + self.button_renderer:renderGroup(
            ctx,
            group,
            current_x,
            start_pos.y,
            window_pos,
            draw_list,
            nil,  -- icon_font
            self.controller.button_editing_mode
        )
        
        -- Handle button click interactions
        if self.r.ImGui_IsMouseClicked(ctx, 1) or 
           (self.controller.button_editing_mode and self.r.ImGui_IsMouseClicked(ctx, 0)) then
            self:handleButtonClicks(ctx, group)
        end
        
        -- Render context menus for each button
        for _, button in ipairs(group.buttons) do
            if self:renderButtonContextMenu(ctx, button, group) then
                popup_open = true
            end
        end
    end
    
    return popup_open
end

function ToolbarWindow:handleButtonClicks(ctx, group)
    for _, button in ipairs(group.buttons) do
        if button.is_hovered then
            if self.r.ImGui_IsKeyDown(ctx, self.r.ImGui_Mod_Ctrl()) or
               (self.controller.button_editing_mode and self.r.ImGui_IsMouseClicked(ctx, 0)) then
                -- Open context menu
                self.controller:showContextMenu(button, group)
                self.r.ImGui_OpenPopup(ctx, "context_menu_" .. button.id)
            else
                -- Normal button action
                self.controller:handleButtonAction(
                    button, 
                    self.r.ImGui_IsMouseClicked(ctx, 1)
                )
            end
            break
        end
    end
end

function ToolbarWindow:renderButtonContextMenu(ctx, button, group)
    -- Create managers object
    local managers = {
        font_icon_selector = self.fontIconSelector,
        button_color_editor = self.button_color_editor,
        state = self.controller.state,
        presets = self.controller.presets
    }
    
    -- Create callbacks object
    local callbacks = {
        saveConfig = function()
            self.controller:saveConfig()
        end,
        focusArrange = function()
            self.controller:focusArrangeWindow(true)
        end
    }
    
    return self.button_context_manager:handleButtonContextMenu(
        ctx,
        button,
        group,
        managers,
        self.controller:getCurrentToolbar(),
        callbacks
    )
end

function ToolbarWindow:handleActiveSeparator(ctx)
    local drag_state = self.controller.drag_state
    
    if drag_state.active_separator then
        if self.r.ImGui_IsMouseDown(ctx, 0) then
            local delta_x = self.r.ImGui_GetMousePosX(ctx) - drag_state.initial_x
            drag_state.active_separator.width = math.max(4, drag_state.initial_width + delta_x)
        else
            self.controller:saveConfig()
            drag_state.active_separator = nil
        end
    end
end

function ToolbarWindow:setupButtonCallbacks(ctx, button, group)
    button.on_context_menu = function()
        self.controller:showContextMenu(button, group)
        self.r.ImGui_OpenPopup(ctx, "context_menu_" .. button.id)
    end
end

function ToolbarWindow:renderUIElements(ctx, popup_open)
    -- Render font icon selector
    if self.fontIconSelector then
        popup_open = self.fontIconSelector:renderGrid(ctx) or popup_open
    end
    
    -- Handle dropdown rendering
    if self.dropdown_renderer then
        popup_open = self.dropdown_renderer:renderDropdown(
            ctx, 
            self.controller.state, 
            function() 
                self.controller:saveConfig() 
            end
        ) or popup_open
    end
    
    -- Handle preset selector
    if self.button_context_manager.preset_selection and 
       self.button_context_manager.preset_selection.is_open then
        popup_open = self.button_context_manager:renderPresetSelector(ctx) or popup_open
    end
    
    -- Handle dropdown editor
    if self.button_context_manager.show_dropdown_editor then
        self.controller.dropdown_editor_open = true
        self.controller.dropdown_editor_button = self.button_context_manager.dropdown_edit_button
        self.button_context_manager.show_dropdown_editor = false
    end
    
    if self.controller.dropdown_editor_open and self.controller.dropdown_editor_button then
        self.controller.dropdown_editor_open =
            self.dropdown_renderer:renderDropdownEditor(
                ctx,
                self.controller.dropdown_editor_button,
                function()
                    self.controller:saveConfig()
                end
            )
        popup_open = popup_open or self.controller.dropdown_editor_open
    end
    
    -- Render color editor
    if self.controller.color_editor.is_open then
        popup_open = true
        self.controller.color_editor:render(
            ctx,
            function()
                self.controller:saveConfig()
            end
        )
    end
    
    return popup_open
end

function ToolbarWindow:trackMouseState(ctx, popup_open)
    -- Track mouse state for auto-focusing arrange window
    local is_mouse_down = self.r.ImGui_IsMouseDown(ctx, 0) or self.r.ImGui_IsMouseDown(ctx, 1)
    
    -- Check if any dropdown is active before auto-focusing arrange window
    local dropdown_active = self.dropdown_renderer and self.dropdown_renderer.is_open
    
    -- Only auto-focus if no popups are open, dropdown is not active, and mouse was released
    if self.controller.was_mouse_down and not is_mouse_down and 
       not popup_open and not dropdown_active then
        self.controller:focusArrangeWindow(true)
    end
    
    -- Store for next frame
    self.controller.was_mouse_down = is_mouse_down
    self.controller.is_mouse_down = is_mouse_down
end

function ToolbarWindow:isOpen()
    return self.controller:isOpen()
end

function ToolbarWindow:cleanup()
    self.controller:cleanup()
end

return {
    new = function(reaper, controller, managers)
        return ToolbarWindow.new(reaper, controller, managers)
    end
}