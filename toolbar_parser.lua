-- toolbar_parser.lua

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
    local resource_path = self.r.GetResourcePath()
    local menu_path = resource_path .. "/reaper-menu.ini"
    
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
    if not icon_path then return false end
    
    local success, file = pcall(function()
        return io.open(icon_path, "r")
    end)
    
    if not success or not file then return false end
    
    file:close()
    return true
end

function Parser:createToolbar(section_name, config, button_manager)
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
            
            -- Add to default group if no groups exist
            if #self.groups == 0 then
                local default_group = self.ButtonGroup.new(self.r, config)
                table.insert(self.groups, default_group)
            end
            self.groups[#self.groups]:addButton(button)
        end
    }
    
    return toolbar
end

-- Takes a toolbar object, array of buttons, and config
function Parser:handleGroups(toolbar, buttons, config)
    -- Get group configurations for this toolbar section, or empty table if none exist
    local group_configs = config.TOOLBAR_GROUPS and config.TOOLBAR_GROUPS[toolbar.section] or {}

    -- Initialize first group
    local current_group = self.ButtonGroup.new(self.r, config)
    local group_index = 1

    -- Helper function to finalize the current group
    local function finalizeCurrentGroup()
        if #current_group.buttons > 0 then
            if group_configs[group_index] and group_configs[group_index].label then
                current_group.label.text = group_configs[group_index].label.text or ""
            else
                current_group.label.text = ""
            end
            table.insert(toolbar.groups, current_group)
            group_index = group_index + 1
        end
    end

    -- Iterate through all buttons
    for _, button in ipairs(buttons) do
        -- Add button to toolbar's button array
        table.insert(toolbar.buttons, button)

        -- If we hit a separator, finalize the current group and start a new one
        if button.is_separator then
            finalizeCurrentGroup()
            current_group = self.ButtonGroup.new(self.r, config)
        else
            -- Add non-separator button to the current group
            current_group:addButton(button)
        end
    end

    -- Finalize the last group
    finalizeCurrentGroup()
end

function Parser:parseToolbars(iniContent, config)
    if not iniContent then return {} end
    
    local button_manager = self.ButtonSystem.ButtonManager.new(self.r, config)
    local toolbars = {}
    local current_toolbar = nil
    local current_buttons = {}

    for line in iniContent:gmatch("[^\r\n]+") do
        local toolbar_section = line:match("%[(.+)%]")
        if toolbar_section then
            -- Handle previous toolbar if exists
            if current_toolbar and #current_buttons > 0 then
                self:handleGroups(current_toolbar, current_buttons, config)
            end
            
            -- Create new toolbar
            current_toolbar = self:createToolbar(toolbar_section, config, button_manager)
            table.insert(toolbars, current_toolbar)
            current_buttons = {}
            
        elseif current_toolbar then
            local title = line:match("^title=(.+)$")
            if title then
                current_toolbar:updateName(title)
            elseif line:match("^item_%d+") then
                local id, text = line:match("^item_%d+=(%S+)%s*(.*)$")
                if id then
                    if id == "-1" then
                        local separator = self.ButtonSystem.Button.new("-1", "SEPARATOR", config)
                        table.insert(current_buttons, separator)
                    else
                        local button = self.ButtonSystem.Button.new(id, text, config)
                        table.insert(current_buttons, button)
                    end
                end
            end
        end
    end
    
    -- Handle last toolbar
    if current_toolbar and #current_buttons > 0 then
        self:handleGroups(current_toolbar, current_buttons, config)
    end


    
    return toolbars, button_manager
end

return {
    new = function(reaper, button_system, button_group)
        return Parser.new(reaper, button_system, button_group)
    end
}
