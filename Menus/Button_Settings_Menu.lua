-- Menus/Button_Settings_Menu.lua

local ButtonSettingsMenu = {}
ButtonSettingsMenu.__index = ButtonSettingsMenu

function ButtonSettingsMenu.new()
    local self = setmetatable({}, ButtonSettingsMenu)

    return self
end

function ButtonSettingsMenu:handleButtonSettingsMenu(ctx, button, active_group)
    if not reaper.ImGui_BeginPopup(ctx, "button_settings_menu_" .. button.id) then
        return false
    end

    local colorCount, styleCount = C.GlobalStyle.apply(ctx, {styles = false})

    -- Basic button options
    if reaper.ImGui_MenuItem(ctx, "Rename") then
        self:handleButtonRename(button)
    end

    if reaper.ImGui_MenuItem(ctx, "Hide Name", nil, button.hide_label) then
        button.hide_label = not button.hide_label
        button:clearCache()
        button:saveChanges()
    end

    if reaper.ImGui_BeginMenu(ctx, "Text Alignment") then
        self:handleAlignmentMenu(ctx, button)
        reaper.ImGui_EndMenu(ctx)
    end

    reaper.ImGui_Separator(ctx)

    self:handleRightClickMenu(ctx, button)
    if button.right_click == "dropdown" and reaper.ImGui_MenuItem(ctx, "Edit Dropdown Items") then
        self.dropdown_edit_button = button
    elseif button.right_click == "launch" and reaper.ImGui_MenuItem(ctx, "Choose Right-Click Action...") then
        self:handleRightClickAction(button)
    end

    -- Widget handling
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

    -- Group options
    if active_group and CONFIG.UI.USE_GROUP_LABELS then
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

        reaper.ImGui_Separator(ctx)
    end

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

    C.GlobalStyle.reset(ctx, colorCount, styleCount)
    reaper.ImGui_EndPopup(ctx)
    return true
end

-- Right-click behavior submenu
function ButtonSettingsMenu:handleRightClickMenu(ctx, button)
    if not reaper.ImGui_BeginMenu(ctx, "Right-Click Behavior") then
        return false
    end

    local options = {
        ["Arm Command"] = "arm",
        ["Show Dropdown"] = "dropdown",
        ["Launch Action"] = "launch",  -- Add the new option
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
    -- Instead of looking up the command, use the original_text which contains the action ID
    local action_identifier = button.original_text or button.id
    local title = "Rename Action: " .. action_identifier
    
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
    
    button:clearCache()
    button:saveChanges()
    return true
end

-- Text alignment submenu
function ButtonSettingsMenu:handleAlignmentMenu(ctx, button)
    local alignments = {"left", "center", "right"}
    for _, align in ipairs(alignments) do
        if reaper.ImGui_MenuItem(ctx, align:gsub("^%l", string.upper), nil, button.alignment == align) then
            button.alignment = align
            button:clearCache()
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
    button:clearCache()
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
    button:clearCache()
    C.ButtonManager:clearIconCache()
    button:saveChanges()
    return true
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

-- Color menus
function ButtonSettingsMenu:addColorMenus(ctx, button)
    if not reaper.ImGui_BeginMenu(ctx, "Button Colors") then
        return false
    end

    local color_types = {"Background", "Border", "Text", "Icon"}
    for _, color_type in ipairs(color_types) do
        if reaper.ImGui_BeginMenu(ctx, color_type .. " Color") then
            C.ButtonColorEditor:renderColorPicker(ctx, button, color_type:lower())
            reaper.ImGui_EndMenu(ctx)
        end
    end

    -- Reset all colors option
    if reaper.ImGui_MenuItem(ctx, "Reset All Colors") then
        button.custom_color = nil
        button:clearCache()
        button:saveChanges()
    end

    reaper.ImGui_EndMenu(ctx)
    return true
end

-- Widget selector functions
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
    local visible, open = reaper.ImGui_Begin(ctx, "Select Widget", true, window_flags)
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