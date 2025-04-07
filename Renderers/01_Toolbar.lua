-- Renderers/01_Toolbars.lua

-- Handles the UI rendering and user interaction for the toolbar system

local ToolbarWindow = {}
ToolbarWindow.__index = ToolbarWindow

function ToolbarWindow.new(ToolbarController)
    local self = setmetatable({}, ToolbarWindow)

    self.toolbar_controller = ToolbarController

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
    self.toolbar_controller.ctx = ctx
    self.toolbar_controller:applyDockState(ctx)

    reaper.ImGui_PushFont(ctx, font)

    local styles = {
        {reaper.ImGui_Col_WindowBg(), COLOR_UTILS.hexToImGuiColor(CONFIG.COLORS.WINDOW_BG)},
        {reaper.ImGui_Col_PopupBg(), COLOR_UTILS.hexToImGuiColor(CONFIG.COLORS.WINDOW_BG)},
        {reaper.ImGui_Col_SliderGrab(), 0x888888FF},
        {reaper.ImGui_Col_SliderGrabActive(), 0xAAAAAAFF},
        {reaper.ImGui_Col_FrameBg(), 0x555555FF}
    }

    for _, style in ipairs(styles) do
        reaper.ImGui_PushStyleColor(ctx, style[1], style[2])
    end

    reaper.ImGui_SetNextWindowSize(ctx, 800, 60, reaper.ImGui_Cond_FirstUseEver())
    reaper.ImGui_SetNextWindowSizeConstraints(ctx, 800, 60, 10000, CONFIG.SIZES.HEIGHT + 40)

    local window_flags =
        reaper.ImGui_WindowFlags_NoScrollbar() | reaper.ImGui_WindowFlags_NoTitleBar() |
        reaper.ImGui_WindowFlags_NoScrollbar() |
        reaper.ImGui_WindowFlags_NoCollapse() |
        reaper.ImGui_WindowFlags_NoFocusOnAppearing()

    local visible, open = reaper.ImGui_Begin(ctx, "Dynamic Toolbar", true, window_flags)
    self.toolbar_controller.is_open = open

    if visible then
        if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) then
            if _G.POPUP_OPEN then
                -- Close all popups
                if C.GlobalColorEditor then C.GlobalColorEditor.is_open = false end
                if C.IconSelector then C.IconSelector.is_open = false end
                if C.ButtonDropdownEditor then C.ButtonDropdownEditor.is_open = false end
                if C.ButtonDropdownMenu then C.ButtonDropdownMenu.is_open = false end
                
                _G.POPUP_OPEN = false
                UTILS.focusArrangeWindow(true)
            end
        end

        if
            reaper.ImGui_IsWindowHovered(ctx) and not reaper.ImGui_IsAnyItemHovered(ctx) and
                reaper.ImGui_IsMouseClicked(ctx, 1)
         then
            reaper.ImGui_OpenPopup(ctx, "toolbar_settings_menu")
        end

        local popup_open = false
        local toolbars = self.toolbar_controller.toolbars

        if toolbars and #toolbars > 0 then
            popup_open = reaper.ImGui_IsPopupOpen(ctx, "toolbar_settings_menu")
            self:renderToolbarSettings(ctx)
            popup_open = self:renderToolbarContent(ctx) or popup_open
        else
            reaper.ImGui_Text(ctx, "No toolbars found in reaper-menu.ini")
        end

        popup_open = self:renderUIElements(ctx, popup_open)

        local is_mouse_down = reaper.ImGui_IsMouseDown(ctx, 0) or reaper.ImGui_IsMouseDown(ctx, 1)
        local dropdown_active = C.ButtonDropdownMenu.is_open

        if self.was_mouse_down and not is_mouse_down and not popup_open then
            UTILS.focusArrangeWindow(true)
        end

        self.was_mouse_down = is_mouse_down
        self.is_mouse_down = is_mouse_down
    end

    reaper.ImGui_End(ctx)
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
            C.Interactions:showGlobalColorEditor(open)
        end,
        function(value, get_only)
            return self.toolbar_controller:toggleEditingMode(value, get_only)
        end,
        self.toolbar_controller.toolbars,
        self.toolbar_controller.currentToolbarIndex,
        function(index)
            self.toolbar_controller:setCurrentToolbarIndex(index)
        end,
        self.toolbar_controller
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

    -- Find the split point group and calculate right-aligned widths
    local split_group = nil
    local split_group_index = 0
    for i, group in ipairs(currentToolbar.groups) do
        if group.is_split_point then
            split_group = group
            split_group_index = i
            break
        end
    end

    -- Calculate total width of right-aligned groups if we have a split
    local right_aligned_width = 0

    if split_group then
        -- Calculate the width of all groups from the split point to the end
        for i = split_group_index, #currentToolbar.groups do
            local group = currentToolbar.groups[i]
            local dims = group:getDimensions()
            if dims then
                right_aligned_width = right_aligned_width + dims.width

                -- Add spacing between groups
                if i < #currentToolbar.groups then
                    right_aligned_width = right_aligned_width + CONFIG.SIZES.SEPARATOR_WIDTH
                end
            end
        end

        -- Add padding for better appearance
        right_aligned_width = right_aligned_width + CONFIG.SIZES.SEPARATOR_WIDTH
    end

    -- Calculate where the split group would be positioned without the split
    local normal_x = start_pos.x
    for i = 1, split_group_index - 1 do
        local group = currentToolbar.groups[i]
        local dims = group:getDimensions()
        if dims then
            normal_x = normal_x + dims.width + CONFIG.SIZES.SEPARATOR_WIDTH
        end
    end

    -- Check if window is wide enough for the split
    local window_width = reaper.ImGui_GetWindowWidth(ctx)
    local split_x = window_width - right_aligned_width -- Where the right side would start

    -- Simple overlap check: Is the right side's starting position to the right of where
    -- the split group would naturally be positioned?
    local should_split = split_group and (split_x > normal_x)

    -- Reset for actual rendering
    local rendering_right_side = false

    -- Render each group
    for i, group in ipairs(currentToolbar.groups) do
        -- Check if we're at the split point
        if should_split and group == split_group then
            rendering_right_side = true

            -- Reposition to start the right-aligned section
            current_x = window_width - right_aligned_width
        else
            if i > 1 then
                current_x = current_x + CONFIG.SIZES.SEPARATOR_WIDTH
            end
        end

        -- Render the group
        current_x =
            current_x +
            C.GroupRenderer:renderGroup(
                ctx,
                group,
                current_x,
                start_pos.y,
                window_pos,
                draw_list,
                self.toolbar_controller.button_editing_mode
            )

        -- Render context menus for each button
        for _, button in ipairs(group.buttons) do
            if C.ButtonSettingsMenu:handleButtonSettingsMenu(ctx, button, group) then
                popup_open = true
            end
        end
    end

    self.toolbar_controller:updateDockState(ctx)

    return popup_open
end

function ToolbarWindow:renderUIElements(ctx, popup_open)

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
            C.ButtonDropdownEditor:renderDropdownEditor(ctx, C.ButtonDropdownEditor.current_button) or popup_open
    end

    if C.GlobalColorEditor and C.GlobalColorEditor.is_open then
        popup_open = true
        C.GlobalColorEditor:render(
            ctx,
            function()
                CONFIG_MANAGER:saveMainConfig()
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
