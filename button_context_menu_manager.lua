-- button_context_menu_manager.lua
local CONFIG = require "Advanced Toolbars - User Config"

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

    if retval then
        button.display_text = new_name
        button:clearCache()
        saveConfig()
    end
end

function ButtonContextMenuManager:handleAlignmentMenu(ctx, button, saveConfig)
    local alignments = {
        {name = "Left", value = "left"},
        {name = "Center", value = "center"},
        {name = "Right", value = "right"}
    }

    for _, align in ipairs(alignments) do
        if self.r.ImGui_MenuItem(ctx, align.name, nil, button.alignment == align.value) then
            button.alignment = align.value
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

    local test_texture = self.r.ImGui_CreateImage(icon_path)
    if not test_texture then
        self.r.ShowMessageBox("Failed to load icon: " .. icon_path, "Error", 0)
        return
    end

    button_manager:clearIconCache()
    button.icon_path = icon_path
    button.icon_char = nil
    button:clearCache()
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
    -- Get new action ID from user
    local retval, action_id = self.r.GetUserInputs("Change Action", 1, "Action ID:,extrawidth=100", button.id)
    if not retval then
        return
    end

    -- Validate the new action ID and get its name
    local cmdID = button_manager:getCommandID(action_id)
    if not cmdID then
        self.r.ShowMessageBox("Invalid action ID", "Error", 0)
        return
    end

    -- Get action name and verify it exists
    local action_name = self.r.CF_GetCommandText(0, cmdID)
    if not action_name or action_name == "" then
        self.r.ShowMessageBox("Action not found", "Error", 0)
        return
    end

    -- Read reaper-menu.ini
    local file = io.open(menu_path, "r")
    if not file then
        self.r.ShowMessageBox("Failed to read reaper-menu.ini", "Error", 0)
        return
    end

    local content = file:read("*all")
    file:close()

    -- Replace the action in the file
    local escaped_section = button.toolbar_section:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
    local section_pattern = "%[" .. escaped_section .. "%]"

    local section_start = content:find(section_pattern)
    if not section_start then
        self.r.ShowMessageBox("Could not find toolbar section in reaper-menu.ini", "Error", 0)
        return
    end

    local section_end = content:find("%[", section_start + 1) or #content
    local section = content:sub(section_start, section_end - 1)

    -- Replace the specific button line
    local button_line_pattern = "(item_[0-9]+)=" .. button.id .. "[^\n]*"
    local new_line = "%1=" .. action_id .. " " .. button.original_text

    local new_section, replacements = section:gsub(button_line_pattern, new_line)
    if replacements == 0 then
        self.r.ShowMessageBox("Could not find button in toolbar section", "Error", 0)
        return
    end

    -- Write back to file
    content = content:sub(1, section_start - 1) .. new_section .. content:sub(section_end)
    file = io.open(menu_path, "w")
    if not file then
        self.r.ShowMessageBox("Failed to write to reaper-menu.ini", "Error", 0)
        return
    end

    file:write(content)
    file:close()

    -- Update button properties
    button.id = action_id
    button.property_key = self.createPropertyKey(action_id, button.original_text)
    button:clearCache()

    -- Inform user
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
    saveConfig)
    if not self.r.ImGui_BeginPopup(ctx, "context_menu_" .. button.id) then
        return
    end

    -- Hide/show label option
    if self.r.ImGui_MenuItem(ctx, "Hide Label", nil, button.hide_label) then
        button.hide_label = not button.hide_label
        button:clearCache()
        saveConfig()
    end

    -- Group management
    if active_group and CONFIG.UI.USE_GROUP_LABELS then
        if self.r.ImGui_MenuItem(ctx, #active_group.label.text > 0 and "Rename Group" or "Name Group") then
            local retval, new_name =
                self.r.GetUserInputs("Group Name", 1, "Group Name:,extrawidth=100", active_group.label.text or "")
            if retval then
                active_group.label.text = new_name
                saveConfig()
            end
        end
        self.r.ImGui_Separator(ctx)
    end

    -- Button operations menu items
    if self.r.ImGui_MenuItem(ctx, "Rename") then
        self:handleButtonRename(button, saveConfig)
    end

    if self.r.ImGui_BeginMenu(ctx, "Text Alignment") then
        self:handleAlignmentMenu(ctx, button, saveConfig)
        self.r.ImGui_EndMenu(ctx)
    end

    -- Color menu
    if self.r.ImGui_BeginMenu(ctx, "Button Color") then
        color_manager:renderColorPicker(ctx, button, current_toolbar, saveConfig)
        self.r.ImGui_EndMenu(ctx)
    end

    -- Icon operations
    if self.r.ImGui_MenuItem(ctx, "Choose Built-in Icon") then
        fontIconSelector:show(button)
    end

    if self.r.ImGui_MenuItem(ctx, "Choose Image Icon") then
        self:handleIconPathChange(button, button_manager, saveConfig)
    end

    if button.icon_path or button.icon_char then
        if self.r.ImGui_MenuItem(ctx, "Remove Icon") then
            self:handleRemoveIcon(button, button_manager, saveConfig)
        end
    end

    if self.r.ImGui_MenuItem(ctx, "Change Action") then
        self:handleChangeAction(ctx, button, button_manager, menu_path, saveConfig)
    end

    self.r.ImGui_EndPopup(ctx)
end

return {
    new = function(reaper, helpers, createPropertyKey)
        return ButtonContextMenuManager.new(reaper, helpers, createPropertyKey)
    end
}
