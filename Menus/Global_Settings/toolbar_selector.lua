function GlobalSettingsMenu:renderToolbarSelector(
    ctx,
    toolbars,
    currentToolbarIndex,
    setCurrentToolbar,
    toolbarController,
    toggleEditingMode)
    if not toolbars or #toolbars == 0 then
        reaper.ImGui_Text(ctx, "No toolbars found in toolbar configs")
        return
    end

    local current_toolbar = toolbars[currentToolbarIndex]

    -- Toolbar management buttons
    if current_toolbar then
        reaper.ImGui_Spacing(ctx)

        local item_spacing_x = select(1, reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing()))
        local mgmt_avail = reaper.ImGui_GetContentRegionAvail(ctx)
        local mgmt_cell = math.max(48, math.floor((mgmt_avail - 2 * item_spacing_x) / 3))

        local is_editing_mode = toggleEditingMode(nil, true)
        pushAccentButtonStyle(ctx, "blue")
        if reaper.ImGui_Button(ctx, "Edit Toolbars", mgmt_cell, 0) then
            toggleEditingMode(not is_editing_mode)
            reaper.ImGui_CloseCurrentPopup(ctx)
        end
        reaper.ImGui_PopStyleColor(ctx, 4)

        reaper.ImGui_SameLine(ctx)

        if reaper.ImGui_Button(ctx, "Launch New Window", mgmt_cell, 0) then
            _G.CreateNewToolbar()
        end

        reaper.ImGui_SameLine(ctx)
        pushAccentButtonStyle(ctx, "red")
        if reaper.ImGui_Button(ctx, "Close This Toolbar", mgmt_cell, 0) then
            if toolbarController.is_ephemeral then
                toolbarController:setOpen(false)
                reaper.ImGui_CloseCurrentPopup(ctx)
            elseif CONFIG.TOOLBAR_CONTROLLERS and next(CONFIG.TOOLBAR_CONTROLLERS) then
                local toolbar_id_str = tostring(toolbarController.toolbar_id)
                
                -- First check if we have at least 2 toolbar controllers
                local controller_count = 0
                for _ in pairs(CONFIG.TOOLBAR_CONTROLLERS) do
                    controller_count = controller_count + 1
                end
                
                if controller_count > 1 then
                    -- Remove this controller from CONFIG.TOOLBAR_CONTROLLERS
                    CONFIG.TOOLBAR_CONTROLLERS[toolbar_id_str] = nil
                    
                    -- Also remove from the global array
                    for i, controller_data in ipairs(_G.TOOLBAR_CONTROLLERS) do
                        if controller_data.controller.toolbar_id == toolbarController.toolbar_id then
                            table.remove(_G.TOOLBAR_CONTROLLERS, i)
                            break
                        end
                    end
                    
                    -- Save the updated configuration
                    CONFIG_MANAGER:saveMainConfigImmediate()
                    
                    -- Close the toolbar
                    toolbarController:setOpen(false)
                else
                    -- Don't allow deleting the last toolbar
                    reaper.ShowMessageBox("Cannot close the last toolbar window", "Error", 0)
                end
            end
        end
        reaper.ImGui_PopStyleColor(ctx, 4)
    end
end

function GlobalSettingsMenu:reloadToolbarSwitchWidgets()
    for _, cd in ipairs(_G.TOOLBAR_CONTROLLERS or {}) do
        if cd.controller and cd.controller.ensureToolbarSwitchWidget then
            cd.controller:ensureToolbarSwitchWidget()
            if cd.controller.ensureExtraRowSwitchWidgets then
                cd.controller:ensureExtraRowSwitchWidgets()
            end
        end
    end
    if C.LayoutManager then
        C.LayoutManager:requestLayoutRecalcAfterToolbarReady()
    end
end

function GlobalSettingsMenu:renderThisToolbarTab(ctx, toolbarController, saveCallback, toolbars, currentToolbarIndex, setCurrentToolbar)
    if not toolbars or #toolbars == 0 then
        reaper.ImGui_Text(ctx, "No toolbars found in toolbar configs")
        return
    end

    local is_v = toolbarController.is_vertical == true
    local row_col_word = is_v and "Column" or "Row"
    local row_col_word_plural = is_v and "Columns" or "Rows"
    local row_col_word_lower = is_v and "column" or "row"

    -- Create a row with left and right justified elements
    local content_width = reaper.ImGui_GetContentRegionAvail(ctx)

    -- Left side - Header
    reaper.ImGui_TextDisabled(ctx, "Toolbar Properties:")

    -- Right side - Dock info
    local dock_text = "Dock ID: " .. (toolbarController.current_dock_id or "!")
    local display_text = dock_text .. " | ID: " .. toolbarController.toolbar_id
    local display_text_width = reaper.ImGui_CalcTextSize(ctx, display_text)
    reaper.ImGui_SameLine(ctx, content_width - display_text_width)

    reaper.ImGui_TextDisabled(ctx, display_text)

    -- Get active toolbar indices (toolbars currently shown in other windows)
    local active_indices = {}
    if _G.getActiveToolbarIndices then
        active_indices = _G.getActiveToolbarIndices()
    end

    -- Reload | Rename Toolbar — split 50/50
    local rename_label = "Rename Toolbar"
    local item_spacing_x = select(1, reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing()))
    local row_avail = reaper.ImGui_GetContentRegionAvail(ctx)
    local button_w = math.max(48, math.floor((row_avail - item_spacing_x) / 2))
    local current_toolbar = toolbars[currentToolbarIndex]
    
    if reaper.ImGui_Button(ctx, "Reload", button_w, 0) then
        toolbarController.loader:loadToolbars()
    end
    
    local hover_ft = reaper.ImGui_HoveredFlags_None()
    local ok_h, ft_val = pcall(function()
        return reaper.ImGui_HoveredFlags_ForTooltip()
    end)
    if ok_h and ft_val then
        hover_ft = ft_val
    end
    if reaper.ImGui_IsItemHovered(ctx, hover_ft) then
        reaper.ImGui_SetTooltip(ctx, "Reload toolbar")
    end
    
    reaper.ImGui_SameLine(ctx)
    if current_toolbar and reaper.ImGui_Button(ctx, rename_label, button_w, 0) then
        local name_for_input = current_toolbar.custom_name or current_toolbar.name
        local retval, new_name = reaper.GetUserInputs("Rename Toolbar", 1, "New Name:,extrawidth=100", name_for_input)

        if retval then
            current_toolbar:updateName(new_name)
            CONFIG_MANAGER:requestSaveToolbarConfig(current_toolbar)
        end
    elseif not current_toolbar then
        reaper.ImGui_BeginDisabled(ctx)
        reaper.ImGui_Button(ctx, rename_label, button_w, 0)
        reaper.ImGui_EndDisabled(ctx)
    end
    
    reaper.ImGui_Spacing(ctx)
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Spacing(ctx)

    reaper.ImGui_TextDisabled(ctx, row_col_word_plural)
    reaper.ImGui_Spacing(ctx)

    if reaper.ImGui_BeginTable(ctx, "##atb_multirow_table", 3, reaper.ImGui_TableFlags_Borders() | reaper.ImGui_TableFlags_RowBg() | reaper.ImGui_TableFlags_SizingStretchProp()) then
        reaper.ImGui_TableSetupColumn(ctx, "Toolbar", reaper.ImGui_TableColumnFlags_WidthStretch())
        reaper.ImGui_TableSetupColumn(ctx, "Switcher", reaper.ImGui_TableColumnFlags_WidthFixed(), 60)
        reaper.ImGui_TableSetupColumn(ctx, "", reaper.ImGui_TableColumnFlags_WidthFixed(), 60)
        reaper.ImGui_TableHeadersRow(ctx)

        local row_count = toolbarController:getRowCount()
        for i = 0, row_count - 1 do
            reaper.ImGui_TableNextRow(ctx)

            -- Toolbar name (selector button)
            reaper.ImGui_TableNextColumn(ctx)
            local tb = toolbarController:getRowToolbar(i)
            local tb_name = tb and (tb.title or tb.custom_name or "Unknown Toolbar") or "Empty"
            local avail_w = reaper.ImGui_GetContentRegionAvail(ctx)
            if reaper.ImGui_Button(ctx, tb_name .. "##RowToolbarSelectorBtn_" .. i, avail_w, 0) then
                self._active_select_row_index = i
                self:menuPopupOpenAtMouse(ctx, POPUP_TOOLBAR_LIST)
            end
            if reaper.ImGui_IsItemHovered(ctx, hover_ft) then
                reaper.ImGui_SetTooltip(ctx, "Choose toolbar for this " .. row_col_word_lower)
            end

            -- Switch checkbox
            reaper.ImGui_TableNextColumn(ctx)
            local current_switch = false
            if i == 0 then
                current_switch = toolbarController.enable_toolbar_switch
            elseif toolbarController.extra_rows[i] then
                current_switch = toolbarController.extra_rows[i].enable_toolbar_switch
            end
            local switch_changed, switch_val = reaper.ImGui_Checkbox(ctx, "##switch_" .. i, current_switch)
            if switch_changed then
                if i == 0 then
                    toolbarController:setEnableToolbarSwitch(switch_val)
                else
                    toolbarController:setExtraRowToolbarSwitch(i, switch_val)
                end
                saveCallback()
            end

            -- Actions (Reorder and Remove)
            reaper.ImGui_TableNextColumn(ctx)
            local should_break = false
            
            -- Reorder Up (only if i > 1)
            if i > 1 then
                if reaper.ImGui_Button(ctx, "^##up_" .. i) then
                    toolbarController:reorderExtraRow(i, i - 1)
                    saveCallback()
                    should_break = true
                end
                if not should_break then reaper.ImGui_SameLine(ctx) end
            end
            
            -- Reorder Down (only if i > 0 and not the last row)
            if not should_break and i > 0 and i < row_count - 1 then
                if reaper.ImGui_Button(ctx, "v##dn_" .. i) then
                    toolbarController:reorderExtraRow(i, i + 1)
                    saveCallback()
                    should_break = true
                end
                if not should_break then reaper.ImGui_SameLine(ctx) end
            end

            -- Remove (shows for any row index if there's more than 1 row total)
            if not should_break and row_count > 1 then
                pushAccentButtonStyle(ctx, "red")
                if reaper.ImGui_Button(ctx, "X##rm_" .. i) then
                    toolbarController:removeRow(i)
                    saveCallback()
                    should_break = true
                end
                reaper.ImGui_PopStyleColor(ctx, 4)
            end
            
            if should_break then
                break
            end
        end
        reaper.ImGui_EndTable(ctx)
    end

    -- POPUP_TOOLBAR_LIST logic is placed here to be accessible by all selector buttons
    self:menuPopupPrepareFrame(ctx, POPUP_TOOLBAR_LIST)
    local toolbar_list_popup_visible = reaper.ImGui_BeginPopup(ctx, POPUP_TOOLBAR_LIST)
    if toolbar_list_popup_visible then
        local active_row = self._active_select_row_index or 0
        for i, toolbar in ipairs(toolbars) do
            local displayName = toolbar.custom_name or toolbar.name
            local is_selected = false
            if active_row == 0 then
                is_selected = (currentToolbarIndex == i)
            else
                local row_info = toolbarController.extra_rows[active_row]
                is_selected = row_info and (row_info.toolbar_index == i)
            end
            local is_active = active_indices[i] and not is_selected

            if reaper.ImGui_MenuItem(ctx, displayName, nil, is_selected, not is_active) then
                if active_row == 0 then
                    setCurrentToolbar(i)
                    toolbarController.loader:loadToolbars()
                else
                    toolbarController:setExtraRowToolbarIndex(active_row, i)
                end
                saveCallback()
            end

            if toolbar.custom_name and reaper.ImGui_IsItemHovered(ctx) then
                reaper.ImGui_BeginTooltip(ctx)
                reaper.ImGui_Text(ctx, toolbar.section)
                reaper.ImGui_EndTooltip(ctx)
            end
        end
        reaper.ImGui_EndPopup(ctx)
    end
    self:menuPopupEndFrame(ctx, POPUP_TOOLBAR_LIST, toolbar_list_popup_visible)

    reaper.ImGui_Spacing(ctx)
    if reaper.ImGui_Button(ctx, "Add " .. row_col_word) then
        local next_idx = CONFIG_MANAGER:findNextUnusedToolbarIndex(toolbarController.toolbars)
        toolbarController:addExtraRow(next_idx)
        saveCallback()
    end

    reaper.ImGui_SameLine(ctx)
    local scroll_changed, scroll_val = reaper.ImGui_Checkbox(ctx, "Enable per-" .. row_col_word_lower .. " scrolling", toolbarController.enable_row_scroll == true)
    if scroll_changed then
        toolbarController:setEnableRowScroll(scroll_val)
        saveCallback()
    end

    reaper.ImGui_Spacing(ctx)
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Spacing(ctx)

    self:renderUiPinSettings(ctx, toolbarController, saveCallback)
end

