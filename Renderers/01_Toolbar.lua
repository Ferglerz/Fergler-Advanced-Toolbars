-- Renderers/01_Toolbars.lua

-- Handles the UI rendering and user interaction for the toolbar system

local ToolbarWindow = {}
ToolbarWindow.__index = ToolbarWindow

function ToolbarWindow.new(Interactions, ToolbarController, GroupRenderer)
    local self = setmetatable({}, ToolbarWindow)

    self.interactions = Interactions
    self.toolbar_controller = ToolbarController
    self.group_renderer = GroupRenderer

    -- State for UI rendering
    self.ctx = nil
    self.fonts_preloaded = false

    return self
end

function ToolbarWindow:render(ctx, font)
    if not self.toolbar_controller then
        return
    end

    self.ctx = ctx

    -- Store the context in the controller for functions that need it
    self.toolbar_controller.ctx = ctx
    self.toolbar_controller:applyDockState(ctx)

    -- Force reset of cached dimensions after any config change
    local currentToolbar = self.toolbar_controller:getCurrentToolbar()
    if currentToolbar then
        -- This ensures visual updates are applied when CONFIG changes
        self.toolbar_controller:updateButtonCaches(currentToolbar)
    end

    -- Prepare fonts before rendering
    if C.IconSelector then
        -- First call to preload required fonts
        if not self.fonts_preloaded then
            self.toolbar_controller:preloadIconFonts()
            self.fonts_preloaded = true
        end

        -- Then prepare the next frame (loads queued fonts)
        C.IconSelector:prepareNextFrame(ctx)
    end

    -- Batch style operations at the beginning
    reaper.ImGui_PushFont(ctx, font)

    -- Batch color styles in one array for easier management
    local styles = {
        {reaper.ImGui_Col_WindowBg(), COLOR_UTILS.hexToImGuiColor(CONFIG.COLORS.WINDOW_BG)},
        {reaper.ImGui_Col_PopupBg(), COLOR_UTILS.hexToImGuiColor(CONFIG.COLORS.WINDOW_BG)},
        {reaper.ImGui_Col_SliderGrab(), 0x888888FF},
        {reaper.ImGui_Col_SliderGrabActive(), 0xAAAAAAFF},
        {reaper.ImGui_Col_FrameBg(), 0x555555FF}
    }

    -- Apply all styles at once
    for _, style in ipairs(styles) do
        reaper.ImGui_PushStyleColor(ctx, style[1], style[2])
    end

    reaper.ImGui_SetNextWindowSize(ctx, 800, 60, reaper.ImGui_Cond_FirstUseEver())

    local window_flags =
        reaper.ImGui_WindowFlags_NoScrollbar() | reaper.ImGui_WindowFlags_NoDecoration() |
        reaper.ImGui_WindowFlags_NoScrollWithMouse() |
        reaper.ImGui_WindowFlags_NoFocusOnAppearing()

    local visible, open = reaper.ImGui_Begin(ctx, "Dynamic Toolbar", true, window_flags)
    self.toolbar_controller.is_open = open

    if visible then
        if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) then
            if
                C.GlobalColorEditor.is_open or C.IconSelector.is_open or
                    (C.ButtonDropdownEditor and C.ButtonDropdownEditor.is_open)
             then
                C.GlobalColorEditor.is_open = false
                C.IconSelector.is_open = false
                if C.ButtonDropdownEditor then
                    C.ButtonDropdownEditor.is_open = false
                end
                UTILS.focusArrangeWindow(true)
            end
        end

        -- Handle right-click on empty area to open menu
        if
            reaper.ImGui_IsWindowHovered(ctx) and not reaper.ImGui_IsAnyItemHovered(ctx) and
                reaper.ImGui_IsMouseClicked(ctx, 1)
         then
            reaper.ImGui_OpenPopup(ctx, "toolbar_settings_menu")
        end

        local popup_open = false

        -- Render toolbar content and handle popup windows
        local toolbars = self.toolbar_controller.toolbars
        if toolbars and #toolbars > 0 then
            popup_open = reaper.ImGui_IsPopupOpen(ctx, "toolbar_settings_menu")
            self:renderToolbarSettings(ctx)
            popup_open = self:renderToolbarContent(ctx) or popup_open
        else
            reaper.ImGui_Text(ctx, "No toolbars found in reaper-menu.ini")
        end

        -- Render various popup UI elements
        popup_open = self:renderUIElements(ctx, popup_open)

        -- Track mouse state for focusing arrange window when clicking elsewhere
        self.toolbar_controller:trackMouseState(ctx, popup_open)
    end

    reaper.ImGui_End(ctx)

    -- Pop all styles at once
    reaper.ImGui_PopStyleColor(ctx, #styles)
    reaper.ImGui_PopFont(ctx)
end

function ToolbarWindow:renderToolbarSettings(ctx)
    reaper.ImGui_SetNextWindowSizeConstraints(ctx, 500, 0, 500, 1000)
    if not reaper.ImGui_BeginPopup(ctx, "toolbar_settings_menu") then
        return
    end

    -- Render settings window
    C.GlobalSettingsMenu:render(
        ctx,
        function()
            local current_toolbar = self.toolbar_controller:getCurrentToolbar()
            CONFIG_MANAGER:saveMainConfig()

            -- Force cache invalidation for all buttons after config save
            if current_toolbar then
                for _, group in ipairs(current_toolbar.groups) do
                    group:clearCache()
                    for _, button in ipairs(group.buttons) do
                        button:clearCache()
                    end
                end
                -- Reset tracking variables to force needCacheUpdate to return true
                self.toolbar_controller.last_min_width = nil
                self.toolbar_controller.last_height = nil
                self.toolbar_controller.last_spacing = nil
            end
        end,
        function(open)
            self.interactions:showGlobalColorEditor(open)
        end,
        function(value, get_only)
            return self.toolbar_controller:toggleEditingMode(value, get_only)
        end,
        self.toolbar_controller.toolbars,
        self.toolbar_controller.currentToolbarIndex,
        function(index)
            self.toolbar_controller:setCurrentToolbarIndex(index)
        end,
        CONFIG_MANAGER
    )

    reaper.ImGui_EndPopup(ctx)
end

function ToolbarWindow:initializeRenderState(ctx)
    reaper.ImGui_Spacing(ctx)
    local window_x, window_y = reaper.ImGui_GetWindowPos(ctx)
    return {x = window_x, y = window_y}, reaper.ImGui_GetWindowDrawList(ctx), {
        x = reaper.ImGui_GetCursorPosX(ctx),
        y = reaper.ImGui_GetCursorPosY(ctx)
    }
end

function ToolbarWindow:renderToolbarContent(ctx)
    -- Get current toolbar
    local currentToolbar = self.toolbar_controller:getCurrentToolbar()
    if not currentToolbar then
        return false
    end

    local window_pos, draw_list, start_pos = self:initializeRenderState(ctx)
    local current_x = start_pos.x
    local popup_open = false

    -- Force cache update check for any config changes
    self.toolbar_controller:updateButtonCaches(currentToolbar)

    -- Update button states before rendering
    self.toolbar_controller:updateButtonStates()

    -- Render each group
    for i, group in ipairs(currentToolbar.groups) do
        if i > 1 then
            current_x = current_x + CONFIG.SIZES.SEPARATOR_WIDTH
        end

        -- Render the group
        current_x =
            current_x +
            self.group_renderer:renderGroup(
                ctx,
                group,
                current_x,
                start_pos.y,
                window_pos,
                draw_list,
                nil, -- icon_font
                self.toolbar_controller.button_editing_mode
            )

        -- Render context menus for each button
        for _, button in ipairs(group.buttons) do
            if C.ButtonSettingsMenu:handleButtonSettingsMenu(ctx, button, group) then
                popup_open = true
            end
        end
    end

    return popup_open
end

function ToolbarWindow:renderUIElements(ctx, popup_open)
    local current_toolbar = self.toolbar_controller:getCurrentToolbar()

    if C.IconSelector and C.IconSelector.is_open then
        popup_open = C.IconSelector:renderGrid(ctx) or popup_open
    end

    if C.ButtonDropdownMenu and C.ButtonDropdownMenu.is_open then
        popup_open = C.ButtonDropdownMenu:renderDropdown(ctx) or popup_open
    end

    if C.ButtonSettingsMenu.widget_selection and C.ButtonSettingsMenu.widget_selection.is_open then
        popup_open = C.ButtonSettingsMenu:renderWidgetSelector(ctx) or popup_open
    end

    if C.ButtonSettingsMenu.dropdown_edit_button then
        self.toolbar_controller:showDropdownEditor(C.ButtonSettingsMenu.dropdown_edit_button)
        C.ButtonSettingsMenu.dropdown_edit_button = nil
    end

    if C.ButtonDropdownEditor and C.ButtonDropdownEditor.is_open then
        popup_open =
            C.ButtonDropdownEditor:renderDropdownEditor(
            ctx,
            C.ButtonDropdownEditor.current_button,
            function()
                CONFIG_MANAGER:saveToolbarConfig(current_toolbar)
            end
        ) or popup_open
    end

    if C.GlobalColorEditor and C.GlobalColorEditor.is_open then
        popup_open = true
        C.GlobalColorEditor:render(
            ctx,
            function()
                CONFIG_MANAGER.saveMainConfig()
            end
        )
    end

    return popup_open
end

return {
    new = function(...)
        return ToolbarWindow.new(...)
    end
}
