-- Menus/Button_Settings_Menu.lua

local ButtonSettingsMenu = {}
ButtonSettingsMenu.__index = ButtonSettingsMenu

function ButtonSettingsMenu.new()
    local self = setmetatable({}, ButtonSettingsMenu)

    return self
end

function ButtonSettingsMenu:handleButtonSettingsMenu(ctx, button, active_group)
    -- Use instance_id for unique popup identification
    local popup_id = "button_settings_menu_" .. button.instance_id
    
    if not reaper.ImGui_BeginPopup(ctx, popup_id) then
        return false
    end

    local colorCount, styleCount = C.GlobalStyle.apply(ctx, {styles = false})

    -- Show button type in header
    if button:isSeparator() then
        reaper.ImGui_TextDisabled(ctx, "Separator Button")
        reaper.ImGui_Separator(ctx)
        
        -- Limited options for separators
        if reaper.ImGui_MenuItem(ctx, "Rename") then
            self:handleButtonRename(button)
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

        reaper.ImGui_Separator(ctx)

        -- Colors and icons for separators
        self:addColorMenus(ctx, button)
        reaper.ImGui_Separator(ctx)

        local icon_actions = {
            ["Choose Built-in Icon"] = function()
                C.IconSelector:show(button)
            end,
            ["Choose Image Icon"] = function()
                self:handleIconPathChange(button)
            end,
            ["Remove Icon"] = function()
                self:handleRemoveIcon(button)
            end
        }

        for label, action in pairs(icon_actions) do
            if label ~= "Remove Icon" or (button.icon_path or button.icon_char) then
                if reaper.ImGui_MenuItem(ctx, label) then
                    action()
                    button:saveChanges()
                end
            end
        end
    else
        -- Full options for normal buttons
        if reaper.ImGui_MenuItem(ctx, "Rename") then
            self:handleButtonRename(button)
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

        reaper.ImGui_Separator(ctx)

        -- Right-click behavior (only for normal buttons)
        self:handleRightClickMenu(ctx, button)
        if button.right_click == "dropdown" and reaper.ImGui_MenuItem(ctx, "Edit Dropdown Items") then
            self.dropdown_edit_button = button
        elseif button.right_click == "launch" and reaper.ImGui_MenuItem(ctx, "Choose Right-Click Action...") then
            self:handleRightClickAction(button)
        end

        -- Widget handling (only for normal buttons)
        if WIDGETS then
            if reaper.ImGui_MenuItem(ctx, button.widget and "Change Widget" or "Assign Widget") then
                self:showWidgetSelector(button)
            end

            if button.widget and reaper.ImGui_MenuItem(ctx, "Remove Widget") then
                C.WidgetsManager:removeWidgetFromButton(button)
                button:clearCache()
                button:saveChanges()
            end
        end

        if self.show_widget_selector then
            POPUP_OPEN = self:renderWidgetSelector(ctx)
            self.show_widget_selector = false
        end

        reaper.ImGui_Separator(ctx)

        -- Colors and icons
        self:addColorMenus(ctx, button)
        reaper.ImGui_Separator(ctx)

        local icon_actions = {
            ["Choose Built-in Icon"] = function()
                C.IconSelector:show(button)
            end,
            ["Choose Image Icon"] = function()
                self:handleIconPathChange(button)
            end,
            ["Remove Icon"] = function()
                self:handleRemoveIcon(button)
            end
        }

        for label, action in pairs(icon_actions) do
            if label ~= "Remove Icon" or (button.icon_path or button.icon_char) then
                if reaper.ImGui_MenuItem(ctx, label) then
                    action()
                    button:saveChanges()
                end
            end
        end
    end

    -- Group options (available to both types)
    if active_group and CONFIG.UI.USE_GROUP_LABELS then
        reaper.ImGui_Separator(ctx)
        
        local group_label = #active_group.group_label.text > 0 and "Rename Group" or "Name Group"
        if reaper.ImGui_MenuItem(ctx, group_label) then
            local retval, new_name =
                reaper.GetUserInputs("Group Name", 1, "Group Name:,extrawidth=100", active_group.group_label.text or "")
            if retval then
                active_group.group_label.text = new_name
                button:saveChanges()
            end
        end

        -- Add the split option
        if reaper.ImGui_MenuItem(ctx, "Left/Right Split From This Group", nil, active_group.is_split_point) then
            -- Toggle split point status
            active_group.is_split_point = not active_group.is_split_point
            
            -- If this group is now the split point, clear any other split points
            if active_group.is_split_point then
                local toolbar = button.parent_toolbar
                if toolbar then
                    for _, group in ipairs(toolbar.groups) do
                        if group ~= active_group then
                            group.is_split_point = false
                        end
                    end
                end
            end
            
            button:saveChanges()
        end
    end

    reaper.ImGui_Separator(ctx)

    -- Remove Button option in red color at the bottom
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0xFF4444FF) -- Red color
    if reaper.ImGui_MenuItem(ctx, button:isSeparator() and "Remove Separator" or "Remove Button") then
        self:handleRemoveButton(button)
    end
    reaper.ImGui_PopStyleColor(ctx)

    C.GlobalStyle.reset(ctx, colorCount, styleCount)
    reaper.ImGui_EndPopup(ctx)
    return true
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

-- Button rename handler
function ButtonSettingsMenu:handleButtonRename(button)
    local action_identifier = button.original_text or button.id
    local title = "Rename " .. (button:isSeparator() and "Separator: " or "Action: ") .. action_identifier
    
    local top_line, bottom_line = button.display_text:match("([^%\n]*)\n?(.*)")
    local retval, new_name =
        reaper.GetUserInputs(
        title,
        2,
        "Top Line:,Bottom Line:,extrawidth=100",
        top_line .. "," .. bottom_line
    )

    if not retval then
        return false
    end

    local top_line, bottom_line = new_name:match("([^,]+),([^,]*)")
    button.display_text = top_line .. "\n" .. bottom_line
    
    -- Always show the name when renaming
    button.hide_label = false
    
    if button.clearLayoutCache then
        button:clearLayoutCache()
    else
        button:clearCache()
    end
    button:saveChanges()
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

-- Icon path change handler
function ButtonSettingsMenu:handleIconPathChange(button)
    local retval, icon_path = reaper.GetUserFileNameForRead("", "Select Icon File", "")
    if not retval then
        return false
    end

    -- Normalize path to consistent form
    icon_path = UTILS.normalizeSlashes(icon_path)

    -- Verify the image can be loaded
    local test_texture = reaper.ImGui_CreateImage(icon_path)
    if not test_texture then
        reaper.ShowMessageBox("Failed to load icon: " .. icon_path, "Error", 0)
        return false
    end

    button.icon_path = icon_path
    button.icon_char = nil
    button.icon_font = nil
    if button.clearLayoutCache then
        button:clearLayoutCache()
    else
        button:clearCache()
    end
    C.ButtonManager:clearIconCache()
    button:saveChanges()
    return true
end

-- Remove icon handler
function ButtonSettingsMenu:handleRemoveIcon(button)
    if not (button.icon_path or button.icon_char) then
        return false
    end

    button.icon_path = nil
    button.icon_char = nil
    button.icon_font = nil
    if button.clearLayoutCache then
        button:clearLayoutCache()
    else
        button:clearCache()
    end
    C.ButtonManager:clearIconCache()
    button:saveChanges()
    return true
end

-- Remove button handler
function ButtonSettingsMenu:handleRemoveButton(button)
    local success = C.IniManager:deleteButtonFromIni(button)
    
    if success then
        C.IniManager:reloadToolbars()
    end
    
    return success
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
local function loadColorPresets()
    local presets_path = SCRIPT_PATH .. "User/Button_Color_Presets.lua"
    local success, presets = pcall(dofile, presets_path)
    if success and presets then
        return presets
    else
        -- Fallback presets if file can't be loaded
        local fallback_presets = {
            {name = "Red", bg = "#E68888FF", border = "#D96666FF", hover_bg = "#EDA1A1FF", hover_border = "#E48F8FFF", active_bg = "#DF7A7AFF", active_border = "#D85555FF", text = "#000000FF", icon = "#000000FF"},
            {name = "Orange", bg = "#E6B888FF", border = "#D9A666FF", hover_bg = "#EDC9A1FF", hover_border = "#E4BE8FFF", active_bg = "#DFAB7AFF", active_border = "#D89855FF", text = "#000000FF", icon = "#000000FF"},
            {name = "Yellow", bg = "#E6E688FF", border = "#D9D966FF", hover_bg = "#EDEDA1FF", hover_border = "#E4E48FFF", active_bg = "#DFDF7AFF", active_border = "#D8D855FF", text = "#000000FF", icon = "#000000FF"},
            {name = "Blue", bg = "#88B8E6FF", border = "#66A6D9FF", hover_bg = "#A1C9EDFF", hover_border = "#8FBEE4FF", active_bg = "#7AABDFFF", active_border = "#5598D8FF", text = "#000000FF", icon = "#000000FF"},
            {name = "Purple", bg = "#B888E6FF", border = "#A666D9FF", hover_bg = "#C9A1EDFF", hover_border = "#BE8FE4FF", active_bg = "#AB7ADFFF", active_border = "#9855D8FF", text = "#000000FF", icon = "#000000FF"},
            {name = "Green", bg = "#88E688FF", border = "#66D966FF", hover_bg = "#A1EDA1FF", hover_border = "#8FE48FFF", active_bg = "#7ADF7AFF", active_border = "#55D855FF", text = "#000000FF", icon = "#000000FF"},
            {name = "Cream", bg = "#F5F0E8FF", border = "#E8E0D0FF", hover_bg = "#F8F5F0FF", hover_border = "#ECE5D8FF", active_bg = "#F0EADDFF", active_border = "#E0D5C0FF", text = "#000000FF", icon = "#000000FF"},
            {name = "Dark Gray", bg = "#9999A6FF", border = "#8080A0FF", hover_bg = "#A6A6B3FF", hover_border = "#9999AAFF", active_bg = "#8F8F9CFF", active_border = "#737388FF", text = "#FFFFFFFF", icon = "#FFFFFFFF"}
        }
        
        -- Try to create the file with fallback presets
        local file_content = "-- Button Color Presets\n-- This file contains color preset definitions that users can customize\n-- Each preset includes colors for normal, hover, and active states\n\nreturn {\n"
        for i, preset in ipairs(fallback_presets) do
            file_content = file_content .. string.format(
                "    {name = \"%s\", bg = \"%s\", border = \"%s\", hover_bg = \"%s\", hover_border = \"%s\", active_bg = \"%s\", active_border = \"%s\", text = \"%s\", icon = \"%s\"}%s\n",
                preset.name, preset.bg, preset.border, preset.hover_bg, preset.hover_border, preset.active_bg, preset.active_border, preset.text, preset.icon,
                i < #fallback_presets and "," or ""
            )
        end
        file_content = file_content .. "}"
        
        local file = io.open(presets_path, "w")
        if file then
            file:write(file_content)
            file:close()
        end
        
        return fallback_presets
    end
end

local COLOR_PRESETS = loadColorPresets()

-- Draw color preset circle
function ButtonSettingsMenu:drawColorPresetCircle(ctx, preset, size)
    local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
    local pos_x, pos_y = reaper.ImGui_GetCursorScreenPos(ctx)
    local center_x = pos_x + size * 0.5
    local center_y = pos_y + size * 0.5
    local radius = size * 0.4
    
    -- Convert colors
    local bg_color = COLOR_UTILS.toImGuiColor(preset.bg)
    local border_color = COLOR_UTILS.toImGuiColor(preset.border)
    
    -- Draw background circle
    reaper.ImGui_DrawList_AddCircleFilled(draw_list, center_x, center_y, radius, bg_color)
    
    -- Draw border circle
    reaper.ImGui_DrawList_AddCircle(draw_list, center_x, center_y, radius, border_color, 0, 2.0)
    
    -- Invisible button for interaction
    reaper.ImGui_InvisibleButton(ctx, "preset_" .. preset.name, size, size)
    
    return reaper.ImGui_IsItemClicked(ctx)
end

-- Color menus
function ButtonSettingsMenu:addColorMenus(ctx, button)
    if not reaper.ImGui_BeginMenu(ctx, "Button Colors") then
        return false
    end

    -- Global color settings
    reaper.ImGui_Text(ctx, "Color Options:")
    
    -- Apply to Group toggle
    local apply_to_group_changed, apply_to_group = reaper.ImGui_Checkbox(ctx, "Apply to Group", CONFIG.COLOR_SETTINGS.APPLY_TO_GROUP)
    if apply_to_group_changed then
        CONFIG.COLOR_SETTINGS.APPLY_TO_GROUP = apply_to_group
        -- Save to user config
        CONFIG_MANAGER:saveMainConfig()
    end
    
    -- Link Background/Border toggle
    local link_bg_border_changed, link_bg_border = reaper.ImGui_Checkbox(ctx, "Link Background/Border", CONFIG.COLOR_SETTINGS.LINK_BG_BORDER)
    if link_bg_border_changed then
        CONFIG.COLOR_SETTINGS.LINK_BG_BORDER = link_bg_border
        CONFIG_MANAGER:saveMainConfig()
    end
    
    -- Link Text/Icon toggle
    local link_text_icon_changed, link_text_icon = reaper.ImGui_Checkbox(ctx, "Link Text/Icon", CONFIG.COLOR_SETTINGS.LINK_TEXT_ICON)
    if link_text_icon_changed then
        CONFIG.COLOR_SETTINGS.LINK_TEXT_ICON = link_text_icon
        CONFIG_MANAGER:saveMainConfig()
    end
    
    reaper.ImGui_Separator(ctx)

    -- Color presets section at the top
    reaper.ImGui_Text(ctx, "Color Presets:")
    reaper.ImGui_Separator(ctx)
    
    local preset_size = 24
    local presets_per_row = 4
    
    for i, preset in ipairs(COLOR_PRESETS) do
        if (i - 1) % presets_per_row ~= 0 then
            reaper.ImGui_SameLine(ctx)
        end
        
        if self:drawColorPresetCircle(ctx, preset, preset_size) then
            -- Apply the color preset to the button
            self:applyColorPreset(button, preset)
            -- Close the menu after applying preset
            reaper.ImGui_CloseCurrentPopup(ctx)
        end
        
        if reaper.ImGui_IsItemHovered(ctx) then
            reaper.ImGui_SetTooltip(ctx, preset.name)
        end
    end
    
    reaper.ImGui_Separator(ctx)

    local color_types
    
    -- Separators only need line color, regular buttons need all colors
    if button:isSeparator() then
        color_types = {"Line"}
    else
        color_types = {"Background", "Border", "Text", "Icon"}
    end
    
    for _, color_type in ipairs(color_types) do
        local menu_title = color_type .. " Color"
        local picker_type = color_type:lower()
        
        -- Special handling for border when BG/Border linking is enabled
        if color_type == "Border" and CONFIG.COLOR_SETTINGS.LINK_BG_BORDER then
            menu_title = "Border Offset"
            picker_type = "border_offset"
        end
        
        if reaper.ImGui_BeginMenu(ctx, menu_title) then
            C.ButtonColorEditor:renderColorPicker(ctx, button, picker_type)
            reaper.ImGui_EndMenu(ctx)
        end
    end

    -- Reset all colors option
    if reaper.ImGui_MenuItem(ctx, "Reset All Colors") then
        -- Get target buttons based on global setting
        local targetButtons = {button}
        if CONFIG.COLOR_SETTINGS.APPLY_TO_GROUP and button.parent_group then
            targetButtons = button.parent_group.buttons
        end
        
        -- Reset colors for all target buttons
        for _, targetButton in ipairs(targetButtons) do
            targetButton.custom_color = nil
            targetButton.border_offset = { saturation = 0.0, value = 0.0 }
            targetButton:clearCache()
        end
        
        button:saveChanges()
    end

    reaper.ImGui_EndMenu(ctx)
    return true
end

-- Apply color preset to button
function ButtonSettingsMenu:applyColorPreset(button, preset)
    -- Get target buttons based on "Apply to Group" setting
    local targetButtons = {button}
    if CONFIG.COLOR_SETTINGS.APPLY_TO_GROUP and button.parent_group then
        targetButtons = button.parent_group.buttons
    end
    
    -- Apply colors to all target buttons
    for _, targetButton in ipairs(targetButtons) do
        -- Initialize custom_color if it doesn't exist
        if not targetButton.custom_color then
            targetButton.custom_color = {}
        end
        
        -- Set colors using the correct structure that the system expects
        targetButton.custom_color.background = { normal = preset.bg }
        targetButton.custom_color.border = { normal = preset.border }
        targetButton.custom_color.text = { normal = preset.text or "#FFFFFFFF" }
        targetButton.custom_color.icon = { normal = preset.icon or "#FFFFFFFF" }
        
        -- Add hover and active states
        targetButton.custom_color.hover = {
            background = preset.hover_bg,
            border = preset.hover_border
        }
        targetButton.custom_color.active = {
            background = preset.active_bg,
            border = preset.active_border
        }
        
        -- Clear cache and save changes
        targetButton:clearCache()
        targetButton:saveChanges()
    end
end

-- Widget selector functions (only for normal buttons)
function ButtonSettingsMenu:showWidgetSelector(button)
    local widget_list = C.WidgetsManager:getWidgetList()

    -- Store widgets and button for the selection menu
    self.widget_selection = {
        widget_list = widget_list,
        button = button,
        selected_index = 1,
        is_open = true
    }

    -- Set a flag to open the widget selector popup in the next frame
    self.show_widget_selector = true
end

function ButtonSettingsMenu:renderWidgetSelector(ctx)
    if not self.widget_selection or not self.widget_selection.is_open then
        return false
    end

    local mouseX, mouseY = reaper.ImGui_GetMousePos(ctx)
    reaper.ImGui_SetNextWindowPos(ctx, mouseX, mouseY, reaper.ImGui_Cond_FirstUseEver())
    reaper.ImGui_SetNextWindowSize(ctx, 400, 300, reaper.ImGui_Cond_FirstUseEver())

    local window_flags =
        reaper.ImGui_WindowFlags_NoCollapse() | reaper.ImGui_WindowFlags_NoDocking() |
        reaper.ImGui_WindowFlags_NoResize()
    local colorCount, styleCount = C.GlobalStyle.apply(ctx)
    
    -- Use instance_id for unique window identification
    local window_title = "Select Widget##" .. self.widget_selection.button.instance_id
    local visible, open = reaper.ImGui_Begin(ctx, window_title, true, window_flags)
    self.widget_selection.is_open = open

    if visible then
        reaper.ImGui_TextWrapped(ctx, "Select a widget to assign to this button:")
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_BeginChild(ctx, "WidgetList", 0, -30)

        for i, widget in ipairs(self.widget_selection.widget_list) do
            if reaper.ImGui_Selectable(ctx, widget.display_name, i == self.widget_selection.selected_index) then
                self.widget_selection.selected_index = i
            end

            if reaper.ImGui_IsItemHovered(ctx) then
                reaper.ImGui_BeginTooltip(ctx)
                reaper.ImGui_Text(ctx, widget.display_name)
                reaper.ImGui_Text(ctx, "Type: " .. widget.type)
                if widget.description and widget.description ~= "" then
                    reaper.ImGui_Text(ctx, "Description: " .. widget.description)
                end
                reaper.ImGui_EndTooltip(ctx)
            end
        end

        reaper.ImGui_EndChild(ctx)
        reaper.ImGui_Separator(ctx)

        local btn_width = (reaper.ImGui_GetWindowWidth(ctx) - 20) / 2
        if reaper.ImGui_Button(ctx, "OK", btn_width, 0) then
            local widget = self.widget_selection.widget_list[self.widget_selection.selected_index]
            if C.WidgetsManager:assignWidgetToButton(self.widget_selection.button, widget.name) then
                self.widget_selection.button:clearCache()
                CONFIG_MANAGER:saveToolbarConfig(self.widget_selection.button.parent_toolbar)
                self.widget_selection.is_open = false
            else
                reaper.ShowMessageBox("Failed to assign widget to button", "Error", 0)
            end
        end

        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_Button(ctx, "Cancel", btn_width, 0) then
            self.widget_selection.is_open = false
        end
    end

    reaper.ImGui_End(ctx)
    C.GlobalStyle.reset(ctx, colorCount, styleCount)
    return self.widget_selection.is_open
end

return ButtonSettingsMenu.new()