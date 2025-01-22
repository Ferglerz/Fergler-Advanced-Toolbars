-- config_manager.lua
local CONFIG = require "Advanced Toolbars - User Config"

local ConfigManager = {}
ConfigManager.__index = ConfigManager

function ConfigManager.new(reaper, script_path)
    local self = setmetatable({}, ConfigManager)
    self.r = reaper
    self.script_path = script_path
    return self
end

function ConfigManager:serializeValue(value, indent)
    if type(value) == "table" then
        return self:serializeTable(value, indent)
    elseif type(value) == "string" then
        return string.format('"%s"', value:gsub('"', '\\"'):gsub("\n", "\\n"))
    else
        return tostring(value)
    end
end

function ConfigManager:serializeTable(tbl, indent)
    indent = indent or "    "
    local parts = {}

    -- Sort keys for consistent output
    local keys = {}
    for k in pairs(tbl) do
        table.insert(keys, k)
    end
    table.sort(keys)

    for _, key in ipairs(keys) do
        local value = tbl[key]
        -- Use simple key format if possible
        local key_str
        if type(key) == "string" and key:match("^[%a_][%w_]*$") then
            key_str = key
        else
            key_str = string.format('["%s"]', key)
        end

        local value_str = self:serializeValue(value, indent .. "    ")
        table.insert(parts, indent .. key_str .. " = " .. value_str)
    end

    return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent:sub(1, -5) .. "}"
end

function ConfigManager:collectButtonProperties(toolbar)
    local button_properties = {}
    
    if not toolbar then return button_properties end
    
    for _, button in ipairs(toolbar.buttons) do
        local props = {}
        
        -- Only add properties that differ from defaults
        if button.display_text ~= button.original_text then
            props.name = button.display_text
        end
        if button.hide_label then
            props.hide_label = button.hide_label
        end
        if button.alignment ~= "center" then
            props.justification = button.alignment
        end
        if button.icon_path then
            props.icon_path = button.icon_path
        end
        if button.icon_char then
            props.icon_char = button.icon_char
        end
        if button.custom_color then
            props.custom_color = button.custom_color
        end

        -- Only add if there are non-default properties
        if next(props) then
            button_properties[button.property_key] = props
        end
    end

    return button_properties
end

function ConfigManager:collectToolbarGroups(toolbars)
    local toolbar_groups = {}
    
    for _, toolbar in ipairs(toolbars) do
        if toolbar.groups and #toolbar.groups > 0 then
            toolbar_groups[toolbar.section] = {}
            for _, group in ipairs(toolbar.groups) do
                table.insert(
                    toolbar_groups[toolbar.section],
                    {
                        label = {text = group.label.text or ""}
                    }
                )
            end
        end
    end

    return toolbar_groups
end

function ConfigManager:saveConfig(current_toolbar, all_toolbars)
    local config_path = self.script_path .. "Advanced Toolbars - User Config.lua"
    local file = io.open(config_path, "w")
    
    if not file then
        self.r.ShowConsoleMsg("Failed to open config file for writing\n")
        return false
    end

    -- Prepare configuration table
    local config_to_save = {
        UI = CONFIG.UI,
        ICON_FONT = CONFIG.ICON_FONT,
        FONTS = CONFIG.FONTS,
        COLORS = CONFIG.COLORS,
        SIZES = CONFIG.SIZES,
        BUTTON_CUSTOM_PROPERTIES = self:collectButtonProperties(current_toolbar),
        TOOLBAR_GROUPS = self:collectToolbarGroups(all_toolbars)
    }

    -- Write configuration
    local success, err = pcall(function()
        file:write("local config = " .. self:serializeTable(config_to_save) .. "\n\nreturn config")
        file:close()
    end)

    if not success then
        self.r.ShowConsoleMsg("Error saving config: " .. tostring(err) .. "\n")
        return false
    end

    return true
end

function ConfigManager:loadConfig()
    local config_path = self.script_path .. "Advanced Toolbars - User Config.lua"
    
    -- Check if file exists
    local f = io.open(config_path, "r")
    if not f then
        self.r.ShowConsoleMsg("Config file not found\n")
        return nil
    end
    f:close()

    -- Load the config
    local config_chunk, err = loadfile(config_path)
    if not config_chunk then
        self.r.ShowConsoleMsg("Error loading config: " .. tostring(err) .. "\n")
        return nil
    end

    local success, config = pcall(config_chunk)
    if not success then
        self.r.ShowConsoleMsg("Error executing config: " .. tostring(config) .. "\n")
        return nil
    end

    if type(config) ~= "table" then
        self.r.ShowConsoleMsg("Config did not return a table\n")
        return nil
    end

    return config
end

function ConfigManager:saveDockState(dock_id)
    self.r.SetExtState("AdvancedToolbars", "dock_id", tostring(dock_id), true)
end

function ConfigManager:loadDockState()
    return tonumber(self.r.GetExtState("AdvancedToolbars", "dock_id")) or 0
end

function ConfigManager:saveToolbarIndex(index)
    self.r.SetExtState("AdvancedToolbars", "last_toolbar_index", tostring(index), true)
end

function ConfigManager:loadToolbarIndex()
    return tonumber(self.r.GetExtState("AdvancedToolbars", "last_toolbar_index")) or 1
end

return {
    new = function(reaper, script_path)
        return ConfigManager.new(reaper, script_path)
    end
}