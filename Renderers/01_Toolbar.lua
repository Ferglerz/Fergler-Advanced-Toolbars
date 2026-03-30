-- Renderers/01_Toolbars.lua

local ToolbarWindow = {}
ToolbarWindow.__index = ToolbarWindow

function ToolbarWindow.new(ToolbarController)
    local self = setmetatable({}, ToolbarWindow)
    self.toolbar_controller = ToolbarController
    self.fonts_preloaded = false
    self.last_window_width = 0
    self.last_window_height = 0
    return self
end

function ToolbarWindow:render(ctx, font)
    if not self.toolbar_controller then
        return
    end

    self.toolbar_controller.ctx = ctx
    self.toolbar_controller:applyDockState(ctx)

    reaper.ImGui_PushFont(ctx, font, 12)

    -- Use cached colors for performance
    local window_bg_color = CONFIG_MANAGER:getCachedColorSafe("WINDOW_BG") or COLOR_UTILS.toImGuiColor(CONFIG.COLORS.WINDOW_BG)

    local styles = {
        {reaper.ImGui_Col_WindowBg(), window_bg_color},
        {reaper.ImGui_Col_PopupBg(), window_bg_color},
        {reaper.ImGui_Col_SliderGrab(), 0x888888FF},
        {reaper.ImGui_Col_SliderGrabActive(), 0xAAAAAAFF},
        {reaper.ImGui_Col_FrameBg(), 0x555555FF}
    }

    for _, style in ipairs(styles) do
        reaper.ImGui_PushStyleColor(ctx, style[1], style[2])
    end

    -- Check if we're in vertical mode using cached dimensions from previous frame
    local is_vertical = self.last_window_width > 0 and self.last_window_height > 0 and self.last_window_width < self.last_window_height

    reaper.ImGui_SetNextWindowSize(ctx, 800, 60, reaper.ImGui_Cond_FirstUseEver())
    -- Reduce max size constraints to prevent windows from being too large and creating invisible clickable areas
    -- Use reasonable maximums: 2000px width, 1000px height (instead of 10000x10000)
    reaper.ImGui_SetNextWindowSizeConstraints(ctx, 50, 60, 2000, 1000)

    local window_flags =
        reaper.ImGui_WindowFlags_NoTitleBar() |
        reaper.ImGui_WindowFlags_NoCollapse() |
        reaper.ImGui_WindowFlags_NoFocusOnAppearing()
    
    -- Hide scrollbar in vertical mode (but still allow scrolling)
    if is_vertical then
        window_flags = window_flags | reaper.ImGui_WindowFlags_NoScrollbar()
    end

    -- Use unique window name for each toolbar to prevent conflicts
    local window_name = "Dynamic Toolbar##" .. (self.toolbar_controller.toolbar_id or "default")
    local visible, open = reaper.ImGui_Begin(ctx, window_name, true, window_flags)
    self.toolbar_controller.is_open = open
    UTILS.snapWindowToMinimum(ctx, 0, 0, true)

    if visible then
        -- Cache window dimensions for next frame
        self.last_window_width = reaper.ImGui_GetWindowWidth(ctx)
        self.last_window_height = reaper.ImGui_GetWindowHeight(ctx)
        if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) then
            if C.DragDropManager and C.DragDropManager:isDragging() then
                C.DragDropManager:endDrag()
            elseif _G.POPUP_OPEN then
                if C.GlobalColorEditor then C.GlobalColorEditor.is_open = false end
                if C.IconSelector then C.IconSelector.is_open = false end
                if C.ButtonDropdownEditor then C.ButtonDropdownEditor.is_open = false end
                if C.ButtonDropdownMenu then
                    C.ButtonDropdownMenu.is_open = false
                    C.ButtonDropdownMenu.owner_ctx = nil
                end
                if C.Interactions then
                    C.Interactions.insert_menu_button = nil
                    C.Interactions.insert_menu_owner_ctx = nil
                    C.Interactions.insert_menu_popup_open = false
                end
                
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

        -- Only refocus arrange window when explicitly closing popups or exiting edit mode
        -- Don't refocus on every mouse release as it can block other scripts from opening
        -- if self.was_mouse_down and not is_mouse_down and not popup_open then
        --     UTILS.focusArrangeWindow(true)
        -- end

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
            C.Interactions:showGlobalColorEditor(open, ctx)
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

function ToolbarWindow:toolbarIsEmpty(toolbar)
    return not toolbar or not toolbar.buttons or #toolbar.buttons == 0
end

-- Relative rect for one button from layout (same math as GroupRenderer:renderGroup).
function ToolbarWindow:getGroupButtonRect(layout, group_index, button_index, centered_y, edit_mode_left_gutter, window_width, offset_x, offset_y)
    local group_layout = layout.groups[group_index]
    local button_layout = group_layout.buttons[button_index]
    edit_mode_left_gutter = edit_mode_left_gutter or 0
    offset_x = offset_x or 0
    offset_y = offset_y or 0
    local should_split = (not layout.is_vertical) and layout.split_point and layout.groups[layout.split_point] and
        (window_width - layout.right_width > layout.groups[layout.split_point].x)
    local group_x = group_layout.x + edit_mode_left_gutter
    local group_y = layout.is_vertical and (group_layout.y or 0) or centered_y
    if should_split and group_index >= layout.split_point then
        group_x = window_width - layout.right_width + (group_x - layout.groups[layout.split_point].x)
    end
    return {
        rel_x = group_x + button_layout.x + offset_x,
        rel_y = group_y + (button_layout.y or 0) + offset_y,
        width = button_layout.width,
        height = button_layout.height
    }
end

function ToolbarWindow:tagToolbarButtons(toolbar, controller_id)
    if not toolbar or not toolbar.groups then
        return
    end
    for _, group in ipairs(toolbar.groups) do
        for _, button in ipairs(group.buttons) do
            button.atb_controller_id = controller_id
            -- WidgetRenderer sets this during draw; layout runs first and calls widget.getLayoutWidth
            -- (e.g. toolbars_list) which needs the controller id so width matches the real toolbar name.
            if button.widget then
                button.widget._atb_controller_id = controller_id
            end
        end
    end
end

-- Thin line between toolbar-switch widget and main toolbar (same style as 03_Button_separator).
-- gap_before_sep: space between switch strip edge and separator column (can be larger than SPACING).
function ToolbarWindow:drawToolbarSwitchSeparator(ctx, draw_list, coords, layout_switch, is_vertical, sep_size, centered_y, gap_before_sep)
    gap_before_sep = gap_before_sep or (CONFIG.SIZES and CONFIG.SIZES.SPACING) or 2
    local line_thickness = 2.0
    local line_color = CONFIG_MANAGER:getCachedColorSafe("SEPARATOR", "LINE", "NORMAL") or 0x666666FF
    local ww = reaper.ImGui_GetWindowWidth(ctx)
    local H = CONFIG.SIZES.HEIGHT
    local inset = math.max(2, math.floor(H / 6))

    if is_vertical then
        local separator_rel_y = layout_switch.height + gap_before_sep + sep_size / 2
        local x1_rel = 6
        local x2_rel = ww - 6
        local x1_draw, separator_y = coords:relativeToDrawList(x1_rel, separator_rel_y)
        local x2_draw, _ = coords:relativeToDrawList(x2_rel, separator_rel_y)
        reaper.ImGui_DrawList_AddLine(draw_list, x1_draw, separator_y, x2_draw, separator_y, line_color, line_thickness)
    else
        local separator_rel_x = layout_switch.width + gap_before_sep + sep_size / 2
        local y1_rel = centered_y + inset
        local y2_rel = centered_y + H - inset
        local separator_x = select(1, coords:relativeToDrawList(separator_rel_x, 0))
        local _, y1_draw = coords:relativeToDrawList(0, y1_rel)
        local _, y2_draw = coords:relativeToDrawList(0, y2_rel)
        reaper.ImGui_DrawList_AddLine(draw_list, separator_x, y1_draw, separator_x, y2_draw, line_color, line_thickness)
    end
end

function ToolbarWindow:buildPlaceholderShadowToolbar(currentToolbar, ph_group, ph_button)
    return {
        section = currentToolbar.section,
        name = currentToolbar.name,
        custom_name = currentToolbar.custom_name,
        groups = { ph_group },
        buttons = { ph_button },
        state = currentToolbar.state,
        updateName = currentToolbar.updateName,
        addButton = currentToolbar.addButton
    }
end

function ToolbarWindow:renderEmptyDropHighlight(ctx, draw_list, coords, rect)
    local x1, y1 = coords:relativeToDrawList(rect.rel_x, rect.rel_y)
    local x2, y2 = coords:relativeToDrawList(rect.rel_x + rect.width, rect.rel_y + rect.height)
    reaper.ImGui_DrawList_AddRect(draw_list, x1, y1, x2, y2, 0x00FF00FF, 0, 0, 3)
end

function ToolbarWindow:calculateVerticalCenter(ctx, layout, editing_mode)
    if layout and layout.is_vertical then
        return (layout.padding_y or 0)
    end

    local window_height = reaper.ImGui_GetWindowHeight(ctx)
    local content_height = layout.height
    local center_y = (window_height - content_height) / 2
    local min_padding = 8
    return math.max(center_y, min_padding)
end

function ToolbarWindow:handleToolbarDragDrop(ctx, toolbar, editing_mode, coords, draw_list, layout, base_y, edit_mode_left_gutter, layout_source_toolbar, content_offset_x, content_offset_y)
    if not editing_mode or not C.DragDropManager:isDragging() then
        return
    end

    if toolbar and toolbar.is_toolbar_switch_widget then
        return
    end

    -- Screen-rect hit test (see Coordinates:isMouseOverWindow). Per-context ImGui_IsWindowHovered is
    -- unreliable when the drag started in another context, which broke cross-toolbar indicators and drops.
    if not coords:isMouseOverWindow() then
        return
    end
    
    edit_mode_left_gutter = edit_mode_left_gutter or 0
    layout_source_toolbar = layout_source_toolbar or toolbar
    content_offset_x = content_offset_x or 0
    content_offset_y = content_offset_y or 0

    if C.DragDropManager:isGroupDrag() then
        local payload = C.DragDropManager.drag_payload
        local src_section = payload and payload.source_toolbar
        local src_gi = payload and payload.source_group_index
        local mouse_screen_x, mouse_screen_y = COORDINATES.getMouseScreenForDrag(ctx)
        local mouse_rel_x, mouse_rel_y = coords:screenToRelative(mouse_screen_x, mouse_screen_y)
        local window_width = reaper.ImGui_GetWindowWidth(ctx)
        local should_split = (not layout.is_vertical) and layout.split_point and layout.groups[layout.split_point] and
            (window_width - layout.right_width > layout.groups[layout.split_point].x)
        -- Empty toolbar: use same placeholder landing zone as button drag (group branch would miss it)
        if (not toolbar.buttons or #toolbar.buttons == 0) and layout.groups[1] and layout.groups[1].buttons[1] and layout_source_toolbar.groups[1] and
            layout_source_toolbar.groups[1].buttons[1] and layout_source_toolbar.groups[1].buttons[1].is_empty_toolbar_placeholder then
            local g1 = layout.groups[1]
            local b1 = g1.buttons[1]
            local group_x = g1.x + edit_mode_left_gutter + content_offset_x
            local group_y = (layout.is_vertical and (g1.y or 0) or base_y) + content_offset_y
            if should_split and layout.split_point and 1 >= layout.split_point then
                group_x = window_width - layout.right_width + (group_x - layout.groups[layout.split_point].x)
            end
            local rx = group_x + b1.x
            local ry = group_y + (b1.y or 0)
            if mouse_rel_x >= rx and mouse_rel_x <= rx + b1.width and mouse_rel_y >= ry and mouse_rel_y <= ry + b1.height then
                C.DragDropManager.empty_drop_toolbar = toolbar
                C.DragDropManager:markPotentialDropTarget()
                return
            end
        end
        for i, group_layout in ipairs(layout.groups) do
            if layout_source_toolbar.section == src_section and i == src_gi then
                -- skip dragged source group
            else
                local group_x = group_layout.x + edit_mode_left_gutter + content_offset_x
                local group_y = (layout.is_vertical and (group_layout.y or 0) or base_y) + content_offset_y
                if should_split and i >= layout.split_point then
                    group_x = window_width - layout.right_width + (group_x - layout.groups[layout.split_point].x)
                end
                local gw = group_layout.width
                local gh = group_layout.height
                if mouse_rel_x >= group_x and mouse_rel_x <= group_x + gw and mouse_rel_y >= group_y and mouse_rel_y <= group_y + gh then
                    C.DragDropManager.drop_target_toolbar = toolbar
                    C.DragDropManager.drop_target_group_index = i
                    if layout.is_vertical then
                        local cy = group_y + gh / 2
                        C.DragDropManager.drop_position = mouse_rel_y > cy and "after" or "before"
                    else
                        local cx = group_x + gw / 2
                        C.DragDropManager.drop_position = mouse_rel_x > cx and "after" or "before"
                    end
                    C.DragDropManager:markPotentialDropTarget()
                    break
                end
            end
        end
        return
    end
    
    local button_rects = {}
    
    C.LayoutManager:setContext(ctx)
    local window_width = reaper.ImGui_GetWindowWidth(ctx)
    local should_split = (not layout.is_vertical) and layout.split_point and layout.groups[layout.split_point] and
        (window_width - layout.right_width > layout.groups[layout.split_point].x)
    
    for i, group_layout in ipairs(layout.groups) do
        local group = layout_source_toolbar.groups[i]
        local group_x = group_layout.x + edit_mode_left_gutter + content_offset_x
        local group_y = (layout.is_vertical and (group_layout.y or 0) or base_y) + content_offset_y
        
        if should_split and i >= layout.split_point then
            group_x = window_width - layout.right_width + (group_x - layout.groups[layout.split_point].x)
        end
        
        for j, button_layout in ipairs(group_layout.buttons) do
            local button = group.buttons[j]
            if not button.is_separator then
                local button_rel_x = group_x + button_layout.x
                local button_rel_y = group_y + (button_layout.y or 0)
                
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
    
    -- Screen mouse must come from the drag source context (or main) so cross-toolbar drags hit-test correctly.
    local mouse_screen_x, mouse_screen_y = COORDINATES.getMouseScreenForDrag(ctx)
    local mouse_rel_x, mouse_rel_y = coords:screenToRelative(mouse_screen_x, mouse_screen_y)
    
    for instance_id, rect in pairs(button_rects) do
        if C.DragDropManager:getDragSource() and C.DragDropManager:getDragSource().instance_id == instance_id then
            -- Skip source button
        else
            if mouse_rel_x >= rect.rel_x and mouse_rel_x <= rect.rel_x + rect.width and
               mouse_rel_y >= rect.rel_y and mouse_rel_y <= rect.rel_y + rect.height then
                if rect.button.is_empty_toolbar_placeholder then
                    C.DragDropManager.empty_drop_toolbar = toolbar
                else
                    C.DragDropManager.current_drop_target = rect.button
                    if layout.is_vertical then
                        local button_center_y = rect.rel_y + rect.height / 2
                        C.DragDropManager.drop_position = mouse_rel_y > button_center_y and "after" or "before"
                    else
                        local button_center_x = rect.rel_x + rect.width / 2
                        C.DragDropManager.drop_position = mouse_rel_x > button_center_x and "after" or "before"
                    end
                end
                C.DragDropManager:markPotentialDropTarget()
                break
            end
        end
    end
end

function ToolbarWindow:refineDropPositionForDragGhost(ctx, coords, layout, layout_source_toolbar, toolbar, base_y, edit_mode_left_gutter, content_offset_x, content_offset_y)
    if not C.DragDropManager:isDragging() then
        return
    end
    if C.DragDropManager:isGroupDrag() then
        local tgt_gi = C.DragDropManager.drop_target_group_index
        if not tgt_gi or not layout.groups[tgt_gi] then
            return
        end
        local mouse_screen_x, mouse_screen_y = COORDINATES.getMouseScreenForDrag(ctx)
        local mouse_rel_x, mouse_rel_y = coords:screenToRelative(mouse_screen_x, mouse_screen_y)
        local window_width = reaper.ImGui_GetWindowWidth(ctx)
        local should_split = (not layout.is_vertical) and layout.split_point and layout.groups[layout.split_point] and
            (window_width - layout.right_width > layout.groups[layout.split_point].x)
        edit_mode_left_gutter = edit_mode_left_gutter or 0
        content_offset_x = content_offset_x or 0
        content_offset_y = content_offset_y or 0
        local group_layout = layout.groups[tgt_gi]
        local group_x = group_layout.x + edit_mode_left_gutter + content_offset_x
        local group_y = (layout.is_vertical and (group_layout.y or 0) or base_y) + content_offset_y
        if should_split and tgt_gi >= layout.split_point then
            group_x = window_width - layout.right_width + (group_x - layout.groups[layout.split_point].x)
        end
        local gw = group_layout.width
        local gh = group_layout.height
        if layout.is_vertical then
            local cy = group_y + gh / 2
            C.DragDropManager.drop_position = mouse_rel_y > cy and "after" or "before"
        else
            local cx = group_x + gw / 2
            C.DragDropManager.drop_position = mouse_rel_x > cx and "after" or "before"
        end
        return
    end
    local tgt = C.DragDropManager:getCurrentDropTarget()
    if not tgt or tgt.is_empty_toolbar_placeholder then
        return
    end
    local mouse_screen_x, mouse_screen_y = COORDINATES.getMouseScreenForDrag(ctx)
    local mouse_rel_x, mouse_rel_y = coords:screenToRelative(mouse_screen_x, mouse_screen_y)
    local window_width = reaper.ImGui_GetWindowWidth(ctx)
    local should_split = (not layout.is_vertical) and layout.split_point and layout.groups[layout.split_point] and
        (window_width - layout.right_width > layout.groups[layout.split_point].x)
    edit_mode_left_gutter = edit_mode_left_gutter or 0
    content_offset_x = content_offset_x or 0
    content_offset_y = content_offset_y or 0
    for i, group_layout in ipairs(layout.groups) do
        local group = layout_source_toolbar.groups[i]
        local group_x = group_layout.x + edit_mode_left_gutter + content_offset_x
        local group_y = (layout.is_vertical and (group_layout.y or 0) or base_y) + content_offset_y
        if should_split and i >= layout.split_point then
            group_x = window_width - layout.right_width + (group_x - layout.groups[layout.split_point].x)
        end
        for j, button_layout in ipairs(group_layout.buttons) do
            local button = group.buttons[j]
            if button.instance_id == tgt.instance_id then
                local rel_x = group_x + button_layout.x
                local rel_y = group_y + (button_layout.y or 0)
                if layout.is_vertical then
                    local cy = rel_y + button_layout.height / 2
                    C.DragDropManager.drop_position = mouse_rel_y > cy and "after" or "before"
                else
                    local cx = rel_x + button_layout.width / 2
                    C.DragDropManager.drop_position = mouse_rel_x > cx and "after" or "before"
                end
                return
            end
        end
    end
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

    if not self:toolbarIsEmpty(currentToolbar) and self.toolbar_controller._empty_ph_button then
        self.toolbar_controller:clearEmptyPlaceholderCache()
    end

    local layout_source_toolbar = currentToolbar
    if self:toolbarIsEmpty(currentToolbar) then
        local ph_button, ph_group = self.toolbar_controller:getEmptyPlaceholderButton(currentToolbar)
        layout_source_toolbar = self:buildPlaceholderShadowToolbar(currentToolbar, ph_group, ph_button)
    end

    C.LayoutManager:setContext(ctx)
    local window_width = reaper.ImGui_GetWindowWidth(ctx)
    local window_height = reaper.ImGui_GetWindowHeight(ctx)
    local is_vertical = window_width > 0 and window_height > 0 and window_width < window_height

    local switch_tb = self.toolbar_controller.toolbar_switch_toolbar
    local show_toolbar_switch = CONFIG.UI and CONFIG.UI.ENABLE_TOOLBAR_SWITCH_WIDGET and switch_tb
    local strip_gap = (CONFIG.SIZES and CONFIG.SIZES.SPACING) or 2
    local sep_size = (CONFIG.SIZES and CONFIG.SIZES.SEPARATOR_SIZE) or 12
    -- Extra air between toolbar-switch strip and separator (layout + draw use same value)
    local switch_gap_before_sep = strip_gap + 4

    local main_offset_x = 0
    local main_offset_y = 0
    local layout_switch = nil

    if show_toolbar_switch then
        self:tagToolbarButtons(switch_tb, self.toolbar_controller.toolbar_id)
        layout_switch = C.LayoutManager:getToolbarLayout(tostring(self.toolbar_controller.toolbar_id) .. "_toolbar_switch", switch_tb)
        if is_vertical then
            main_offset_y = layout_switch.height + switch_gap_before_sep + sep_size + strip_gap
        else
            -- Reserve space for separator column (same as in-toolbar separators) + gaps — avoids overlap with first main button
            main_offset_x = layout_switch.width + switch_gap_before_sep + sep_size + strip_gap
        end
    end

    self:tagToolbarButtons(layout_source_toolbar, self.toolbar_controller.toolbar_id)

    local editing_mode = self.toolbar_controller.button_editing_mode
    local layout_opts = { editing_mode = editing_mode }
    if show_toolbar_switch and not is_vertical and main_offset_x > 0 then
        layout_opts.width_override = math.max(window_width - main_offset_x, CONFIG.SIZES.MIN_WIDTH or 30)
    end

    local layout0 = C.LayoutManager:getToolbarLayout(self.toolbar_controller.toolbar_id, layout_source_toolbar, layout_opts)
    local centered_y0 = self:calculateVerticalCenter(ctx, layout0, editing_mode)
    local edit_mode_left_gutter = 0

    self:handleToolbarDragDrop(
        ctx,
        currentToolbar,
        editing_mode,
        coords,
        draw_list,
        layout0,
        centered_y0,
        edit_mode_left_gutter,
        layout_source_toolbar,
        main_offset_x,
        main_offset_y
    )

    local layout = C.LayoutManager:applyDragGhostLayoutShift(layout0, layout_source_toolbar) or layout0
    if layout ~= layout0 then
        local cy_refine = self:calculateVerticalCenter(ctx, layout, editing_mode)
        self:refineDropPositionForDragGhost(ctx, coords, layout, layout_source_toolbar, currentToolbar, cy_refine, edit_mode_left_gutter, main_offset_x, main_offset_y)
        layout = C.LayoutManager:applyDragGhostLayoutShift(layout0, layout_source_toolbar) or layout
    end

    local centered_y = self:calculateVerticalCenter(ctx, layout, editing_mode)

    local should_split = (not layout.is_vertical) and layout.split_point and layout.groups[layout.split_point] and
        (window_width - layout.right_width > layout.groups[layout.split_point].x)

    -- Toolbar switch + separator + main share one row Y in horizontal mode: use main layout's centered_y only
    -- (layout_switch.height can differ when the widget has a label, which misaligned rows when using sw_centered).
    if show_toolbar_switch and layout_switch then
        for i, group_layout in ipairs(layout_switch.groups) do
            local group = switch_tb.groups[i]
            local group_x = group_layout.x
            local group_y = layout_switch.is_vertical and (group_layout.y or 0) or centered_y
            C.GroupRenderer:renderGroup(
                ctx,
                group,
                group_x,
                group_y,
                coords,
                draw_list,
                false,
                group_layout,
                layout_switch,
                i,
                switch_tb
            )
        end
        self:drawToolbarSwitchSeparator(ctx, draw_list, coords, layout_switch, is_vertical, sep_size, centered_y, switch_gap_before_sep)
    end

    if self:toolbarIsEmpty(currentToolbar) then
        for i, group_layout in ipairs(layout.groups) do
            local group = layout_source_toolbar.groups[i]
            local group_x = group_layout.x + edit_mode_left_gutter + main_offset_x
            local group_y = (layout.is_vertical and (group_layout.y or 0) or centered_y) + main_offset_y

            if should_split and i >= layout.split_point then
                group_x = window_width - layout.right_width + (group_x - layout.groups[layout.split_point].x)
            end

            C.GroupRenderer:renderGroup(
                ctx,
                group,
                group_x,
                group_y,
                coords,
                draw_list,
                editing_mode,
                group_layout,
                layout,
                i,
                layout_source_toolbar
            )
        end

        if editing_mode and C.DragDropManager:isDragging() and C.DragDropManager.empty_drop_toolbar == currentToolbar and
            layout.groups[1] and layout.groups[1].buttons[1] then
            local er = self:getGroupButtonRect(layout, 1, 1, centered_y, edit_mode_left_gutter, window_width, main_offset_x, main_offset_y)
            self:renderEmptyDropHighlight(ctx, draw_list, coords, er)
            if C.DragDropManager:isGroupDrag() and C.DragDropManager:getDragSourceGroup() then
                local src_group = C.DragDropManager:getDragSourceGroup()
                local spacing = CONFIG.SIZES.SPACING or 0
                local gx = er.rel_x
                local gy = er.rel_y
                for _, btn in ipairs(src_group.buttons) do
                    local gw = (btn.cached_width and btn.cached_width.total) or CONFIG.SIZES.MIN_WIDTH
                    local gh = CONFIG.SIZES.HEIGHT
                    if btn:isSeparator() then
                        if layout.is_vertical then
                            gw = er.width
                            gh = (btn.cache.layout and btn.cache.layout.height) or CONFIG.SIZES.SEPARATOR_SIZE
                        else
                            gw = (btn.cache.layout and btn.cache.layout.width) or CONFIG.SIZES.SEPARATOR_SIZE
                        end
                    elseif layout.is_vertical then
                        gw = er.width
                    end
                    local bl = { width = gw, height = gh, is_vertical = layout.is_vertical }
                    C.ButtonRenderer:renderButton(
                        ctx,
                        btn,
                        gx,
                        gy,
                        coords,
                        draw_list,
                        editing_mode,
                        bl,
                        { ghost_mode = true }
                    )
                    if layout.is_vertical then
                        gy = gy + gh + spacing
                    else
                        gx = gx + gw + spacing
                    end
                end
            else
                local src = C.DragDropManager:getDragSource()
                if src then
                    local gw = (src.cached_width and src.cached_width.total) or CONFIG.SIZES.MIN_WIDTH
                    local gh = CONFIG.SIZES.HEIGHT
                    if src:isSeparator() then
                        if layout.is_vertical then
                            gw = er.width
                            gh = (src.cache.layout and src.cache.layout.height) or CONFIG.SIZES.SEPARATOR_SIZE
                        else
                            gw = (src.cache.layout and src.cache.layout.width) or CONFIG.SIZES.SEPARATOR_SIZE
                        end
                    elseif layout.is_vertical then
                        gw = er.width
                    end
                    local gx = er.rel_x + (er.width - gw) / 2
                    local gy = er.rel_y + (er.height - gh) / 2
                    local gl = { width = gw, height = gh, is_vertical = layout.is_vertical }
                    C.ButtonRenderer:renderButton(ctx, src, gx, gy, coords, draw_list, editing_mode, gl, { ghost_mode = true })
                end
            end
        end
    else
        for i, group_layout in ipairs(layout.groups) do
            local group = currentToolbar.groups[i]
            local group_x = group_layout.x + edit_mode_left_gutter + main_offset_x
            local group_y = (layout.is_vertical and (group_layout.y or 0) or centered_y) + main_offset_y
            
            if should_split and i >= layout.split_point then
                group_x = window_width - layout.right_width + (group_x - layout.groups[layout.split_point].x)
            end
            
            C.GroupRenderer:renderGroup(
                ctx,
                group,
                group_x,
                group_y,
                coords,
                draw_list,
                editing_mode,
                group_layout,
                layout,
                i,
                currentToolbar
            )

            -- Only handle button settings menu for the specific button that has it open
            if C.Interactions.button_settings_button then
                local settings_button = C.Interactions.button_settings_button
                local settings_group = C.Interactions.button_settings_group
                -- Check if the settings button is in this group
                for _, button in ipairs(group.buttons) do
                    if button.instance_id == settings_button.instance_id then
                        if C.ButtonSettingsMenu:handleButtonSettingsMenu(ctx, settings_button, settings_group) then
                            popup_open = true
                        else
                            -- Popup was closed, clear the tracked button
                            C.Interactions.button_settings_button = nil
                            C.Interactions.button_settings_group = nil
                        end
                        break
                    end
                end
            end
        end
    end

    if editing_mode and C.ButtonRenderer then
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

    if C.Interactions and C.Interactions.insert_menu_button then
        popup_open = C.Interactions:renderInsertMenu(ctx) or popup_open
    end

    if C.ButtonSettingsMenu.widget_selection and C.ButtonSettingsMenu.widget_selection.is_open then
        popup_open = C.ButtonSettingsMenu:renderWidgetSelector(ctx) or popup_open
    end

    if C.ButtonSettingsMenu.dropdown_edit_button then
        self.toolbar_controller:showDropdownEditor(C.ButtonSettingsMenu.dropdown_edit_button, ctx)
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