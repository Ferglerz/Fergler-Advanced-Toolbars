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

