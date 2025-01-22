-- toolbar_parser.lua
local CONFIG = require "Advanced Toolbars - User Config"

local Parser = {}
Parser.__index = Parser

function Parser.new(reaper, button_system, button_group)
    local self = setmetatable({}, Parser)
    self.r = reaper
    self.ButtonSystem = button_system
    self.ButtonGroup = button_group
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

function Parser:createToolbar(section_name, button_manager)
    local toolbar = {
        name = section_name:gsub("toolbar:", ""):gsub("_", " "),
        section = section_name,
        custom_name = nil,
        buttons = {},
        groups = {},
        button_manager = button_manager,
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

    return toolbar
end
function Parser:handleGroups(toolbar, buttons)
    local group_configs = CONFIG.TOOLBAR_GROUPS and CONFIG.TOOLBAR_GROUPS[toolbar.section] or {}
    local current_group = self.ButtonGroup.new(self.r)
    local group_index = 1

    for _, button in ipairs(buttons) do
        table.insert(toolbar.buttons, button)
        
        if button.is_separator then
            if #current_group.buttons > 0 then
                current_group.label.text = group_configs[group_index] and group_configs[group_index].label and group_configs[group_index].label.text or ""
                table.insert(toolbar.groups, current_group)
                group_index = group_index + 1
                current_group = self.ButtonGroup.new(self.r)
            end
        else
            current_group:addButton(button)
        end
    end

    if #current_group.buttons > 0 then
        current_group.label.text = group_configs[group_index] and group_configs[group_index].label and group_configs[group_index].label.text or ""
        table.insert(toolbar.groups, current_group)
    end
end

function Parser:parseToolbars(iniContent)
    if not iniContent then return {} end

    local button_manager = self.ButtonSystem.ButtonManager.new(self.r)
    local toolbars = {}
    local current_toolbar, current_buttons = nil, {}

    for line in iniContent:gmatch("[^\r\n]+") do
        local toolbar_section = line:match("%[(.+)%]")
        if toolbar_section then
            if current_toolbar and #current_buttons > 0 then
                self:handleGroups(current_toolbar, current_buttons)
            end
            current_toolbar = self:createToolbar(toolbar_section, button_manager)
            table.insert(toolbars, current_toolbar)
            current_buttons = {}
        elseif current_toolbar then
            local title = line:match("^title=(.+)$")
            if title then
                current_toolbar:updateName(title)
            elseif line:match("^item_%d+") then
                local id, text = line:match("^item_%d+=(%S+)%s*(.*)$")
                if id then
                    local button = id == "-1" 
                        and self.ButtonSystem.Button.new("-1", "SEPARATOR")
                        or self.ButtonSystem.Button.new(id, text)
                    table.insert(current_buttons, button)
                end
            end
        end
    end

    if current_toolbar and #current_buttons > 0 then
        self:handleGroups(current_toolbar, current_buttons)
    end

    return toolbars, button_manager
end

return {
    new = function(reaper, button_system, button_group)
        return Parser.new(reaper, button_system, button_group)
    end
}
