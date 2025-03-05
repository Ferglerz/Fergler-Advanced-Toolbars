-- toolbar_parser.lua
local ConfigManager = require("config_manager")

local Parser = {}
Parser.__index = Parser

function Parser.new(reaper, button_system, button_group)
    local self = setmetatable({}, Parser)
    self.r = reaper
    self.ButtonSystem = button_system
    self.ButtonGroup = button_group
    self.ConfigManager = ConfigManager.new(reaper)
    return self
end

function Parser:loadMenuIni()
    local menu_path = self.r.GetResourcePath() .. "/reaper-menu.ini"
    local file = io.open(menu_path, "r")

    if not file then
        self.r.ShowMessageBox("Could not open reaper-menu.ini", "Error", 0)
        return nil
    end

    local content = file:read("*all")
    file:close()
    return content, menu_path
end

function Parser:validateIcon(icon_path)
    if not icon_path then
        return false
    end

    local success, file =
        pcall(
        function()
            return io.open(icon_path, "r")
        end
    )
    if not success or not file then
        return false
    end

    file:close()
    return true
end

function Parser:createToolbar(section_name, button_state)
    local toolbar = {
        name = section_name:gsub("toolbar:", ""):gsub("_", " "),
        section = section_name,
        custom_name = nil,
        buttons = {},
        groups = {},
        button_state = button_state,
        updateName = function(self, new_name)
            self.custom_name = new_name
            self.name = new_name or self.section:gsub("toolbar:", ""):gsub("_", " ")
        end,
        addButton = function(self, button)
            table.insert(self.buttons, button)
            if #self.groups == 0 then
                table.insert(self.groups, self.ButtonGroup.new(self.r))
            end
            self.groups[#self.groups]:addButton(button)
        end
    }

    local toolbar_config = self.ConfigManager:loadToolbarConfig(section_name)
    if toolbar_config and toolbar_config.CUSTOM_NAME then
        toolbar:updateName(toolbar_config.CUSTOM_NAME)
    end

    return toolbar
end

function Parser:handleGroups(toolbar, buttons)
    local toolbar_config = self.ConfigManager:loadToolbarConfig(toolbar.section)
    local group_configs = toolbar_config and toolbar_config.TOOLBAR_GROUPS or {}

    local current_group = self.ButtonGroup.new(self.r)
    local group_index = 1

    for _, button in ipairs(buttons) do
        table.insert(toolbar.buttons, button)

        if button.is_separator then
            if #current_group.buttons > 0 then
                current_group.label.text =
                    group_configs[group_index] and group_configs[group_index].label and
                    group_configs[group_index].label.text or
                    ""
                table.insert(toolbar.groups, current_group)
                group_index = group_index + 1
                current_group = self.ButtonGroup.new(self.r)
            end
        else
            current_group:addButton(button)
        end
    end

    if #current_group.buttons > 0 then
        current_group.label.text =
            group_configs[group_index] and group_configs[group_index].label and group_configs[group_index].label.text or
            ""
        table.insert(toolbar.groups, current_group)
    end
end

function Parser:parseToolbars(iniContent)
    if not iniContent then
        return {}
    end

    local button_state = self.ButtonSystem.ButtonState.new(self.r)
    local toolbars = {}
    local current_toolbar, current_buttons = nil, {}

    for line in iniContent:gmatch("[^\r\n]+") do
        local toolbar_section = line:match("%[(.+)%]")
        if toolbar_section then
            if current_toolbar and #current_buttons > 0 then
                self:handleGroups(current_toolbar, current_buttons)
            end
            current_toolbar = self:createToolbar(toolbar_section, button_state)
            table.insert(toolbars, current_toolbar)
            current_buttons = {}
        elseif current_toolbar then
            local title = line:match("^title=(.+)$")
            if title then
                current_toolbar:updateName(title)
            elseif line:match("^item_%d+") then
                local id, text = line:match("^item_%d+=(%S+)%s*(.*)$")
                if id then
                    local button =
                        id == "-1" and self.ButtonSystem.Button.new("-1", "SEPARATOR") or
                        self.ButtonSystem.Button.new(id, text)
                    local toolbar_config = self.ConfigManager:loadToolbarConfig(current_toolbar.section)
                    if toolbar_config and toolbar_config.BUTTON_CUSTOM_PROPERTIES then
                        local props = toolbar_config.BUTTON_CUSTOM_PROPERTIES[button.property_key]
                        if props then
                            if props.name then
                                button.display_text = props.name
                            end
                            if props.hide_label ~= nil then
                                button.hide_label = props.hide_label
                            end
                            if props.justification then
                                button.alignment = props.justification
                            end
                            if props.icon_path then
                                button.icon_path = props.icon_path
                            end
                            if props.icon_char then
                                button.icon_char = props.icon_char
                            end
                            if props.custom_color then
                                button.custom_color = props.custom_color
                            end
                        end
                    end

                    table.insert(current_buttons, button)
                end
            end
        end
    end

    if current_toolbar and #current_buttons > 0 then
        self:handleGroups(current_toolbar, current_buttons)
    end

    return toolbars, button_state
end

function Parser:cleanup()
    -- Nothing to clean up for now
end

return {
    new = function(reaper, button_system, button_group)
        return Parser.new(reaper, button_system, button_group)
    end
}
