return function(ConfigManager, shared)
function ConfigManager:saveConfigToFile(config, file_path)
    if not self:backupUserConfigFileBeforeWrite(file_path) then
        reaper.ShowConsoleMsg("Advanced Toolbars: could not create config backup for " .. tostring(file_path) .. "\n")
    end

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
function ConfigManager:loadToolbarConfig(toolbar_section)
    if shared.toolbar_config_cache[toolbar_section] then
        return shared.toolbar_config_cache[toolbar_section]
    end

    local config_path = shared.getToolbarConfigPath(toolbar_section)

    local file = io.open(config_path, "r")
    if not file then
        return nil
    end
    local content = file:read("*a")
    file:close()
    if not content or content:match("^%s*$") then
        return nil
    end

    local config_chunk, err
    if loadstring then
        config_chunk, err = loadstring(content, "@" .. config_path)
    else
        config_chunk, err = load(content, "@" .. config_path, "t")
    end
    if not config_chunk then
        reaper.ShowConsoleMsg("Error loading config at " .. config_path .. ": " .. tostring(err) .. "\n")
        return nil
    end

    local success, config = pcall(config_chunk)
    if not success or type(config) ~= "table" then
        reaper.ShowConsoleMsg("Error executing config: " .. tostring(config) .. "\n")
        return nil
    end

    shared.toolbar_config_cache[toolbar_section] = config
    return config
end

function ConfigManager:writeToolbarConfig(toolbar_section, config_table)
    if type(config_table) == "table" and type(config_table.STRUCTURE) == "table" and type(config_table.STRUCTURE.items) == "table" then
        if self:stripTrailingSeparatorsFromStructureItems(config_table) then
            self:rekeyButtonCustomPropertiesForStructure(config_table)
            self:syncToolbarGroupsToStructureItems(config_table)
        end
    end
    local serialized_data = UTILS.serializeTable(config_table)
    if not serialized_data then
        reaper.ShowConsoleMsg("Advanced Toolbars: error serializing toolbar config for " .. tostring(toolbar_section) .. "\n")
        return false
    end

    local path = shared.getToolbarConfigPath(toolbar_section)
    if not self:backupUserConfigFileBeforeWrite(path) then
        reaper.ShowConsoleMsg("Advanced Toolbars: could not create config backup for " .. tostring(path) .. "\n")
    end
    local file = io.open(path, "w")
    if not file then
        reaper.ShowConsoleMsg("Advanced Toolbars: failed to open toolbar config for write: " .. tostring(path) .. "\n")
        return false
    end

    local ok = file:write("local config = " .. serialized_data .. "\n\nreturn config")
    file:close()
    if ok then
        self:invalidateToolbarConfigCache(toolbar_section)
        if type(config_table) == "table" then
            shared.toolbar_config_cache[toolbar_section] = config_table
        end
    end
    return ok and true or false
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

    local main_path = shared.getMainConfigPath()
    if not self:backupUserConfigFileBeforeWrite(main_path) then
        reaper.ShowConsoleMsg("Advanced Toolbars: could not create config backup for " .. tostring(main_path) .. "\n")
    end

    local file = io.open(main_path, "w")
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

function ConfigManager:requestSaveMainConfig()
    self._pending_main_save = true
    self._pending_main_save_at = reaper.time_precise() + shared.SAVE_DEBOUNCE_SEC
end

--- Debounced save for CONFIG.WIDGET_SAVED_STATES mutations (same coalesced write as main config).
function ConfigManager:requestSaveWidgetSavedStates()
    self:requestSaveMainConfig()
end

function ConfigManager:flushPendingSaves()
    local now = reaper.time_precise()
    local did = false

    if self._pending_main_save and now >= self._pending_main_save_at then
        self._pending_main_save = false
        if self:saveMainConfig() then
            did = true
        end
    end

    for section, pending in pairs(self._pending_toolbar_saves) do
        if now >= pending.at and pending.toolbar then
            self._pending_toolbar_saves[section] = nil
            if self:saveToolbarConfig(pending.toolbar) then
                did = true
            end
        end
    end

    return did
end

function ConfigManager:flushAllPendingSavesImmediate()
    local did = false

    if self._pending_main_save then
        self._pending_main_save = false
        if self:saveMainConfig() then
            did = true
        end
    end

    for section, pending in pairs(self._pending_toolbar_saves) do
        self._pending_toolbar_saves[section] = nil
        if pending.toolbar and self:saveToolbarConfig(pending.toolbar) then
            did = true
        end
    end

    return did
end

function ConfigManager:saveMainConfigImmediate()
    self._pending_main_save = false
    return self:saveMainConfig()
end

function ConfigManager:requestSaveToolbarConfig(toolbar)
    if not toolbar or not toolbar.section or toolbar.is_ephemeral then
        return false
    end
    self._pending_toolbar_saves[toolbar.section] = {
        toolbar = toolbar,
        at = reaper.time_precise() + shared.SAVE_DEBOUNCE_SEC,
    }
    return true
end

function ConfigManager:saveToolbarConfig(toolbar)
    if not toolbar then
        reaper.ShowConsoleMsg("Error: Attempt to save nil toolbar\n")
        return false
    end

    if toolbar.is_ephemeral then
        return false
    end

    if toolbar.section and self._pending_toolbar_saves then
        self._pending_toolbar_saves[toolbar.section] = nil
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
    -- instance_id ties each row to BUTTON_CUSTOM_PROPERTIES across reorders (drag-drop, ini round-trips).
    config_to_save.STRUCTURE.items = {}
    for _, button in ipairs(toolbar.buttons or {}) do
        table.insert(
            config_to_save.STRUCTURE.items,
            {
                id = button.id,
                text = button.original_text or "",
                instance_id = button.instance_id
            }
        )
    end
    if self:stripTrailingSeparatorsFromStructureItems(config_to_save) then
        self:rekeyButtonCustomPropertiesForStructure(config_to_save)
        self:syncToolbarGroupsToStructureItems(config_to_save)
    end
    config_to_save.STRUCTURE.title = toolbar.ini_title or config_to_save.STRUCTURE.title or toolbar.custom_name

    if not self:writeToolbarConfig(toolbar.section, config_to_save) then
        return false
    end

    -- Clear layout/button caches to force re-render (session toolbar config cache updated in writeToolbarConfig)
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

    -- Reset tracking variables on controller instances
    for _, controller_data in ipairs(_G.TOOLBAR_CONTROLLERS or {}) do
        local controller = controller_data.controller
        if controller then
            controller.last_min_width = nil
            controller.last_height = nil
            controller.last_spacing = nil
        end
    end
end

end
