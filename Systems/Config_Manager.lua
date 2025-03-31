-- Systems/Config_Manager.lua

local ConfigManager = {}
ConfigManager.__index = ConfigManager

local function getMainConfigPath()
    return SCRIPT_PATH .. "User/Advanced Toolbars - User Config.lua"
end

local function getToolbarConfigPath(toolbar_section)
    local safe_name = UTILS.getSafeFilename(toolbar_section)
    return UTILS.normalizeSlashes(SCRIPT_PATH .. "User/toolbar_configs/" .. safe_name .. ".lua")
end

function ConfigManager.new(defaults)
    local self = setmetatable({}, ConfigManager)

    if not _G.CONFIG then
        -- Create User directory if it doesn't exist
        local user_dir = UTILS.joinPath(SCRIPT_PATH, "User")
        if not reaper.file_exists(user_dir) then
            if reaper.RecursiveCreateDirectory(user_dir, 0) == 0 then
                reaper.ShowConsoleMsg("Failed to create User directory\n")
                return nil
            end
        end

        local config_path = getMainConfigPath()
        local f = io.open(config_path, "r")

        if not f then
            -- Config file doesn't exist, create it
            local file = io.open(config_path, "w")
            if file then
                file:write("local config = " .. UTILS.serializeTable(defaults, "     ") .. "\n\nreturn config")
                file:close()
                _G.CONFIG = defaults
            else
                reaper.ShowConsoleMsg("Failed to create default config file\n")
                return nil
            end
        else
            f:close()

            local config_loader = assert(loadfile(config_path), "Failed to load config file")
            local config = config_loader()
            assert(type(config) == "table", "Config didn't return a valid table")
            _G.CONFIG = config
        end
    end

    -- Create toolbar configs directory if it doesn't exist
    local toolbar_configs_path = UTILS.joinPath(SCRIPT_PATH, "User/toolbar_configs")

    -- Create directory if it doesn't exist
    if not reaper.file_exists(toolbar_configs_path) then
        if reaper.RecursiveCreateDirectory(toolbar_configs_path, 0) == 0 then
            reaper.ShowConsoleMsg("Failed to create toolbar_configs directory\n")
            return nil
        end
    end

    return self
end

function ConfigManager:collectButtonProperties(toolbar)
    local button_properties = {}
    if not toolbar then
        return button_properties
    end

    for _, button in ipairs(toolbar.buttons) do
        local props = {}
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
        if button.right_click ~= "arm" then
            props.right_click = button.right_click
        end

        if button.dropdown_menu and #button.dropdown_menu > 0 then
            local sanitized_dropdown = {}
            for _, item in ipairs(button.dropdown_menu) do
                if item.is_separator then
                    table.insert(sanitized_dropdown, {is_separator = true})
                else
                    table.insert(
                        sanitized_dropdown,
                        {
                            name = item.name or "Unnamed",
                            action_id = tostring(item.action_id or "")
                        }
                    )
                end
            end
            props.dropdown_menu = sanitized_dropdown
        end

        if button.widget then
            props.widget = {
                name = button.widget.name,
                width = button.widget.width
            }
        end

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
                    group_label = {text = group.group_label.text or ""},
                    is_split_point = group.is_split_point or false
                }
            )
        end
    end
    return toolbar_groups
end

function ConfigManager:loadToolbarConfig(toolbar_section)
    local config_path = getToolbarConfigPath(toolbar_section)

    local f = io.open(config_path, "r")
    if not f then
        --reaper.ShowConsoleMsg("Failed to open toolbar config file: " .. config_path .. "\n")
        return nil
    end
    f:close()

    local config_chunk, err = loadfile(config_path)
    if not config_chunk then
        reaper.ShowConsoleMsg("Error loading config at " .. config_path .. ": " .. tostring(err) .. "\n")
        return nil
    end

    local success, config = pcall(config_chunk)
    if not success or type(config) ~= "table" then
        reaper.ShowConsoleMsg("Error executing config: " .. tostring(config) .. "\n")
        return nil
    end

    return config
end

function ConfigManager:saveMainConfig()
    local config_to_save = {
        UI = CONFIG.UI,
        ICON_FONT = CONFIG.ICON_FONT,
        FONTS = CONFIG.FONTS,
        COLORS = CONFIG.COLORS,
        SIZES = CONFIG.SIZES
    }

    local serialized_data
    local success, err =
        pcall(
        function()
            serialized_data = UTILS.serializeTable(config_to_save)
        end
    )

    if not success or not serialized_data then
        reaper.ShowConsoleMsg("Error serializing config data: " .. tostring(err) .. "\n")
        return false
    end

    local file = io.open(getMainConfigPath(), "w")
    if not file then
        reaper.ShowConsoleMsg("Failed to open config file for writing\n")
        return false
    end

    success, err =
        pcall(
        function()
            file:write("local config = " .. serialized_data .. "\n\nreturn config")
            file:close()
        end
    )

    if not success then
        reaper.ShowConsoleMsg("Error writing main config: " .. tostring(err) .. "\n")
        return false
    end

    return true
end

function ConfigManager:saveToolbarConfig(toolbar)
    if not toolbar then
        reaper.ShowConsoleMsg("Error: Attempt to save nil toolbar\n")
        return false
    end

    local config_to_save = {
        BUTTON_CUSTOM_PROPERTIES = self:collectButtonProperties(toolbar),
        TOOLBAR_GROUPS = self:collectToolbarGroups(toolbar),
        CUSTOM_NAME = toolbar.custom_name
    }

    local serialized_data = UTILS.serializeTable(config_to_save)
    if not serialized_data then
        reaper.ShowConsoleMsg("Error serializing config data\n")
        return false
    end

    local file = io.open(getToolbarConfigPath(toolbar.section), "w")
    if not file then
        reaper.ShowConsoleMsg(
            "Failed to open toolbar config file for writing: " .. getToolbarConfigPath(toolbar.section) .. "\n"
        )
        return false
    end

    local success = file:write("local config = " .. serialized_data .. "\n\nreturn config")
    file:close()

    if not success then
        reaper.ShowConsoleMsg("Error writing config\n")
        return false
    end

    -- Clear all caches to force re-render
    self:clearAllCaches(toolbar)

    return true
end

function ConfigManager:clearAllCaches(toolbar)
    if not toolbar then
        return
    end

    -- Clear group caches
    for _, group in ipairs(toolbar.groups) do
        if group.clearCache then
            group:clearCache()
        end
    end

    -- Clear button caches
    for _, button in ipairs(toolbar.buttons) do
        if button.clearCache then
            button:clearCache()
        end
    end

    -- Reset tracking variables in the toolbar controller
    if C.ToolbarController then
        C.ToolbarController.last_min_width = nil
        C.ToolbarController.last_height = nil
        C.ToolbarController.last_spacing = nil
    end
end

function ConfigManager:saveDockState(dock_id)
    reaper.SetExtState("AdvancedToolbars", "dock_id", tostring(dock_id), true)
end

function ConfigManager:loadDockState()
    return tonumber(reaper.GetExtState("AdvancedToolbars", "dock_id")) or 0
end

function ConfigManager:saveToolbarIndex(index)
    reaper.SetExtState("AdvancedToolbars", "last_toolbar_index", tostring(index), true)
end

function ConfigManager:loadToolbarIndex()
    return tonumber(reaper.GetExtState("AdvancedToolbars", "last_toolbar_index")) or 1
end

function ConfigManager:cleanup()
end

return {
    new = function(...)
        return ConfigManager.new(...)
    end
}
