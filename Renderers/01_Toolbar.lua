-- Renderers/01_Toolbars.lua

local ToolbarWindow = {}
ToolbarWindow.__index = ToolbarWindow

function ToolbarWindow.new(ToolbarController)
    local self = setmetatable({}, ToolbarWindow)
    self.toolbar_controller = ToolbarController
    self.fonts_preloaded = false
    return self
end

function ToolbarWindow:render(ctx, font)
    if not self.toolbar_controller then
        return
    end

    self.toolbar_controller.ctx = ctx
    self.toolbar_controller:applyDockState(ctx)

    reaper.ImGui_PushFont(ctx, font)

    local styles = {
        {reaper.ImGui_Col_WindowBg(), COLOR_UTILS.toImGuiColor(CONFIG.COLORS.WINDOW_BG)},
        {reaper.ImGui_Col_PopupBg(), COLOR_UTILS.toImGuiColor(CONFIG.COLORS.WINDOW_BG)},
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
                if C.GlobalColorEditor then C.GlobalColorEditor.is_open = false end
                if C.IconSelector then C.IconSelector.is_open = false end
                if C.ButtonDropdownEditor then C.ButtonDropdownEditor.is_open = false end
                if C.ButtonDropdownMenu then C.ButtonDropdownMenu.is_open = false end
                
                _G.POPUP_OPEN = false
                UTILS.focusArrangeWindow(true)
            elseif self.toolbar_controller.button_editing_mode then
                self.toolbar_controller:toggleEditingMode(false)
                UTILS.focusArrangeWindow(true)
            end
        end

        if reaper.ImGui_IsWindowHovered(ctx) and not reaper.ImGui_IsAnyItemHovered(ctx) and reaper.ImGui_IsMouseClicked(ctx, 1) then
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

    C.GlobalSettingsMenu:render(
        ctx,
        function()
            local current_toolbar = self.toolbar_controller:getCurrentToolbar()
            CONFIG_MANAGER:saveMainConfig()

            if current_toolbar then
                for _, group in ipairs(current_toolbar.groups) do
                    group:clearCache()
                    for _, button in ipairs(group.buttons) do
                        button:clearCache()
                    end
                end
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

function ToolbarWindow:calculateVerticalCenter(ctx, layout)
    local window_height = reaper.ImGui_GetWindowHeight(ctx)
    local content_height = layout.height
    local center_y = (window_height - content_height) / 2
    local min_padding = 8
    return math.max(center_y, min_padding)
end

function ToolbarWindow:handleToolbarDragDrop(ctx, toolbar, editing_mode, coords, draw_list, centered_y)
    if not editing_mode or not C.DragDropManager:isDragging() then
        return
    end
    
    local button_rects = {}
    
    C.LayoutManager:setContext(ctx)
    local layout = C.LayoutManager:getToolbarLayout(self.toolbar_controller.toolbar_id, toolbar)
    
    local window_width = reaper.ImGui_GetWindowWidth(ctx)
    local should_split = layout.split_point and (window_width - layout.right_width > layout.groups[layout.split_point].x)
    
    for i, group_layout in ipairs(layout.groups) do
        local group = toolbar.groups[i]
        local group_x = group_layout.x
        
        if should_split and i >= layout.split_point then
            group_x = window_width - layout.right_width + (group_x - layout.groups[layout.split_point].x)
        end
        
        for j, button_layout in ipairs(group_layout.buttons) do
            local button = group.buttons[j]
            if not button.is_separator then
                local button_rel_x = group_x + button_layout.x
                local button_rel_y = centered_y
                
                button_rects[button.instance_id] = {
                    rel_x = button_rel_x,
                    rel_y = button_rel_y,
                    width = button_layout.width,
                    height = button_layout.height,
                    button = button
                }
            end
        end
    end
    
    -- Get mouse position in screen coordinates and convert to relative with scroll
    local mouse_screen_x, mouse_screen_y = reaper.ImGui_GetMousePos(ctx)
    local window_x, window_y = reaper.ImGui_GetWindowPos(ctx)
    local scroll_x = reaper.ImGui_GetScrollX(ctx)
    local scroll_y = reaper.ImGui_GetScrollY(ctx)
    
    -- Convert screen mouse to relative coordinates accounting for scroll
    local mouse_rel_x = mouse_screen_x - window_x + scroll_x
    local mouse_rel_y = mouse_screen_y - window_y + scroll_y
    
    C.DragDropManager.current_drop_target = nil
    
    for instance_id, rect in pairs(button_rects) do
        if C.DragDropManager:getDragSource() and C.DragDropManager:getDragSource().instance_id == instance_id then
            -- Skip source button
        else
            if mouse_rel_x >= rect.rel_x and mouse_rel_x <= rect.rel_x + rect.width and
               mouse_rel_y >= rect.rel_y and mouse_rel_y <= rect.rel_y + rect.height then
                local button_center_x = rect.rel_x + rect.width / 2
                C.DragDropManager.current_drop_target = rect.button
                C.DragDropManager.drop_position = mouse_rel_x > button_center_x and "after" or "before"
                break
            end
        end
    end
    
    if C.DragDropManager.current_drop_target then
        local target_rect = button_rects[C.DragDropManager.current_drop_target.instance_id]
        if target_rect then
            self:renderDropIndicator(ctx, draw_list, target_rect, coords)
        end
    end
    
    if reaper.ImGui_IsMouseReleased(ctx, 0) then
        if C.DragDropManager.current_drop_target then
            C.DragDropManager:performDrop(C.DragDropManager.current_drop_target, C.DragDropManager.drag_payload)
        end
        C.DragDropManager:endDrag()
    end
end

function ToolbarWindow:renderDropIndicator(ctx, draw_list, target_rect, coords)
    local drop_after = C.DragDropManager.drop_position == "after"
    local indicator_rel_x = drop_after and target_rect.rel_x + target_rect.width or target_rect.rel_x
    local y1_rel = target_rect.rel_y - 5
    local y2_rel = target_rect.rel_y + target_rect.height + 5
    
    local indicator_x, _ = coords:relativeToDrawList(indicator_rel_x, 0)
    local _, y1 = coords:relativeToDrawList(0, y1_rel)
    local _, y2 = coords:relativeToDrawList(0, y2_rel)
    
    local indicator_color = 0x00FF00FF
    local line_thickness = 4.0
    
    reaper.ImGui_DrawList_AddLine(draw_list, indicator_x, y1, indicator_x, y2, indicator_color, line_thickness)
    
    local cap_width = 10
    reaper.ImGui_DrawList_AddLine(draw_list, indicator_x - cap_width/2, y1, indicator_x + cap_width/2, y1, indicator_color, line_thickness)
    reaper.ImGui_DrawList_AddLine(draw_list, indicator_x - cap_width/2, y2, indicator_x + cap_width/2, y2, indicator_color, line_thickness)
end

function ToolbarWindow:renderToolbarContent(ctx)
    local currentToolbar = self.toolbar_controller:getCurrentToolbar()
    if not currentToolbar then
        return false
    end

    -- Create coordinate system once per frame
    local coords = COORDINATES.new(ctx)
    local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
    local popup_open = false

    self.toolbar_controller:updateButtonStates()

    C.LayoutManager:setContext(ctx)
    local layout = C.LayoutManager:getToolbarLayout(self.toolbar_controller.toolbar_id, currentToolbar)

    local centered_y = self:calculateVerticalCenter(ctx, layout)

    self:handleToolbarDragDrop(ctx, currentToolbar, self.toolbar_controller.button_editing_mode, coords, draw_list, centered_y)

    local window_width = reaper.ImGui_GetWindowWidth(ctx)
    local should_split = layout.split_point and (window_width - layout.right_width > layout.groups[layout.split_point].x)

    for i, group_layout in ipairs(layout.groups) do
        local group = currentToolbar.groups[i]
        local group_x = group_layout.x
        
        if should_split and i >= layout.split_point then
            group_x = window_width - layout.right_width + (group_x - layout.groups[layout.split_point].x)
        end
        
        C.GroupRenderer:renderGroup(
            ctx,
            group,
            group_x,
            centered_y,
            coords,
            draw_list,
            self.toolbar_controller.button_editing_mode,
            group_layout
        )

        for _, button in ipairs(group.buttons) do
            if C.ButtonSettingsMenu:handleButtonSettingsMenu(ctx, button, group) then
                popup_open = true
            end
        end
    end

    if self.toolbar_controller.button_editing_mode and C.ButtonRenderer then
        C.ButtonRenderer:renderPendingControlsOnTop(ctx, draw_list, coords)
    end

    C.LayoutManager:endFrame()
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
        popup_open = C.ButtonDropdownEditor:renderDropdownEditor(ctx, C.ButtonDropdownEditor.current_button) or popup_open
    end

    if C.GlobalColorEditor and C.GlobalColorEditor.is_open then
        popup_open = true
        C.GlobalColorEditor:render(ctx, function()
            CONFIG_MANAGER:saveMainConfig()
        end)
    end

    return popup_open
end

return {
    new = function(...)
        return ToolbarWindow.new(...)
    end
}