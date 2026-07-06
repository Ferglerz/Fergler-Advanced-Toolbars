-- Renderers/01_Toolbar/single_row.lua

function ToolbarWindow:renderSingleRow(ctx, coords, draw_list, row_toolbar, row_index, is_vertical, width_override, switch_toolbar, enable_switch, window_width, window_height, editing_mode, pin_force_horizontal, layout0, layout_switch, row_offset_x, row_offset_y)
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
    if self.toolbar_controller:shouldFollowUiAnchor() and not layout0.is_vertical and not layout0.split_active then
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

    local centered_y0 = layout0.padding_y or 0

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
        main_offset_x + pin_shift_x + (row_offset_x or 0),
        main_offset_y + (row_offset_y or 0)
    )

    local layout = C.LayoutManager:applyDragGhostLayoutShift(layout0, layout_source_toolbar) or layout0
    if layout ~= layout0 then
        local cy_refine = centered_y0
        self:refineDropPositionForDragGhost(ctx, coords, layout, layout_source_toolbar, row_toolbar, cy_refine, 0, main_offset_x + pin_shift_x + (row_offset_x or 0), main_offset_y + (row_offset_y or 0))
        layout = C.LayoutManager:applyDragGhostLayoutShift(layout0, layout_source_toolbar) or layout
    end

    local centered_y = centered_y0

    local row_offset_x_val = row_offset_x or 0
    local row_offset_y_val = row_offset_y or 0
    local prescan_offset_x = main_offset_x + pin_shift_x + row_offset_x_val
    local prescan_offset_y = main_offset_y + row_offset_y_val

    if editing_mode and C.ButtonRenderer and not self:toolbarIsEmpty(row_toolbar) then
        C.ButtonRenderer:prescanRowInsertionControls(ctx, coords, {
            editing_mode = editing_mode,
            layout = layout,
            layout_source_toolbar = layout_source_toolbar,
            main_offset_x = prescan_offset_x,
            main_offset_y = prescan_offset_y,
            centered_y = centered_y,
            group_origin_fn = function(gi, gx, gy)
                return self:layoutGroupOriginForSplit(layout, width_override or window_width, window_height, gi, gx, gy)
            end,
        })
    elseif editing_mode and C.ButtonRenderer then
        C.ButtonRenderer:beginRowInsertionPrescan()
    end

    if enable_switch and layout_switch then
        local switch_title_offset_y = (not is_vertical and layout.widget_title_band) or 0
        for i, group_layout in ipairs(layout_switch.groups) do
            local group = switch_toolbar.groups[i]
            local group_x = group_layout.x + pin_shift_x + (row_offset_x or 0)
            local group_y = (layout_switch.is_vertical and (group_layout.y or 0) or (centered_y + switch_title_offset_y)) + (row_offset_y or 0)
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
        self:drawToolbarSwitchSeparator(ctx, draw_list, coords, layout_switch, is_vertical, sep_size, centered_y + switch_title_offset_y, switch_gap_before_sep, pin_shift_x, (row_offset_x or 0), (row_offset_y or 0), width_override)
    end

    if self:toolbarIsEmpty(row_toolbar) then
        for i, group_layout in ipairs(layout.groups) do
            local group = layout_source_toolbar.groups[i]
            local group_x = group_layout.x + main_offset_x + pin_shift_x + (row_offset_x or 0)
            local group_y = (layout.is_vertical and (group_layout.y or 0) or centered_y) + main_offset_y + (row_offset_y or 0)
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
            local er = self:getGroupButtonRect(layout, 1, 1, centered_y, 0, width_override or window_width, window_height, main_offset_x + pin_shift_x + (row_offset_x or 0), main_offset_y + (row_offset_y or 0))
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
            local group_x = group_layout.x + main_offset_x + pin_shift_x + (row_offset_x or 0)
            local group_y = (layout.is_vertical and (group_layout.y or 0) or centered_y) + main_offset_y + (row_offset_y or 0)
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
                        if C.Interactions:consumeNeedsOpenSettings(ctx) then
                            reaper.ImGui_OpenPopup(ctx, "button_settings_menu_" .. button.instance_id)
                        end
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
                main_offset_x + pin_shift_x + (row_offset_x or 0),
                main_offset_y + (row_offset_y or 0)
            )
        end
        C.ButtonRenderer:renderPendingControlsOnTop(ctx, draw_list, coords)
    end

    return popup_open
end
