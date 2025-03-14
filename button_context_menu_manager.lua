-- button_context_menu_manager.lua

local ButtonContextMenuManager = {}
ButtonContextMenuManager.__index = ButtonContextMenuManager

function ButtonContextMenuManager.new(reaper, helpers, createPropertyKey)
    local self = setmetatable({}, ButtonContextMenuManager)
    self.r = reaper
    self.helpers = helpers
    self.createPropertyKey = createPropertyKey
    return self
end

function ButtonContextMenuManager:handleButtonContextMenu(
    ctx,
    button,
    active_group,
    managers,
    current_toolbar,
    callbacks)
    if not self.r.ImGui_BeginPopup(ctx, "context_menu_" .. button.id) then
        return false
    end

    -- Unpack managers for easier access
    local font_icon_selector = managers.font_icon_selector
    local button_color_editor = managers.button_color_editor
    local button_state = managers.state
    local presets = managers.presets

    -- Unpack callbacks
    local saveConfig = callbacks.saveConfig
    local focusArrangeCallback = callbacks.focusArrange

    -- Basic button options
    if self.r.ImGui_MenuItem(ctx, "Hide Label", nil, button.hide_label) then
        button.hide_label = not button.hide_label
        button:clearCache()
        saveConfig()
        if focusArrangeCallback then
            focusArrangeCallback()
        end
    end

    -- Group label (if in a group)
    if active_group and CONFIG.UI.USE_GROUP_LABELS then
        local group_label = #active_group.label.text > 0 and "Rename Group" or "Name Group"
        if self.r.ImGui_MenuItem(ctx, group_label) then
            local retval, new_name =
                self.r.GetUserInputs("Group Name", 1, "Group Name:,extrawidth=100", active_group.label.text or "")
            if retval then
                active_group.label.text = new_name
                saveConfig()
            end
            if focusArrangeCallback then
                focusArrangeCallback()
            end
        end
        self.r.ImGui_Separator(ctx)
    end

    -- Rename button
    if self.r.ImGui_MenuItem(ctx, "Rename Button") then
        self:handleButtonRename(button, saveConfig)
        if focusArrangeCallback then
            focusArrangeCallback()
        end
    end

    -- Text alignment submenu
    if self.r.ImGui_BeginMenu(ctx, "Text Alignment") then
        self:handleAlignmentMenu(ctx, button, saveConfig)
        self.r.ImGui_EndMenu(ctx)
    end

    -- Colors submenu
    self:addColorMenus(ctx, button, button_color_editor, current_toolbar, saveConfig)

    self.r.ImGui_Separator(ctx)

    -- Right-click behavior submenu
    self:handleRightClickMenu(ctx, button, saveConfig)

    -- Dropdown editor (if right-click is set to dropdown)
    if button.right_click == "dropdown" then
        if self.r.ImGui_MenuItem(ctx, "Edit Dropdown Items") then
            self.dropdown_edit_button = button
            self.show_dropdown_editor = true
            if focusArrangeCallback then
                focusArrangeCallback()
            end
        end
    end

    self.r.ImGui_Separator(ctx)

    -- Icon options
    if self.r.ImGui_MenuItem(ctx, "Choose Built-in Icon") then
        font_icon_selector:show(button)
        if focusArrangeCallback then
            focusArrangeCallback()
        end
    end

    if self.r.ImGui_MenuItem(ctx, "Choose Image Icon") then
        self:handleIconPathChange(button, button_state, saveConfig)
        if focusArrangeCallback then
            focusArrangeCallback()
        end
    end

    if (button.icon_path or button.icon_char) and self.r.ImGui_MenuItem(ctx, "Remove Icon") then
        self:handleRemoveIcon(button, button_state, saveConfig)
        if focusArrangeCallback then
            focusArrangeCallback()
        end
    end

    -- Preset options (if presets provided)
    if presets then
        self.r.ImGui_Separator(ctx)
        if self.r.ImGui_MenuItem(ctx, button.preset and "Change Preset" or "Assign Preset") then
            self:showPresetSelector(button, presets, saveConfig)
            if focusArrangeCallback then
                focusArrangeCallback()
            end
        end

        if button.preset and self.r.ImGui_MenuItem(ctx, "Remove Preset") then
            presets:removePresetFromButton(button)
            button:clearCache()
            saveConfig()
            if focusArrangeCallback then
                focusArrangeCallback()
            end
        end
    end

    -- Handle preset selector if needed
    if self.show_preset_selector then
        POPUP_OPEN = self:renderPresetSelector(ctx)
        self.show_preset_selector = false
    end

    self.r.ImGui_EndPopup(ctx)
    return true
end

-- Right-click behavior submenu
function ButtonContextMenuManager:handleRightClickMenu(ctx, button, saveConfig)
    if not self.r.ImGui_BeginMenu(ctx, "Right-Click Behavior") then
        return false
    end

    if self.r.ImGui_MenuItem(ctx, "Arm Command", nil, button.right_click == "arm") then
        button.right_click = "arm"
        saveConfig()
    end

    if self.r.ImGui_MenuItem(ctx, "Show Dropdown", nil, button.right_click == "dropdown") then
        button.right_click = "dropdown"
        saveConfig()
    end

    if self.r.ImGui_MenuItem(ctx, "No Action", nil, button.right_click == "none") then
        button.right_click = "none"
        saveConfig()
    end

    self.r.ImGui_EndMenu(ctx)
    return true
end

-- Button rename handler
function ButtonContextMenuManager:handleButtonRename(button, saveConfig)
    local top_line, bottom_line = button.display_text:match("([^%\n]*)\n?(.*)")
    local retval, new_name =
        self.r.GetUserInputs(
        "Rename Toolbar Item",
        2,
        "Top Line:,Bottom Line:,extrawidth=100",
        top_line .. "," .. bottom_line
    )
    if not retval then
        return false
    end

    local top_line, bottom_line = new_name:match("([^,]+),([^,]*)")
    button.display_text = top_line .. "\n" .. bottom_line
    button:clearCache()
    saveConfig()
    return true
end

-- Text alignment submenu
function ButtonContextMenuManager:handleAlignmentMenu(ctx, button, saveConfig)
    if self.r.ImGui_MenuItem(ctx, "Left", nil, button.alignment == "left") then
        button.alignment = "left"
        button:clearCache()
        saveConfig()
    end

    if self.r.ImGui_MenuItem(ctx, "Center", nil, button.alignment == "center") then
        button.alignment = "center"
        button:clearCache()
        saveConfig()
    end

    if self.r.ImGui_MenuItem(ctx, "Right", nil, button.alignment == "right") then
        button.alignment = "right"
        button:clearCache()
        saveConfig()
    end
end

-- Icon path change handler
function ButtonContextMenuManager:handleIconPathChange(button, button_state, saveConfig)
    local retval, icon_path = self.r.GetUserFileNameForRead("", "Select Icon File", "")
    if not retval then
        return false
    end

    -- Normalize path to consistent form
    icon_path = icon_path:gsub("\\", "/")

    -- Verify the image can be loaded
    local test_texture = self.r.ImGui_CreateImage(icon_path)
    if not test_texture then
        self.r.ShowMessageBox("Failed to load icon: " .. icon_path, "Error", 0)
        return false
    end

    button.icon_path = icon_path
    button.icon_char = nil
    button.icon_font = nil
    button:clearCache()
    button_state:clearIconCache()
    saveConfig()
    return true
end

-- Remove icon handler
function ButtonContextMenuManager:handleRemoveIcon(button, button_state, saveConfig)
    if not (button.icon_path or button.icon_char) then
        return false
    end

    button.icon_path = nil
    button.icon_char = nil
    button.icon_font = nil
    button:clearCache()
    button_state:clearIconCache()
    saveConfig()
    return true
end

-- Color menus
function ButtonContextMenuManager:addColorMenus(ctx, button, button_color_editor, current_toolbar, saveConfig)
    if not self.r.ImGui_BeginMenu(ctx, "Button Colors") then
        return false
    end

    -- Color submenus
    if self.r.ImGui_BeginMenu(ctx, "Background Color") then
        button_color_editor:renderColorPicker(ctx, button, current_toolbar, saveConfig, "background")
        self.r.ImGui_EndMenu(ctx)
    end

    if self.r.ImGui_BeginMenu(ctx, "Border Color") then
        button_color_editor:renderColorPicker(ctx, button, current_toolbar, saveConfig, "border")
        self.r.ImGui_EndMenu(ctx)
    end

    if self.r.ImGui_BeginMenu(ctx, "Text Color") then
        button_color_editor:renderColorPicker(ctx, button, current_toolbar, saveConfig, "text")
        self.r.ImGui_EndMenu(ctx)
    end

    if self.r.ImGui_BeginMenu(ctx, "Icon Color") then
        button_color_editor:renderColorPicker(ctx, button, current_toolbar, saveConfig, "icon")
        self.r.ImGui_EndMenu(ctx)
    end

    -- Reset all colors option
    if self.r.ImGui_MenuItem(ctx, "Reset All Colors") then
        button.custom_color = nil
        button:clearCache()
        saveConfig()
    end

    self.r.ImGui_EndMenu(ctx)
    return true
end

-- Preset selector functions
function ButtonContextMenuManager:showPresetSelector(button, presets, saveConfig)
    local presets = presets:getPresetList()
    if #presets == 0 then
        self.r.ShowMessageBox("No presets found. Place preset files in the 'presets' folder.", "Info", 0)
        return
    end

    -- Store presets and button for the selection menu
    self.preset_selection = {
        presets,
        button,
        presets,
        saveConfig,
        selected_index = 1,
        is_open = true
    }

    -- Set a flag to open the preset selector popup in the next frame
    self.show_preset_selector = true
end

function ButtonContextMenuManager:renderPresetSelector(ctx)
    if not self.preset_selection or not self.preset_selection.is_open then
        return false
    end

    local selection = self.preset_selection

    -- Set window position near the mouse
    local mouseX, mouseY = self.r.ImGui_GetMousePos(ctx)
    self.r.ImGui_SetNextWindowPos(ctx, mouseX, mouseY, self.r.ImGui_Cond_FirstUseEver())

    -- Set window size
    self.r.ImGui_SetNextWindowSize(ctx, 400, 300, self.r.ImGui_Cond_FirstUseEver())

    -- Window flags
    local window_flags =
        self.r.ImGui_WindowFlags_NoCollapse() | self.r.ImGui_WindowFlags_NoDocking() |
        self.r.ImGui_WindowFlags_NoResize()

    -- Begin window
    local visible, open = self.r.ImGui_Begin(ctx, "Select Preset", true, window_flags)
    selection.is_open = open

    if visible then
        -- Display instructions
        self.r.ImGui_TextWrapped(ctx, "Select a preset to assign to this button:")
        self.r.ImGui_Separator(ctx)

        -- Create a child window for the scrollable list
        self.r.ImGui_BeginChild(ctx, "PresetList", 0, -30)

        for i, preset in ipairs(selection.presets) do
            local is_selected = (i == selection.selected_index)

            -- Create selectable for each preset
            if self.r.ImGui_Selectable(ctx, preset.display_name, is_selected) then
                selection.selected_index = i
            end

            -- If item is hovered, show tooltip with more info
            if self.r.ImGui_IsItemHovered(ctx) then
                self.r.ImGui_BeginTooltip(ctx)
                self.r.ImGui_Text(ctx, preset.display_name)
                self.r.ImGui_Text(ctx, "Type: " .. preset.type)
                if preset.description and preset.description ~= "" then
                    self.r.ImGui_Text(ctx, "Description: " .. preset.description)
                end
                self.r.ImGui_EndTooltip(ctx)
            end
        end

        self.r.ImGui_EndChild(ctx)

        self.r.ImGui_Separator(ctx)

        -- Buttons at the bottom
        local btn_width = (self.r.ImGui_GetWindowWidth(ctx) - 20) / 2

        if self.r.ImGui_Button(ctx, "OK", btn_width, 0) then
            local preset = selection.presets[selection.selected_index]
            if selection.presets:assignPresetToButton(selection.button, preset.name) then
                selection.button:clearCache()
                selection.saveConfig()
                selection.is_open = false
            else
                self.r.ShowMessageBox("Failed to assign preset to button", "Error", 0)
            end
        end

        self.r.ImGui_SameLine(ctx)

        if self.r.ImGui_Button(ctx, "Cancel", btn_width, 0) then
            selection.is_open = false
        end
    end

    self.r.ImGui_End(ctx)

    return selection.is_open
end

return {
    new = function(reaper, helpers, createPropertyKey)
        return ButtonContextMenuManager.new(reaper, helpers, createPropertyKey)
    end
}
