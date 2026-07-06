function ButtonSettingsMenu:drawSeparator(ctx)
    local current_y = reaper.ImGui_GetCursorPosY(ctx)
    
    -- Prevent drawing separator as the very first item (ImGui typical top cursor Y is usually ~4.0 - 8.0)
    if current_y <= 8.0 then
        return
    end
    
    local _, screen_y = reaper.ImGui_GetCursorScreenPos(ctx)
    
    -- Prevent double separators (if screen Y hasn't advanced by at least ~15px, roughly an item's height)
    if math.abs(screen_y - self._last_separator_screen_y) < 15 then
        return
    end
    
    reaper.ImGui_Separator(ctx)
    _, self._last_separator_screen_y = reaper.ImGui_GetCursorScreenPos(ctx)
end

function ButtonSettingsMenu:handleButtonSettingsMenu(ctx, button, active_group, is_vertical_layout)
    -- Use instance_id for unique popup identification
    local popup_id = "button_settings_menu_" .. button.instance_id

    return C.GlobalStyle.withGlobalStyle(ctx, function()
        if not reaper.ImGui_BeginPopup(ctx, popup_id) then
            return false
        end

        local has_custom_settings = button.widget and type(button.widget.onSettingsMenu) == "function"
        if has_custom_settings then
            -- Calculate dynamic widths based on content heuristics
            local right_text = is_vertical_layout and "Up/Down Split From This Group" or "Left/Right Split From This Group"
            local right_w = reaper.ImGui_CalcTextSize(ctx, right_text) + 60
            
            local left_w = reaper.ImGui_CalcTextSize(ctx, "Left/Right Split From This Group") + 60 -- Default fallback
            if button.widget.type == "ftc_adaptive_grid" then
                left_w = reaper.ImGui_CalcTextSize(ctx, "Select Adaptive Grid Menu script...") + 60
            elseif button.widget.type == "colour_swatch" then
                left_w = reaper.ImGui_CalcTextSize(ctx, "Duplicate palette…") + 100
            elseif type(button.widget.getSettingsMenuWidth) == "function" then
                left_w = button.widget:getSettingsMenuWidth(ctx)
            end

            local table_flags = reaper.ImGui_TableFlags_BordersInnerV()
            if reaper.ImGui_BeginTable(ctx, "settings_table", 2, table_flags) then
                reaper.ImGui_TableSetupColumn(ctx, "Widget", reaper.ImGui_TableColumnFlags_WidthFixed(), left_w)
                reaper.ImGui_TableSetupColumn(ctx, "Default", reaper.ImGui_TableColumnFlags_WidthFixed(), right_w)
                reaper.ImGui_TableNextRow(ctx)
                reaper.ImGui_TableSetColumnIndex(ctx, 0)
                
                button.widget:onSettingsMenu(ctx, button)
                
                reaper.ImGui_TableSetColumnIndex(ctx, 1)
                -- Small padding
                reaper.ImGui_Dummy(ctx, 4, 0)
                reaper.ImGui_SameLine(ctx)
                reaper.ImGui_BeginGroup(ctx)
                self:renderDefaultButtonSettings(ctx, button, active_group, is_vertical_layout)
                reaper.ImGui_EndGroup(ctx)
                
                reaper.ImGui_EndTable(ctx)
            end
        else
            self:renderDefaultButtonSettings(ctx, button, active_group, is_vertical_layout)
        end

        reaper.ImGui_EndPopup(ctx)
        return true
    end)
end

function ButtonSettingsMenu:renderDefaultButtonSettings(ctx, button, active_group, is_vertical_layout)

    -- Show button type in header
    if button:isSeparator() then
        reaper.ImGui_TextDisabled(ctx, "Separator Button")
        self:drawSeparator(ctx)
        
        -- Limited options for separators
        if reaper.ImGui_MenuItem(ctx, "Name and Icon") then
            C.IconSelector:show(button, ctx)
        end

        if reaper.ImGui_MenuItem(ctx, "Hide Name", nil, button.hide_label) then
            button.hide_label = not button.hide_label
            if button.clearLayoutCache then
                button:clearLayoutCache()
            else
                button:clearCache()
            end
            button:saveChanges()
        end

        if reaper.ImGui_BeginMenu(ctx, "Text Alignment") then
            self:handleAlignmentMenu(ctx, button)
            reaper.ImGui_EndMenu(ctx)
        end

        self:drawSeparator(ctx)

        -- Colors and icons for separators
        self:addColorMenus(ctx, button)
        self:drawSeparator(ctx)


    else
        -- Full options for normal buttons
        local has_widget = button.widget ~= nil

        if has_widget then
            if button.widget.type == "slider" then
                if button.widget.snap_points or button.widget.snap_increment then
                    local current_snap = not button.widget.default_snap_disabled
                    if reaper.ImGui_MenuItem(ctx, "Snap by default", nil, current_snap) then
                        button.widget.default_snap_disabled = current_snap
                        button:saveChanges()
                    end
                end
                
                if button.widget.slider_style == "simple_knob" then
                    local current_dir = button.widget.knob_bg_direction or "right"
                    local is_flipped = current_dir == "left"
                    if reaper.ImGui_MenuItem(ctx, "Flip sides", nil, is_flipped) then
                        button.widget.knob_bg_direction = is_flipped and "right" or "left"
                        button:saveChanges()
                    end
                end
            end

            self:drawSeparator(ctx)
        end

        if not has_widget then
            if reaper.ImGui_MenuItem(ctx, "Name and Icon") then
                C.IconSelector:show(button, ctx)
            end

            if reaper.ImGui_MenuItem(ctx, "Hide Name", nil, button.hide_label) then
                button.hide_label = not button.hide_label
                if button.clearLayoutCache then
                    button:clearLayoutCache()
                else
                    button:clearCache()
                end
                button:saveChanges()
            end

            if reaper.ImGui_BeginMenu(ctx, "Text Alignment") then
                self:handleAlignmentMenu(ctx, button)
                reaper.ImGui_EndMenu(ctx)
            end

            if C.ActionSearch and reaper.ImGui_MenuItem(ctx, "Assign Action…") then
                C.ActionSearch:open({ mode = "change_action", button = button, ctx = ctx })
            end

            self:drawSeparator(ctx)

            -- Right-click behavior (only when no widget — widget owns interaction)
            self:handleRightClickMenu(ctx, button)
            if button.right_click == "dropdown" and reaper.ImGui_MenuItem(ctx, "Edit Dropdown Items") then
                self.dropdown_edit_button = button
            elseif button.right_click == "launch" and reaper.ImGui_MenuItem(ctx, "Choose Right-Click Action…") then
                if C.ActionSearch then
                    C.ActionSearch:open({ mode = "right_click_action", button = button, ctx = ctx })
                else
                    self:handleRightClickAction(button)
                end
            end
        end

        self:drawSeparator(ctx)

        -- Widget handling (only for normal buttons)
        if WIDGETS then
            if reaper.ImGui_MenuItem(ctx, button.widget and "Change Widget" or "Assign Widget") then
                self:showWidgetSelector(button, ctx)
            end

            if button.widget and reaper.ImGui_MenuItem(ctx, "Remove Widget") then
                C.WidgetsManager:removeWidgetFromButton(button)
                button:clearCache()
                button:saveChanges()
            end
        end

        if self.show_widget_selector then
            -- Selector is rendered globally from ToolbarWindow:renderUIElements().
            -- Do not render it here as well, or duplicate windows can appear.
            self.show_widget_selector = false
        end

        self:drawSeparator(ctx)

        self:addColorMenus(ctx, button)
        if not has_widget then
            self:drawSeparator(ctx)

        end
    end

    if reaper.ImGui_MenuItem(ctx, "Hide Background & Shadow", nil, button.hide_bg_shadow) then
        button.hide_bg_shadow = not button.hide_bg_shadow
        button:saveChanges()
    end

    if active_group and #active_group.buttons > 1 then
        self:drawSeparator(ctx)

        local group_hide_bg_shadow = true
        for _, group_button in ipairs(active_group.buttons) do
            if not group_button.hide_bg_shadow then
                group_hide_bg_shadow = false
                break
            end
        end

        if reaper.ImGui_MenuItem(ctx, "Hide Background & Shadow for Group", nil, group_hide_bg_shadow) then
            local new_val = not group_hide_bg_shadow
            for _, group_button in ipairs(active_group.buttons) do
                group_button.hide_bg_shadow = new_val
            end
            button:saveChanges()
        end
    end

    -- Group options (available to both types)
    if active_group and CONFIG.UI.USE_GROUP_LABELS then
        self:drawSeparator(ctx)
        
        local group_label = #active_group.group_label.text > 0 and "Rename Group" or "Name Group"
        if reaper.ImGui_MenuItem(ctx, group_label) then
            local retval, new_name =
                reaper.GetUserInputs("Group Name", 1, "Group Name:,extrawidth=100", active_group.group_label.text or "")
            if retval then
                active_group.group_label.text = new_name
                button:saveChanges()
            end
        end

        -- Add the split option; axis label follows current toolbar orientation.
        local split_label = is_vertical_layout and "Up/Down Split From This Group" or "Left/Right Split From This Group"
        local current_split
        if is_vertical_layout then
            current_split = active_group.is_split_point_v
        else
            current_split = active_group.is_split_point_h
        end
        if reaper.ImGui_MenuItem(ctx, split_label, nil, current_split) then
            if is_vertical_layout then
                active_group.is_split_point_v = not active_group.is_split_point_v
            else
                active_group.is_split_point_h = not active_group.is_split_point_h
            end
            button:saveChanges()
        end
    end

    self:drawSeparator(ctx)
    if reaper.ImGui_MenuItem(ctx, "Open toolbar settings") then
        reaper.ImGui_CloseCurrentPopup(ctx)
        if C.Interactions then
            C.Interactions:queueOpenToolbarSettings(ctx)
            C.Interactions:clearButtonSettings(ctx)
        end
    end

    self:drawSeparator(ctx)

    -- Remove Button option in red color at the bottom
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0xFF4444FF) -- Red color
    if reaper.ImGui_MenuItem(ctx, button:isSeparator() and "Remove Separator" or "Remove Button") then
        self:handleRemoveButton(button)
    end
    reaper.ImGui_PopStyleColor(ctx)
end

-- Right-click behavior submenu (only for normal buttons)
function ButtonSettingsMenu:handleRightClickMenu(ctx, button)
    if not reaper.ImGui_BeginMenu(ctx, "Right-Click Behavior") then
        return false
    end

    local options = {
        ["Arm Command"] = "arm",
        ["Show Dropdown"] = "dropdown", 
        ["Launch Action"] = "launch",
        ["No Action"] = "none"
    }

    for label, value in pairs(options) do
        if reaper.ImGui_MenuItem(ctx, label, nil, button.right_click == value) then
            button.right_click = value
            button:saveChanges()
        end
    end

    reaper.ImGui_EndMenu(ctx)
    return true
end

-- Text alignment submenu
function ButtonSettingsMenu:handleAlignmentMenu(ctx, button)
    local alignments = {"left", "center", "right"}
    for _, align in ipairs(alignments) do
        if reaper.ImGui_MenuItem(ctx, align:gsub("^%l", string.upper), nil, button.alignment == align) then
            button.alignment = align
            if button.clearLayoutCache then
                button:clearLayoutCache()
            else
                button:clearCache()
            end
            button:saveChanges()
        end
    end
end



-- Remove button handler
function ButtonSettingsMenu:handleRemoveButton(button)
    return C.IniManager:deleteButton(button)
end

function ButtonSettingsMenu:handleRightClickAction(button)
    local current_action = button.right_click_action or ""
    local retval, new_action = reaper.GetUserInputs(
        "Set Right-Click Action",
        1,
        "Command ID:,extrawidth=80",
        current_action
    )

    if not retval then
        return false
    end

    button.right_click_action = new_action
    button:saveChanges()
    return true
end

-- Load color presets from external file
