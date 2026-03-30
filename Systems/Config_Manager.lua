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

local function getToolbarConfigsDir()
    return UTILS.joinPath(SCRIPT_PATH, "User/toolbar_configs")
end

local function parseIniToolbars(content)
    local toolbars = {}
    local current = nil

    if type(content) ~= "string" or content == "" then
        return toolbars
    end

    local function pushCurrent()
        if current then
            table.insert(toolbars, current)
        end
    end

    for line in content:gmatch("[^\r\n]+") do
        local section_name = line:match("^%[(.+)%]$")
        if section_name then
            pushCurrent()
            current = {
                section = section_name,
                title = nil,
                default = nil,
                icons = {},
                items = {}
            }
        elseif current then
            local _, id, text = line:match("^item_(%d+)=(%S+)%s*(.*)$")
            if id then
                table.insert(current.items, { id = id, text = text or "" })
            else
                local default_val = line:match("^default=(.*)$")
                if default_val ~= nil then
                    current.default = default_val
                else
                    local icon_idx, icon_val = line:match("^icon_(%d+)=(.*)$")
                    if icon_idx and icon_val ~= nil then
                        current.icons[tonumber(icon_idx)] = icon_val
                    else
                        local title_val = line:match("^title=(.*)$")
                        if title_val ~= nil then
                            current.title = title_val
                        end
                    end
                end
            end
        end
    end

    pushCurrent()
    return toolbars
end

-- Recursively merge default config into user config to add missing entries
function ConfigManager:migrateConfig(userConfig, defaultConfig)
    local migrated = false
    
    for key, value in pairs(defaultConfig) do
        if userConfig[key] == nil then
            -- Missing key in user config, add it
            userConfig[key] = self:deepCopy(value)
            migrated = true
        elseif type(value) == "table" and type(userConfig[key]) == "table" then
            -- Both are tables, recurse deeper
            if self:migrateConfig(userConfig[key], value) then
                migrated = true
            end
        end
    end
    
    return migrated
end

-- Deep copy function for config values
function ConfigManager:deepCopy(original)
    if type(original) ~= "table" then
        return original
    end
    
    local copy = {}
    for key, value in pairs(original) do
        copy[key] = self:deepCopy(value)
    end
    return copy
end

-- Ensure TOOLBAR_CONTROLLERS is keyed by string IDs (avoid numeric/string split-brain).
function ConfigManager:normalizeToolbarControllerKeys(config_table)
    if type(config_table) ~= "table" then
        return false
    end
    if type(config_table.TOOLBAR_CONTROLLERS) ~= "table" then
        config_table.TOOLBAR_CONTROLLERS = {}
        return true
    end

    local normalized = {}
    local changed = false
    for key, value in pairs(config_table.TOOLBAR_CONTROLLERS) do
        local skey = tostring(key)
        if skey ~= key then
            changed = true
        end
        if type(normalized[skey]) == "table" then
            changed = true
        else
            normalized[skey] = value
        end
    end

    if changed then
        config_table.TOOLBAR_CONTROLLERS = normalized
    end
    return changed
end

-- Pre-convert all config colors to ImGui format for performance
function ConfigManager:cacheColors()
    if not _G.CONFIG or not _G.CONFIG.COLORS then
        return
    end

    -- Clear existing cache
    self.cached_colors = {}

    -- Function to recursively cache colors in a table
    local function cacheColorTable(source, target)
        for key, value in pairs(source) do
            if type(value) == "table" then
                target[key] = {}
                cacheColorTable(value, target[key])
            elseif type(value) == "string" and value:match("^#%x%x%x%x%x%x%x?%x?$") then
                -- Convert hex color to ImGui format
                target[key] = COLOR_UTILS.toImGuiColor(value)
            else
                target[key] = value
            end
        end
    end

    -- Cache all colors from CONFIG.COLORS
    cacheColorTable(_G.CONFIG.COLORS, self.cached_colors)
end

-- Get cached ImGui color (fallback to conversion if not cached)
-- Accepts either a dot-separated string path (e.g., "GROUP.LABEL") or a table path (e.g., {"GROUP", "LABEL"})
function ConfigManager:getCachedColor(path)
    local keys = {}
    
    -- Handle both string and table paths
    if type(path) == "string" then
        for key in path:gmatch("[^%.]+") do
            table.insert(keys, key)
        end
    elseif type(path) == "table" then
        keys = path
    else
        return COLOR_UTILS.toImGuiColor("#FF0000FF") -- Default red on invalid input
    end

    local current = self.cached_colors
    for _, key in ipairs(keys) do
        if not current or not current[key] then
            -- Fallback to original conversion if not cached
            local original = _G.CONFIG and _G.CONFIG.COLORS
            if not original then
                return COLOR_UTILS.toImGuiColor("#FF0000FF") -- Default red
            end
            
            for _, orig_key in ipairs(keys) do
                if original and original[orig_key] then
                    original = original[orig_key]
                else
                    return COLOR_UTILS.toImGuiColor("#FF0000FF") -- Default red
                end
            end
            return COLOR_UTILS.toImGuiColor(original)
        end
        current = current[key]
    end

    return current
end

-- Convenience method for getting cached color with safe fallback
-- Returns the cached color if available, otherwise converts from CONFIG
function ConfigManager:getCachedColorSafe(...)
    local keys = {...}
    if #keys == 0 then
        return nil
    end
    
    -- Check cache first
    local current = self.cached_colors
    for _, key in ipairs(keys) do
        if current and current[key] then
            current = current[key]
        else
            current = nil
            break
        end
    end
    
    if current then
        return current
    end
    
    -- Fallback to CONFIG
    local original = _G.CONFIG and _G.CONFIG.COLORS
    if not original then
        return nil
    end
    
    for _, key in ipairs(keys) do
        if original and original[key] then
            original = original[key]
        else
            return nil
        end
    end
    
    -- Convert if it's a string
    if type(original) == "string" then
        return COLOR_UTILS.toImGuiColor(original)
    end
    
    return original
end

-- Helper function to save config to file
function ConfigManager:saveConfigToFile(config, file_path)
    local serialized_data = UTILS.serializeTable(config)
    if not serialized_data then
        reaper.ShowConsoleMsg("Error serializing config data\n")
        return false
    end
    
    local file = io.open(file_path, "w")
    if not file then
        reaper.ShowConsoleMsg("Failed to open config file for writing: " .. file_path .. "\n")
        return false
    end
    
    local success, err = pcall(function()
        file:write("local config = " .. serialized_data .. "\n\nreturn config")
    end)
    
    file:close()
    
    if not success then
        reaper.ShowConsoleMsg("Error writing config file: " .. tostring(err) .. "\n")
        return false
    end
    
    return true
end

function ConfigManager.new()
    local self = setmetatable({}, ConfigManager)
    self.cached_colors = {}

    if not _G.CONFIG then
        -- Create User directory if it doesn't exist
        local user_dir = UTILS.joinPath(SCRIPT_PATH, "User")
        if not UTILS.ensureDirectoryExists(user_dir) then
            return nil
        end

        local config_path = getMainConfigPath()
        local f = io.open(config_path, "r")

        if not f then
            -- Config file doesn't exist, create it by copying DEFAULT_CONFIG.lua
            local default_config_path = UTILS.joinPath(SCRIPT_PATH, "Systems/DEFAULT_CONFIG.lua")
            local default_file = io.open(default_config_path, "r")
            
            if not default_file then
                reaper.ShowConsoleMsg("Failed to open default config file: " .. default_config_path .. "\n")
                return nil
            end
            
            local content = default_file:read("*all")
            default_file:close()
            
            local file = io.open(config_path, "w")
            if file then
                file:write(content)
                file:close()
                
                -- Now load the config we just wrote
                local config_loader = assert(loadfile(config_path), "Failed to load config file")
                local config = config_loader()
                assert(type(config) == "table", "Config didn't return a valid table")
                _G.CONFIG = config
                self:cacheColors() -- Pre-convert colors for performance
            else
                reaper.ShowConsoleMsg("Failed to create default config file\n")
                return nil
            end
        else
            f:close()

            local config_loader = assert(loadfile(config_path), "Failed to load config file")
            local user_config = config_loader()
            assert(type(user_config) == "table", "Config didn't return a valid table")
            
            -- Load default config for migration
            local default_config_path = UTILS.joinPath(SCRIPT_PATH, "Systems/DEFAULT_CONFIG.lua")
            local default_config_loader = assert(loadfile(default_config_path), "Failed to load default config file")
            local default_config = default_config_loader()
            
            -- Migrate user config to include any missing default values
            local needs_save = self:migrateConfig(user_config, default_config)
            if self:normalizeToolbarControllerKeys(user_config) then
                needs_save = true
            end
            
            if needs_save then
                reaper.ShowConsoleMsg("Advanced Toolbars: Migrated user config with new settings\n")
                -- Save the updated config
                self:saveConfigToFile(user_config, config_path)
            end

            _G.CONFIG = user_config
            self:cacheColors() -- Pre-convert colors for performance
        end
    end

    -- Create toolbar configs directory if it doesn't exist
    local toolbar_configs_path = UTILS.joinPath(SCRIPT_PATH, "User/toolbar_configs")

    if not UTILS.ensureDirectoryExists(toolbar_configs_path) then
        return nil
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
        
        -- Always save instance_id to maintain uniqueness
        if button.instance_id then
            props.instance_id = button.instance_id
        end
        
        -- Save button type for proper reconstruction
        if button.button_type and button.button_type ~= "normal" then
            props.button_type = button.button_type
        end
        
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
        
        -- Only save these properties for normal buttons
        if not button:isSeparator() then
            if button.right_click ~= "arm" then
                props.right_click = button.right_click
            end
            if button.right_click_action and not button.right_click_action == "" then
                props.right_click_action = button.right_click_action
            end

            if button.dropdown_menu and #button.dropdown_menu > 0 then
                local sanitized_dropdown = {}
                for _, item in ipairs(button.dropdown_menu) do
                    if item.is_separator then
                        table.insert(sanitized_dropdown, {is_separator = true})
                    elseif item.is_heading then
                        table.insert(
                            sanitized_dropdown,
                            {is_heading = true, name = item.name or ""}
                        )
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
            local gl = group.group_label
            table.insert(
                toolbar_groups,
                {
                    group_label = {text = (gl and gl.text) or ""},
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

function ConfigManager:writeToolbarConfig(toolbar_section, config_table)
    local serialized_data = UTILS.serializeTable(config_table)
    if not serialized_data then
        reaper.ShowConsoleMsg("Advanced Toolbars: error serializing toolbar config for " .. tostring(toolbar_section) .. "\n")
        return false
    end

    local path = getToolbarConfigPath(toolbar_section)
    local file = io.open(path, "w")
    if not file then
        reaper.ShowConsoleMsg("Advanced Toolbars: failed to open toolbar config for write: " .. tostring(path) .. "\n")
        return false
    end

    local ok = file:write("local config = " .. serialized_data .. "\n\nreturn config")
    file:close()
    return ok and true or false
end

function ConfigManager:getToolbarConfigSections()
    local dir = getToolbarConfigsDir()
    local files = UTILS.getFilesInDirectory(dir)
    local out = {}
    for _, file in ipairs(files or {}) do
        if type(file) == "string" and file:match("%.lua$") then
            local full = UTILS.joinPath(dir, file)
            local chunk = loadfile(full)
            if chunk then
                local ok, cfg = pcall(chunk)
                if ok and type(cfg) == "table" then
                    local section = cfg.SECTION
                    if type(section) ~= "string" or section == "" then
                        section = file:gsub("%.lua$", "")
                    end
                    local order = tonumber(cfg.ORDER) or 999999
                    table.insert(out, { section = section, order = order })
                end
            end
        end
    end
    table.sort(
        out,
        function(a, b)
            if a.order == b.order then
                return tostring(a.section) < tostring(b.section)
            end
            return a.order < b.order
        end
    )
    return out
end

function ConfigManager:ensureToolbarStructureStoreInitialized(ini_content)
    local sections = self:getToolbarConfigSections()
    local missing_sections = {}
    for _, s in ipairs(sections) do
        local cfg = self:loadToolbarConfig(s.section)
        local has_structure = type(cfg) == "table" and type(cfg.STRUCTURE) == "table" and type(cfg.STRUCTURE.items) == "table"
        if not has_structure then
            table.insert(missing_sections, s.section)
        end
    end

    if #sections > 0 and #missing_sections == 0 then
        return true
    end

    local parsed = parseIniToolbars(ini_content)
    if #parsed == 0 then
        return #sections > 0
    end

    for i, tb in ipairs(parsed) do
        local should_write = (#sections == 0)
        if not should_write then
            for _, missing in ipairs(missing_sections) do
                if missing == tb.section then
                    should_write = true
                    break
                end
            end
        end
        if not should_write then
            goto continue
        end

        local cfg = self:loadToolbarConfig(tb.section)
        if type(cfg) ~= "table" then
            cfg = {}
        end
        cfg.SECTION = tb.section
        cfg.ORDER = i
        cfg.STRUCTURE = {
            items = tb.items or {},
            default = tb.default,
            icons = tb.icons or {},
            title = tb.title
        }
        cfg.BUTTON_CUSTOM_PROPERTIES = cfg.BUTTON_CUSTOM_PROPERTIES or {}
        cfg.TOOLBAR_GROUPS = cfg.TOOLBAR_GROUPS or {}
        cfg.CUSTOM_NAME = cfg.CUSTOM_NAME or tb.title
        if not self:writeToolbarConfig(tb.section, cfg) then
            return false
        end
        ::continue::
    end

    return true
end

function ConfigManager:buildRuntimeLinesFromToolbarConfigs(ini_content)
    if not self:ensureToolbarStructureStoreInitialized(ini_content) then
        return nil
    end

    local lines = {}
    local sections = self:getToolbarConfigSections()
    for _, s in ipairs(sections) do
        local cfg = self:loadToolbarConfig(s.section)
        if type(cfg) == "table" and type(cfg.STRUCTURE) == "table" then
            local structure = cfg.STRUCTURE
            table.insert(lines, "[" .. tostring(s.section) .. "]")

            for i, item in ipairs(structure.items or {}) do
                local id = tostring(item.id or "")
                local text = tostring(item.text or "")
                if id == "-1" or text == "" then
                    table.insert(lines, string.format("item_%d=%s", i - 1, id))
                else
                    table.insert(lines, string.format("item_%d=%s %s", i - 1, id, text))
                end
            end

            if structure.default ~= nil and structure.default ~= "" then
                table.insert(lines, "default=" .. tostring(structure.default))
            end

            local icon_keys = {}
            for k in pairs(structure.icons or {}) do
                if type(k) == "number" then
                    table.insert(icon_keys, k)
                end
            end
            table.sort(icon_keys)
            for _, k in ipairs(icon_keys) do
                table.insert(lines, string.format("icon_%d=%s", k, tostring(structure.icons[k])))
            end

            local title = structure.title or cfg.CUSTOM_NAME
            if title and title ~= "" then
                table.insert(lines, "title=" .. tostring(title))
            end
        end
    end

    return lines
end

function ConfigManager:buildRuntimeIniContentFromToolbarConfigs(ini_content)
    local lines = self:buildRuntimeLinesFromToolbarConfigs(ini_content)
    if not lines then
        return nil
    end
    return table.concat(lines, "\n")
end

function ConfigManager:writeRuntimeLinesToToolbarConfigs(lines)
    local content = table.concat(lines or {}, "\n")
    local parsed = parseIniToolbars(content)
    if #parsed == 0 then
        return false
    end

    for i, tb in ipairs(parsed) do
        local cfg = self:loadToolbarConfig(tb.section)
        if type(cfg) ~= "table" then
            cfg = {}
        end
        cfg.SECTION = tb.section
        cfg.ORDER = cfg.ORDER or i
        cfg.STRUCTURE = {
            items = tb.items or {},
            default = tb.default,
            icons = tb.icons or {},
            title = tb.title
        }
        cfg.BUTTON_CUSTOM_PROPERTIES = cfg.BUTTON_CUSTOM_PROPERTIES or {}
        cfg.TOOLBAR_GROUPS = cfg.TOOLBAR_GROUPS or {}
        if cfg.CUSTOM_NAME == nil and tb.title then
            cfg.CUSTOM_NAME = tb.title
        end
        if not self:writeToolbarConfig(tb.section, cfg) then
            return false
        end
    end
    return true
end

function ConfigManager:listTemplateEntriesFromIni(ini_content)
    local out = {}
    for _, tb in ipairs(parseIniToolbars(ini_content)) do
        table.insert(
            out,
            {
                section = tb.section,
                name = (tb.title and tb.title ~= "") and tb.title or tb.section
            }
        )
    end
    return out
end

function ConfigManager:createToolbarFromIniTemplate(template_section, ini_content)
    local template = nil
    for _, tb in ipairs(parseIniToolbars(ini_content)) do
        if tb.section == template_section then
            template = tb
            break
        end
    end
    if not template then
        return nil
    end

    local existing = {}
    local max_order = 0
    for _, s in ipairs(self:getToolbarConfigSections()) do
        existing[s.section] = true
        max_order = math.max(max_order, tonumber(s.order) or 0)
    end

    local base = ((template.title and template.title ~= "") and template.title or template.section) .. " Copy"
    local section = base
    local n = 2
    while existing[section] do
        section = string.format("%s (%d)", base, n)
        n = n + 1
    end

    local cfg = {
        SECTION = section,
        ORDER = max_order + 1,
        CUSTOM_NAME = section,
        BUTTON_CUSTOM_PROPERTIES = {},
        TOOLBAR_GROUPS = {},
        STRUCTURE = {
            items = template.items or {},
            default = template.default,
            icons = template.icons or {},
            title = section
        }
    }
    if not self:writeToolbarConfig(section, cfg) then
        return nil
    end
    return section
end

function ConfigManager:saveMainConfig()
    local config_to_save = {}
    for k, v in pairs(CONFIG) do
        config_to_save[k] = v
    end

    local serialized_data
    serialized_data = UTILS.serializeTable(config_to_save)

    if not serialized_data then
        reaper.ShowConsoleMsg("Error serializing config data: \n")
        return false
    end

    local file = io.open(getMainConfigPath(), "w")
    if not file then
        reaper.ShowConsoleMsg("Failed to open config file for writing\n")
        return false
    end

    
    local success, err =
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

    -- Re-cache colors after config change
    self:cacheColors()

    -- Notify layout manager of config change
    if C.LayoutManager then
        C.LayoutManager:configChanged()
    end

    return true
end

-- Write TOOLBAR_GROUPS only, preserving other keys from disk (for group reorder without full toolbar save).
function ConfigManager:saveToolbarGroupsOnly(toolbar_section, toolbar_groups_array)
    if not toolbar_section or type(toolbar_groups_array) ~= "table" then
        reaper.ShowConsoleMsg("Advanced Toolbars: saveToolbarGroupsOnly invalid arguments\n")
        return false
    end
    local existing = self:loadToolbarConfig(toolbar_section)
    if type(existing) ~= "table" then
        existing = {}
    end
    existing.TOOLBAR_GROUPS = toolbar_groups_array
    existing.SECTION = existing.SECTION or toolbar_section
    if existing.BUTTON_CUSTOM_PROPERTIES == nil then
        existing.BUTTON_CUSTOM_PROPERTIES = {}
    end

    local serialized_data = UTILS.serializeTable(existing)
    if not serialized_data then
        reaper.ShowConsoleMsg("Advanced Toolbars: failed to serialize TOOLBAR_GROUPS for " .. tostring(toolbar_section) .. "\n")
        return false
    end

    local config_path = getToolbarConfigPath(toolbar_section)
    local file = io.open(config_path, "w")
    if not file then
        reaper.ShowConsoleMsg("Advanced Toolbars: failed to open toolbar config for groups-only save: " .. tostring(config_path) .. "\n")
        return false
    end
    local success = file:write("local config = " .. serialized_data .. "\n\nreturn config")
    file:close()
    if not success then
        reaper.ShowConsoleMsg("Advanced Toolbars: failed to write TOOLBAR_GROUPS for " .. tostring(toolbar_section) .. "\n")
        return false
    end
    if C.LayoutManager then
        C.LayoutManager:configChanged()
    end
    return true
end

function ConfigManager:saveToolbarConfig(toolbar)
    if not toolbar then
        reaper.ShowConsoleMsg("Error: Attempt to save nil toolbar\n")
        return false
    end

    local config_to_save = self:loadToolbarConfig(toolbar.section)
    if type(config_to_save) ~= "table" then
        config_to_save = {}
    end
    config_to_save.BUTTON_CUSTOM_PROPERTIES = self:collectButtonProperties(toolbar)
    config_to_save.TOOLBAR_GROUPS = self:collectToolbarGroups(toolbar)
    config_to_save.CUSTOM_NAME = toolbar.custom_name
    config_to_save.SECTION = toolbar.section
    config_to_save.STRUCTURE = config_to_save.STRUCTURE or {}
    config_to_save.STRUCTURE.items = {}
    for _, button in ipairs(toolbar.buttons or {}) do
        table.insert(
            config_to_save.STRUCTURE.items,
            {
                id = button.id,
                text = button.original_text or ""
            }
        )
    end
    config_to_save.STRUCTURE.title = toolbar.ini_title or config_to_save.STRUCTURE.title or toolbar.custom_name

    local serialized_data = UTILS.serializeTable(config_to_save)
    if not serialized_data then
        reaper.ShowConsoleMsg("Advanced Toolbars: error serializing toolbar config for " .. tostring(toolbar.section) .. "\n")
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
        reaper.ShowConsoleMsg("Advanced Toolbars: error writing toolbar config for " .. tostring(toolbar.section) .. "\n")
        return false
    end

    -- Clear all caches to force re-render
    self:clearAllCaches(toolbar)
    
    -- Notify layout manager of config change
    if C.LayoutManager then
        C.LayoutManager:configChanged()
    end

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

    -- Clear button caches (layout only - preserve colors)
    for _, button in ipairs(toolbar.buttons) do
        if button.clearLayoutCache then
            button:clearLayoutCache()
        elseif button.clearCache then
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

local function getControllerSettingsById(toolbar_id)
    if not CONFIG or type(CONFIG.TOOLBAR_CONTROLLERS) ~= "table" then
        return nil, nil
    end
    if toolbar_id ~= nil then
        local key = tostring(toolbar_id)
        local t = CONFIG.TOOLBAR_CONTROLLERS[key]
        if type(t) == "table" then
            return t, key
        end
    end
    for key, t in pairs(CONFIG.TOOLBAR_CONTROLLERS) do
        if type(t) == "table" then
            return t, key
        end
    end
    return nil, nil
end

function ConfigManager:saveDockState(dock_id, toolbar_id)
    local t, key = getControllerSettingsById(toolbar_id)
    if not t then
        return false
    end
    CONFIG.TOOLBAR_CONTROLLERS[key].dock_id = tonumber(dock_id) or 0
    return self:saveMainConfig()
end

function ConfigManager:loadDockState(toolbar_id)
    local t = getControllerSettingsById(toolbar_id)
    return tonumber(t and t.dock_id) or 0
end

function ConfigManager:saveToolbarIndex(index, toolbar_id)
    local t, key = getControllerSettingsById(toolbar_id)
    if not t then
        return false
    end
    local v = tonumber(index) or 1
    CONFIG.TOOLBAR_CONTROLLERS[key].last_toolbar_index = v
    CONFIG.TOOLBAR_CONTROLLERS[key].toolbar_index = v
    return self:saveMainConfig()
end

function ConfigManager:saveConfig()
    return self:saveMainConfig()
end

function ConfigManager:loadToolbarIndex(toolbar_id)
    local t = getControllerSettingsById(toolbar_id)
    if not t then
        return 1
    end
    return tonumber(t.last_toolbar_index or t.toolbar_index) or 1
end

function ConfigManager:cleanup()
end

return ConfigManager.new()