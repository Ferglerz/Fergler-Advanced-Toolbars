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

function ButtonContextMenuManager:handleButtonRename(button, saveConfig)
    local retval, new_name =
        self.r.GetUserInputs("Rename Toolbar Item", 1, "New Name:,extrawidth=100", button.display_text)
    if not retval then
        return
    end

    button.display_text = new_name
    button:clearCache()
    saveConfig()
end

function ButtonContextMenuManager:handleAlignmentMenu(ctx, button, saveConfig)
    for _, align in ipairs({{"Left", "left"}, {"Center", "center"}, {"Right", "right"}}) do
        if self.r.ImGui_MenuItem(ctx, align[1], nil, button.alignment == align[2]) then
            button.alignment = align[2]
            button:clearCache()
            saveConfig()
        end
    end
end

function ButtonContextMenuManager:handleIconPathChange(button, button_manager, saveConfig)
    local retval, icon_path = self.r.GetUserFileNameForRead("", "Select Icon File", "")
    if not retval then
        return
    end

    -- Normalize path to consistent form
    icon_path = icon_path:gsub("\\", "/")

    if not self.r.ImGui_CreateImage(icon_path) then
        self.r.ShowMessageBox("Failed to load icon: " .. icon_path, "Error", 0)
        return
    end

    button.icon_path = icon_path
    button.icon_char = nil
    button:clearCache()
    button_manager:clearIconCache()
    saveConfig()
end

function ButtonContextMenuManager:handleRemoveIcon(button, button_manager, saveConfig)
    button.icon_path = nil
    button.icon_char = nil
    button:clearCache()
    button_manager:clearIconCache()
    saveConfig()
end

function ButtonContextMenuManager:handleChangeAction(ctx, button, button_manager, menu_path, saveConfig)
    local retval, action_id = self.r.GetUserInputs("Change Action", 1, "Action ID:,extrawidth=100", button.id)
    if not retval then
        return
    end

    local cmdID = button_manager:getCommandID(action_id)
    if not cmdID then
        self.r.ShowMessageBox("Invalid action ID", "Error", 0)
        return
    end

    local action_name = self.r.CF_GetCommandText(0, cmdID)
    if not action_name or action_name == "" then
        self.r.ShowMessageBox("Action not found", "Error", 0)
        return
    end

    local file = io.open(menu_path, "r")
    if not file then
        self.r.ShowMessageBox("Failed to read reaper-menu.ini", "Error", 0)
        return
    end

    local content = file:read("*all")
    file:close()

    local section_start =
        content:find("%[" .. button.toolbar_section:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1") .. "%]")
    if not section_start then
        self.r.ShowMessageBox("Could not find toolbar section in reaper-menu.ini", "Error", 0)
        return
    end

    local section_end = content:find("%[", section_start + 1) or #content
    local section = content:sub(section_start, section_end - 1)

    local new_section, replacements =
        section:gsub("(item_[0-9]+)=" .. button.id .. "[^\n]*", "%1=" .. action_id .. " " .. button.original_text)
    if replacements == 0 then
        self.r.ShowMessageBox("Could not find button in toolbar section", "Error", 0)
        return
    end

    file = io.open(menu_path, "w")
    if not file then
        self.r.ShowMessageBox("Failed to write to reaper-menu.ini", "Error", 0)
        return
    end

    file:write(content:sub(1, section_start - 1) .. new_section .. content:sub(section_end))
    file:close()

    button.id = action_id
    button.property_key = self.createPropertyKey(action_id, button.original_text)
    button:clearCache()

    self.r.ShowMessageBox(string.format('Action changed to: "%s"', action_name), "Success", 0)
    saveConfig()
end

function ButtonContextMenuManager:handleButtonContextMenu(
    ctx,
    button,
    active_group,
    fontIconSelector,
    color_manager,
    button_manager,
    current_toolbar,
    menu_path,
    saveConfig,
    focusArrangeCallback)
    
    if not self.r.ImGui_BeginPopup(ctx, "context_menu_" .. button.id) then
        return false
    end

    local menu_items = {
        {label = "Hide Label", checked = button.hide_label, fn = function()
            button.hide_label = not button.hide_label
            button:clearCache()
            saveConfig()
        end},
    }

    if active_group and CONFIG.UI.USE_GROUP_LABELS then
        local group_label = #active_group.label.text > 0 and "Rename Group" or "Name Group"
        table.insert(menu_items, {label = group_label, fn = function()
            local retval, new_name = self.r.GetUserInputs("Group Name", 1, "Group Name:,extrawidth=100", active_group.label.text or "")
            if retval then
                active_group.label.text = new_name
                saveConfig()
            end
        end})
        table.insert(menu_items, {separator = true})
    end

    table.insert(menu_items, {label = "Rename", fn = function()
        self:handleButtonRename(button, saveConfig)
    end})

    if self.r.ImGui_BeginMenu(ctx, "Text Alignment") then
        self:handleAlignmentMenu(ctx, button, saveConfig)
        self.r.ImGui_EndMenu(ctx)
    end

    if self.r.ImGui_BeginMenu(ctx, "Button Color") then
        color_manager:renderColorPicker(ctx, button, current_toolbar, saveConfig)
        self.r.ImGui_EndMenu(ctx)
    end

    table.insert(menu_items, {label = "Choose Built-in Icon", fn = function()
        fontIconSelector:show(button)
    end})

    table.insert(menu_items, {label = "Choose Image Icon", fn = function()
        self:handleIconPathChange(button, button_manager, saveConfig)
    end})

    if button.icon_path or button.icon_char then
        table.insert(menu_items, {label = "Remove Icon", fn = function()
            self:handleRemoveIcon(button, button_manager, saveConfig)
        end})
    end

    table.insert(menu_items, {label = "Change Action", fn = function()
        self:handleChangeAction(ctx, button, button_manager, menu_path, saveConfig)
    end})

    for _, item in ipairs(menu_items) do
        if item.separator then
            self.r.ImGui_Separator(ctx)
        else
            if self.r.ImGui_MenuItem(ctx, item.label, nil, item.checked) then
                item.fn()
                if focusArrangeCallback then
                    focusArrangeCallback()
                end
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
