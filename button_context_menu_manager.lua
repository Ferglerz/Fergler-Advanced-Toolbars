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

function ButtonContextMenuManager:handleRightClickMenu(ctx, button, saveConfig)
    if not self.r.ImGui_BeginMenu(ctx, "Right-Click Behavior") then
        return false
    end

    local behaviors = {
        {name = "Arm Command", value = "arm"},
        {name = "Show Dropdown", value = "dropdown"},
        {name = "No Action", value = "none"}
    }

    local changed = false
    for _, behavior in ipairs(behaviors) do
        if self.r.ImGui_MenuItem(ctx, behavior.name, nil, button.right_click == behavior.value) then
            button.right_click = behavior.value
            saveConfig()
            changed = true
        end
    end

    self.r.ImGui_EndMenu(ctx)
    return changed
end

function ButtonContextMenuManager:handleDropdownEditor(ctx, button, saveConfig)
    if button.right_click ~= "dropdown" then
        return false
    end

    if self.r.ImGui_MenuItem(ctx, "Edit Dropdown Items") then
        -- Store reference to the button for the dropdown editor
        self.dropdown_edit_button = button
        -- This will trigger the dropdown editor to be shown
        return true
    end

    return false
end

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

function ButtonContextMenuManager:handleAlignmentMenu(ctx, button, saveConfig)
    local alignments = {
        {name = "Left", value = "left"},
        {name = "Center", value = "center"},
        {name = "Right", value = "right"}
    }

    local changed = false
    for _, align in ipairs(alignments) do
        if self.r.ImGui_MenuItem(ctx, align.name, nil, button.alignment == align.value) then
            button.alignment = align.value
            button:clearCache()
            saveConfig()
            changed = true
        end
    end

    return changed
end

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

function ButtonContextMenuManager:validateActionChange(button_state, action_id, menu_path)
    -- Verify command ID
    local cmdID = button_state:getCommandID(action_id)
    if not cmdID then
        self.r.ShowMessageBox("Invalid action ID", "Error", 0)
        return false, nil, nil
    end

    -- Action name is used later for display purposes, so keep it
    local action_name = self.r.CF_GetCommandText(0, cmdID)
    if not action_name or action_name == "" then
        self.r.ShowMessageBox("Action not found", "Error", 0)
        return false, nil, nil
    end

    -- Verify menu file
    local file = io.open(menu_path, "r")
    if not file then
        self.r.ShowMessageBox("Failed to read reaper-menu.ini", "Error", 0)
        return false, nil, nil
    end

    local content = file:read("*all")
    file:close()

    return true, cmdID, content
end

function ButtonContextMenuManager:locateButtonInMenu(content, button)
    local section_pattern = "%[" .. button.toolbar_section:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1") .. "%]"
    local section_start = content:find(section_pattern)

    if not section_start then
        self.r.ShowMessageBox("Could not find toolbar section in reaper-menu.ini", "Error", 0)
        return false, nil, nil
    end

    local section_end = content:find("%[", section_start + 1) or #content
    local section = content:sub(section_start, section_end - 1)

    local button_pattern = "(item_[0-9]+)=" .. button.id .. "[^\n]*"
    local new_section = section:gsub(button_pattern, "%1=%s%s")

    -- Check if replacements happened without using the replacements variable
    if new_section == section then
        self.r.ShowMessageBox("Could not find button in toolbar section", "Error", 0)
        return false, nil, nil
    end

    return true, new_section, section_start, section_end
end

function ButtonContextMenuManager:updateMenuFile(menu_path, content, section_start, section_end, new_section)
    local file = io.open(menu_path, "w")
    if not file then
        self.r.ShowMessageBox("Failed to write to reaper-menu.ini", "Error", 0)
        return false
    end

    file:write(content:sub(1, section_start - 1) .. new_section .. content:sub(section_end))
    file:close()
    return true
end

function ButtonContextMenuManager:handleChangeAction(ctx, button, button_state, menu_path, saveConfig)
    local retval, action_id = self.r.GetUserInputs("Change Action", 1, "Action ID:,extrawidth=100", button.id)
    if not retval then
        return false
    end

    -- Validate action and get menu content
    local valid, cmdID, content = self:validateActionChange(button_state, action_id, menu_path)
    if not valid then
        return false
    end

    -- Locate button in menu file
    local found, new_section, section_start, section_end = self:locateButtonInMenu(content, button)
    if not found then
        return false
    end

    -- Write updated menu file
    if not self:updateMenuFile(menu_path, content, section_start, section_end, new_section) then
        return false
    end

    -- Update button
    button.id = action_id
    button.property_key = self.createPropertyKey(action_id, button.original_text)
    button:clearCache()

    -- Show success message
    local action_name = self.r.CF_GetCommandText(0, cmdID)
    self.r.ShowMessageBox(string.format('Action changed to: "%s"', action_name), "Success", 0)
    saveConfig()
    return true
end

-- Create all menu items for the context menu
function ButtonContextMenuManager:createContextMenuItems(button, active_group, saveConfig)
    local menu_items = {}

    -- Hide label toggle
    table.insert(
        menu_items,
        {
            label = "Hide Label",
            checked = button.hide_label,
            fn = function()
                button.hide_label = not button.hide_label
                button:clearCache()
                saveConfig()
            end
        }
    )

    -- Group label (if in a group)
    if active_group and CONFIG.UI.USE_GROUP_LABELS then
        local group_label = #active_group.label.text > 0 and "Rename Group" or "Name Group"
        table.insert(
            menu_items,
            {
                label = group_label,
                fn = function()
                    local retval, new_name =
                        self.r.GetUserInputs(
                        "Group Name",
                        1,
                        "Group Name:,extrawidth=100",
                        active_group.label.text or ""
                    )
                    if retval then
                        active_group.label.text = new_name
                        saveConfig()
                    end
                end
            }
        )
        table.insert(menu_items, {separator = true})
    end

    -- Rename button
    table.insert(
        menu_items,
        {
            label = "Rename",
            fn = function()
                self:handleButtonRename(button, saveConfig)
            end
        }
    )

    return menu_items
end

function ButtonContextMenuManager:addColorMenus(ctx, button, button_color_editor, current_toolbar, saveConfig)
    if not self.r.ImGui_BeginMenu(ctx, "Button Colors") then
        return false
    end

    -- Color submenus
    local color_types = {
        {"Background Color", "background"},
        {"Border Color", "border"},
        {"Text Color", "text"},
        {"Icon Color", "icon"}
    }

    for _, color_info in ipairs(color_types) do
        if self.r.ImGui_BeginMenu(ctx, color_info[1]) then
            button_color_editor:renderColorPicker(ctx, button, current_toolbar, saveConfig, color_info[2])
            self.r.ImGui_EndMenu(ctx)
        end
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

function ButtonContextMenuManager:addIconMenuItems(menu_items, button, button_state, font_icon_selector, saveConfig)
    -- Choose built-in icon
    table.insert(
        menu_items,
        {
            label = "Choose Built-in Icon",
            fn = function()
                font_icon_selector:show(button)
            end
        }
    )

    -- Choose image icon
    table.insert(
        menu_items,
        {
            label = "Choose Image Icon",
            fn = function()
                self:handleIconPathChange(button, button_state, saveConfig)
            end
        }
    )

    -- Remove icon (if exists)
    if button.icon_path or button.icon_char then
        table.insert(
            menu_items,
            {
                label = "Remove Icon",
                fn = function()
                    self:handleRemoveIcon(button, button_state, saveConfig)
                end
            }
        )
    end
end

function ButtonContextMenuManager:handleButtonContextMenu(
    ctx,
    button,
    active_group,
    font_icon_selector,
    button_color_editor,
    button_state,
    current_toolbar,
    menu_path,
    saveConfig,
    focusArrangeCallback)
    if not self.r.ImGui_BeginPopup(ctx, "context_menu_" .. button.id) then
        return false
    end

    -- Create menu items array
    local menu_items = self:createContextMenuItems(button, active_group, saveConfig)

    -- Add alignment submenu
    if self.r.ImGui_BeginMenu(ctx, "Text Alignment") then
        self:handleAlignmentMenu(ctx, button, saveConfig)
        self.r.ImGui_EndMenu(ctx)
    end

    -- Add Right-Click Behavior submenu
    self:handleRightClickMenu(ctx, button, saveConfig)

    -- If right-click is set to dropdown, add Editor option
    if button.right_click == "dropdown" then
        if self:handleDropdownEditor(ctx, button, saveConfig) then
            -- Handle the dropdown editor being requested
            self.show_dropdown_editor = true
        end
    end

    -- Add color submenus
    self:addColorMenus(ctx, button, button_color_editor, current_toolbar, saveConfig)

    -- Add icon menu items
    self:addIconMenuItems(menu_items, button, button_state, font_icon_selector, saveConfig)

    -- Add action menu item
    table.insert(
        menu_items,
        {
            label = "Change Action",
            fn = function()
                self:handleChangeAction(ctx, button, button_state, menu_path, saveConfig)
            end
        }
    )

    -- Render all menu items
    for _, item in ipairs(menu_items) do
        if item.separator then
            self.r.ImGui_Separator(ctx)
        elseif self.r.ImGui_MenuItem(ctx, item.label, nil, item.checked) then
            item.fn()
            if focusArrangeCallback then
                focusArrangeCallback()
            end
        end
    end

    self.r.ImGui_EndPopup(ctx)
    return true
end

return {
    new = function(reaper, helpers, createPropertyKey)
        return ButtonContextMenuManager.new(reaper, helpers, createPropertyKey)
    end
}
