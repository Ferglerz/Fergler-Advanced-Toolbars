import re

with open('/Users/fearghasgundy/Desktop/Audio/Reaper/Scripts/Advanced Toolbars/Working Copy/Renderers/01_Toolbar.lua', 'r') as f:
    content = f.read()

# Fix hover check
hover_old = """        if reaper.ImGui_IsWindowHovered(ctx) and not reaper.ImGui_IsAnyItemHovered(ctx) and reaper.ImGui_IsMouseClicked(ctx, 1) then
            reaper.ImGui_OpenPopup(ctx, "toolbar_settings_menu")
        end"""
hover_new = """        local hover_flags = reaper.ImGui_HoveredFlags_ChildWindows and reaper.ImGui_HoveredFlags_ChildWindows() or 0
        if reaper.ImGui_IsWindowHovered(ctx, hover_flags) and not reaper.ImGui_IsAnyItemHovered(ctx) and reaper.ImGui_IsMouseClicked(ctx, 1) then
            reaper.ImGui_OpenPopup(ctx, "toolbar_settings_menu")
        end"""
content = content.replace(hover_old, hover_new)

# Replace renderSingleRow and renderToolbarContent
match = re.search(r"function ToolbarWindow:renderSingleRow\(ctx.*?return popup_open\nend", content, re.DOTALL)
if match:
    old_funcs = match.group(0)
    
    new_funcs = """function ToolbarWindow:renderSingleRow(ctx, coords, draw_list, row_toolbar, row_index, is_vertical, width_override, switch_toolbar, enable_switch, window_width, window_height, editing_mode, pin_force_horizontal, layout0, layout_switch)
    local popup_open = false
    
    local strip_gap = (CONFIG.SIZES and CONFIG.SIZES.SPACING) or 2
    local sep_size = (CONFIG.SIZES and CONFIG.SIZES.SEPARATOR_SIZE) or 12
    local switch_gap_before_sep = strip_gap + 4

    local main_offset_x = 0
    local main_offset_y = 0

    if enable_switch and switch_toolbar and layout_switch then
        if is_vertical then
            main_offset_y = layout_switch.height + switch_gap_before_sep + sep_size + strip_gap
        else
            main_offset_x = layout_switch.width + switch_gap_before_sep + sep_size + strip_gap
        end
    end

    local layout_source_toolbar = row_toolbar
    if self:toolbarIsEmpty(row_toolbar) then
        local ph_button, ph_group = self.toolbar_controller:getEmptyPlaceholderButton(row_toolbar)
        layout_source_toolbar = self:buildPlaceholderShadowToolbar(row_toolbar, ph_group, ph_button)
    end
    
    local pin_shift_x = 0
    if self.toolbar_controller:shouldFollowUiAnchor() and not layout0.is_vertical then
        local row_w = main_offset_x + layout0.width
        local slack = (width_override or window_width) - row_w
        if slack > 0 then
            local al = self.toolbar_controller.ui_anchor_align or "center"
            if al == "center" then
                pin_shift_x = math.floor(slack * 0.5 + 0.5)
            elseif al == "right" then
                pin_shift_x = math.floor(slack + 0.5)
            end
        end
    end

    local centered_y0 = 0
    if layout0.is_vertical then
        centered_y0 = layout0.padding_y or 0
    else
        centered_y0 = 8 -- Min padding
    end

    self:handleToolbarDragDrop(
        ctx,
        row_toolbar,
        editing_mode,
        coords,
        draw_list,
        layout0,
        centered_y0,
        0, -- edit_mode_left_gutter
        layout_source_toolbar,
        main_offset_x + pin_shift_x,
        main_offset_y
    )

    local layout = C.LayoutManager:applyDragGhostLayoutShift(layout0, layout_source_toolbar) or layout0
    if layout ~= layout0 then
        local cy_refine = centered_y0
        self:refineDropPositionForDragGhost(ctx, coords, layout, layout_source_toolbar, row_toolbar, cy_refine, 0, main_offset_x + pin_shift_x, main_offset_y)
        layout = C.LayoutManager:applyDragGhostLayoutShift(layout0, layout_source_toolbar) or layout
    end

    local centered_y = centered_y0

    if enable_switch and layout_switch then
        local switch_title_offset_y = (not is_vertical and layout.widget_title_band) or 0
        for i, group_layout in ipairs(layout_switch.groups) do
            local group = switch_toolbar.groups[i]
            local group_x = group_layout.x + pin_shift_x
            local group_y = layout_switch.is_vertical and (group_layout.y or 0) or (centered_y + switch_title_offset_y)
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
                switch_toolbar
            )
        end
        self:drawToolbarSwitchSeparator(ctx, draw_list, coords, layout_switch, is_vertical, sep_size, centered_y + switch_title_offset_y, switch_gap_before_sep, pin_shift_x, 0, 0, width_override)
    end

    if self:toolbarIsEmpty(row_toolbar) then
        for i, group_layout in ipairs(layout.groups) do
            local group = layout_source_toolbar.groups[i]
            local group_x = group_layout.x + main_offset_x + pin_shift_x
            local group_y = (layout.is_vertical and (group_layout.y or 0) or centered_y) + main_offset_y
            group_x, group_y = self:layoutGroupOriginForSplit(layout, width_override or window_width, window_height, i, group_x, group_y)

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

        if editing_mode and C.DragDropManager:isDragging() and C.DragDropManager.empty_drop_toolbar == row_toolbar and
            layout.groups[1] and layout.groups[1].buttons[1] then
            local er = self:getGroupButtonRect(layout, 1, 1, centered_y, 0, width_override or window_width, window_height, main_offset_x + pin_shift_x, main_offset_y)
            self:renderEmptyDropHighlight(ctx, draw_list, coords, er)
            -- simplified ghost logic
            if C.DragDropManager:isGroupDrag() and C.DragDropManager:getDragSourceGroup() then
                local src_group = C.DragDropManager:getDragSourceGroup()
                local spacing = CONFIG.SIZES.SPACING or 0
                local gx, gy = er.rel_x, er.rel_y
                for _, btn in ipairs(src_group.buttons) do
                    local gw = (btn.cached_width and btn.cached_width.total) or CONFIG.SIZES.MIN_WIDTH
                    local gh = CONFIG.SIZES.HEIGHT
                    if btn:isSeparator() then
                        if layout.is_vertical then gw, gh = er.width, (btn.cache.layout and btn.cache.layout.height) or CONFIG.SIZES.SEPARATOR_SIZE
                        else gw, gh = (btn.cache.layout and btn.cache.layout.width) or CONFIG.SIZES.SEPARATOR_SIZE, CONFIG.SIZES.SEPARATOR_SIZE end
                    elseif layout.is_vertical then gw = er.width end
                    local bl = { width = gw, height = gh, is_vertical = layout.is_vertical }
                    C.ButtonRenderer:renderButton(ctx, btn, gx, gy, coords, draw_list, editing_mode, bl, { ghost_mode = true })
                    if layout.is_vertical then gy = gy + gh + spacing else gx = gx + gw + spacing end
                end
            else
                local src = C.DragDropManager:getDragSource()
                if src then
                    local gw = (src.cached_width and src.cached_width.total) or CONFIG.SIZES.MIN_WIDTH
                    local gh = CONFIG.SIZES.HEIGHT
                    if src:isSeparator() then
                        if layout.is_vertical then gw, gh = er.width, (src.cache.layout and src.cache.layout.height) or CONFIG.SIZES.SEPARATOR_SIZE
                        else gw, gh = (src.cache.layout and src.cache.layout.width) or CONFIG.SIZES.SEPARATOR_SIZE, CONFIG.SIZES.SEPARATOR_SIZE end
                    elseif layout.is_vertical then gw = er.width end
                    local gx, gy = er.rel_x + (er.width - gw) / 2, er.rel_y + (er.height - gh) / 2
                    local gl = { width = gw, height = gh, is_vertical = layout.is_vertical }
                    C.ButtonRenderer:renderButton(ctx, src, gx, gy, coords, draw_list, editing_mode, gl, { ghost_mode = true })
                end
            end
        end
    else
        for i, group_layout in ipairs(layout.groups) do
            local group = row_toolbar.groups[i]
            local group_x = group_layout.x + main_offset_x + pin_shift_x
            local group_y = (layout.is_vertical and (group_layout.y or 0) or centered_y) + main_offset_y
            group_x, group_y = self:layoutGroupOriginForSplit(layout, width_override or window_width, window_height, i, group_x, group_y)

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
                row_toolbar
            )

            local settings_button, settings_group = C.Interactions:getButtonSettings(ctx)
            if settings_button then
                for _, button in ipairs(group.buttons) do
                    if button.instance_id == settings_button.instance_id then
                        if C.ButtonSettingsMenu:handleButtonSettingsMenu(ctx, settings_button, settings_group, layout.is_vertical) then
                            popup_open = true
                        else
                            C.Interactions:clearButtonSettings(ctx)
                        end
                        break
                    end
                end
            end
        end
    end

    if editing_mode and C.ButtonRenderer then
        if row_toolbar and not row_toolbar.is_toolbar_switch_widget then
            self:renderEditModeTrailingAddControl(
                ctx,
                coords,
                draw_list,
                layout,
                row_toolbar,
                width_override or window_width,
                window_height,
                centered_y,
                0,
                main_offset_x + pin_shift_x,
                main_offset_y
            )
        end
        if row_index == 0 then
            C.ButtonRenderer:renderPendingControlsOnTop(ctx, draw_list, coords)
        end
    end

    return popup_open
end

function ToolbarWindow:renderToolbarContent(ctx)
    local all_toolbars = self.toolbar_controller:getAllRowToolbars()
    if not all_toolbars or #all_toolbars == 0 or not all_toolbars[1] then
        return false
    end

    local popup_open = false

    C.LayoutManager:setContext(ctx)
    local window_width = reaper.ImGui_GetWindowWidth(ctx)
    local window_height = reaper.ImGui_GetWindowHeight(ctx)
    local pin_force_horizontal = self.toolbar_controller:shouldFollowUiAnchor()
    local is_vertical = not pin_force_horizontal and window_width > 0 and window_height > 0 and window_width < window_height

    local editing_mode = self.toolbar_controller.button_editing_mode
    local row_count = #all_toolbars

    local col_width = nil
    local row_height = nil
    if is_vertical then
        col_width = math.floor(window_width / row_count)
    else
        row_height = math.floor(window_height / row_count)
    end

    local layout0 = nil
    local layout_switch0 = nil

    for i = 1, row_count do
        local row_index = i - 1
        local row_toolbar = all_toolbars[i]
        
        if not self:toolbarIsEmpty(row_toolbar) and self.toolbar_controller._empty_ph_button then
            self.toolbar_controller:clearEmptyPlaceholderCache()
        end

        local enable_switch = false
        local switch_tb = nil
        if row_index == 0 then
            enable_switch = self.toolbar_controller.enable_toolbar_switch
            switch_tb = self.toolbar_controller.toolbar_switch_toolbar
        else
            enable_switch = self.toolbar_controller.extra_rows[row_index] and self.toolbar_controller.extra_rows[row_index].enable_toolbar_switch
            switch_tb = self.toolbar_controller.extra_row_switch_toolbars[row_index]
        end

        local layout_switch = nil
        local main_offset_x = 0
        local main_offset_y = 0
        local strip_gap = (CONFIG.SIZES and CONFIG.SIZES.SPACING) or 2
        local sep_size = (CONFIG.SIZES and CONFIG.SIZES.SEPARATOR_SIZE) or 12
        local switch_gap_before_sep = strip_gap + 4

        if enable_switch and switch_tb then
            self:tagToolbarButtons(switch_tb, self.toolbar_controller.toolbar_id)
            layout_switch = C.LayoutManager:getToolbarLayout(
                tostring(self.toolbar_controller.toolbar_id) .. "_row_" .. tostring(row_index) .. "_switch",
                switch_tb,
                { force_horizontal = pin_force_horizontal }
            )
            if is_vertical then
                main_offset_y = layout_switch.height + switch_gap_before_sep + sep_size + strip_gap
            else
                main_offset_x = layout_switch.width + switch_gap_before_sep + sep_size + strip_gap
            end
        end

        local layout_source_toolbar = row_toolbar
        if self:toolbarIsEmpty(row_toolbar) then
            local ph_button, ph_group = self.toolbar_controller:getEmptyPlaceholderButton(row_toolbar)
            layout_source_toolbar = self:buildPlaceholderShadowToolbar(row_toolbar, ph_group, ph_button)
        end

        self:tagToolbarButtons(layout_source_toolbar, self.toolbar_controller.toolbar_id)

        local layout_opts = { editing_mode = editing_mode, force_horizontal = pin_force_horizontal }
        if is_vertical then
            layout_opts.width_override = col_width
        else
            if enable_switch and switch_tb and main_offset_x > 0 then
                layout_opts.width_override = math.max(window_width - main_offset_x, CONFIG.SIZES.MIN_WIDTH or 30)
            end
        end

        local layout_id = tostring(self.toolbar_controller.toolbar_id) .. (row_index == 0 and "" or ("_row_" .. row_index))
        local layout0_local = C.LayoutManager:getToolbarLayout(layout_id, layout_source_toolbar, layout_opts)

        local child_id = "row_child_" .. row_index
        local flags = reaper.ImGui_WindowFlags_NoBackground()
        if not is_vertical then
            flags = flags | reaper.ImGui_WindowFlags_HorizontalScrollbar()
        end

        local child_w = is_vertical and col_width or 0
        local child_h = is_vertical and 0 or row_height

        local use_child = not pin_force_horizontal
        if use_child then
            reaper.ImGui_BeginChild(ctx, child_id, child_w, child_h, 0, flags)
        end

        local coords = COORDINATES.new(ctx)
        local draw_list = reaper.ImGui_GetWindowDrawList(ctx)

        local pop = self:renderSingleRow(
            ctx, coords, draw_list, row_toolbar, row_index, is_vertical,
            col_width, switch_tb, enable_switch,
            window_width, window_height, editing_mode, pin_force_horizontal, layout0_local, layout_switch
        )
        if pop then popup_open = true end
        
        if use_child then
            reaper.ImGui_EndChild(ctx)
        end

        if row_index == 0 then
            layout0 = layout0_local
            layout_switch0 = layout_switch
        end

        if i < row_count and use_child then
            if is_vertical then
                reaper.ImGui_SameLine(ctx)
            end
        end
    end

    if pin_force_horizontal and layout0 then
        local single_h = self:computePinnedMinContentHeight(layout0, layout_switch0, self.toolbar_controller.enable_toolbar_switch)
        self._pin_content_min_h = single_h * row_count
    end

    self.toolbar_controller:updateDockState(ctx)

    return popup_open
end"""

    content = content.replace(old_funcs, new_funcs)
else:
    print("Could not find functions to replace")

with open('/Users/fearghasgundy/Desktop/Audio/Reaper/Scripts/Advanced Toolbars/Working Copy/Renderers/01_Toolbar.lua', 'w') as f:
    f.write(content)
print("Updated 01_Toolbar.lua")
