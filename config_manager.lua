-- config_manager.lua

local ConfigManager = {}
ConfigManager.__index = ConfigManager

function ConfigManager.new(reaper)
    local self = setmetatable({}, ConfigManager)
    self.r = reaper
    
    -- Create toolbar configs directory if it doesn't exist
    local toolbar_configs_path = SCRIPT_PATH .. "toolbar_configs"
    
    -- Check if directory exists using reaper.file_exists()
    if not reaper.file_exists(toolbar_configs_path) then
        -- Directory doesn't exist, create it
        if reaper.RecursiveCreateDirectory(toolbar_configs_path, 0) == 0 then
            reaper.ShowMessageBox("Failed to create toolbar_configs directory", "Error", 0)
        end
    end
    
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

function ConfigManager:getSafeFilename(str)
    -- Replace characters that are problematic in filenames with underscores
    return str:gsub("[%/\\%:%*%?%\"<>%|]", "_")
end

function ConfigManager:collectButtonProperties(toolbar)
    local button_properties = {}

    if not toolbar then
        return button_properties
    end

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
        if button.icon_font then 
            props.icon_font = button.icon_font
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

function ConfigManager:collectToolbarGroups(toolbar)
    local toolbar_groups = {}

    if toolbar.groups and #toolbar.groups > 0 then
        for _, group in ipairs(toolbar.groups) do
            table.insert(
                toolbar_groups,
                {
                    label = {text = group.label.text or ""}
                }
            )
        end
    end

    return toolbar_groups
end

function ConfigManager:loadConfig()
    -- First check for the main config file
    local config_path = SCRIPT_PATH .. "Advanced Toolbars - User Config.lua"
    local main_config = self:loadMainConfig(config_path)
    
    if not main_config then
        return nil
    end
    
    -- Ensure BUTTON_CUSTOM_PROPERTIES exists
    main_config.BUTTON_CUSTOM_PROPERTIES = main_config.BUTTON_CUSTOM_PROPERTIES or {}
    
    -- Ensure TOOLBAR_GROUPS exists
    main_config.TOOLBAR_GROUPS = main_config.TOOLBAR_GROUPS or {}
    
    return main_config
end

function ConfigManager:loadMainConfig(config_path)
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

function ConfigManager:loadToolbarConfig(toolbar_section)
    local safe_name = self:getSafeFilename(toolbar_section)
    local toolbar_config_path = SCRIPT_PATH .. "toolbar_configs/" .. safe_name .. ".lua"
    
    -- Check if file exists
    local f = io.open(toolbar_config_path, "r")
    if not f then
        -- No specific config for this toolbar
        return nil
    end
    f:close()

    -- Load the config
    local config_chunk, err = loadfile(toolbar_config_path)
    if not config_chunk then
        self.r.ShowConsoleMsg("Error loading toolbar config: " .. tostring(err) .. "\n")
        return nil
    end

    local success, config = pcall(config_chunk)
    if not success then
        self.r.ShowConsoleMsg("Error executing toolbar config: " .. tostring(config) .. "\n")
        return nil
    end

    if type(config) ~= "table" then
        self.r.ShowConsoleMsg("Toolbar config did not return a table\n")
        return nil
    end

    return config
end

function ConfigManager:saveConfig(current_toolbar, all_toolbars, global_config)
    if not current_toolbar then
        return false
    end
    
    -- Save main config (excluding toolbar-specific settings)
    local success = self:saveMainConfig(global_config)
    if not success then
        return false
    end
    
    -- Save individual toolbar configs
    for _, toolbar in ipairs(all_toolbars) do
        success = self:saveToolbarConfig(toolbar)
        if not success then
            return false
        end
    end
    
    return true
end

function ConfigManager:saveMainConfig(config)
    local config_path = SCRIPT_PATH .. "Advanced Toolbars - User Config.lua"
    local file = io.open(config_path, "w")

    if not file then
        self.r.ShowConsoleMsg("Failed to open config file for writing\n")
        return false
    end

    -- Prepare configuration table without toolbar-specific configs
    local config_to_save = {
        UI = config.UI,
        ICON_FONT = config.ICON_FONT,
        FONTS = config.FONTS,
        COLORS = config.COLORS,
        SIZES = config.SIZES,
        -- We're removing these from main config:
        -- BUTTON_CUSTOM_PROPERTIES = {},
        -- TOOLBAR_GROUPS = {}
    }

    -- Write configuration
    local success, err = pcall(function()
        file:write("local config = " .. self:serializeTable(config_to_save) .. "\n\nreturn config")
        file:close()
    end)

    if not success then
        self.r.ShowConsoleMsg("Error saving main config: " .. tostring(err) .. "\n")
        return false
    end

    return true
end

function ConfigManager:saveToolbarConfig(toolbar)
    local safe_name = self:getSafeFilename(toolbar.section)
    local toolbar_config_path = SCRIPT_PATH .. "toolbar_configs/" .. safe_name .. ".lua"
    local file = io.open(toolbar_config_path, "w")

    if not file then
        self.r.ShowConsoleMsg("Failed to open toolbar config file for writing: " .. toolbar_config_path .. "\n")
        return false
    end

    -- Prepare configuration table for this toolbar
    local button_properties = self:collectButtonProperties(toolbar)
    local groups = self:collectToolbarGroups(toolbar)
    
    local config_to_save = {
        BUTTON_CUSTOM_PROPERTIES = button_properties,
        TOOLBAR_GROUPS = groups,
        CUSTOM_NAME = toolbar.custom_name
    }

    -- Write configuration
    local success, err = pcall(function()
        file:write("local config = " .. self:serializeTable(config_to_save) .. "\n\nreturn config")
        file:close()
    end)

    if not success then
        self.r.ShowConsoleMsg("Error saving toolbar config: " .. tostring(err) .. "\n")
        return false
    end

    return true
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
    new = function(reaper)
        return ConfigManager.new(reaper)
    end
}