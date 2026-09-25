local TABLES = require("Utils.Core.table_utils")

return function(ConfigManager, shared)
local temp_sequence = 0

local function writeConfig(self, config, path)
    local ok, serialized = pcall(TABLES.serializeTable, config)
    if not ok or not serialized then
        reaper.ShowConsoleMsg("Advanced Toolbars: failed to serialize " .. tostring(path) .. ": " .. tostring(serialized) .. "\n")
        return false
    end
    local backup_called, backed_up = pcall(self.backupUserConfigFileBeforeWrite, self, path)
    if not backup_called or not backed_up then
        reaper.ShowConsoleMsg("Advanced Toolbars: could not back up " .. tostring(path)
            .. (backup_called and "" or ": " .. tostring(backed_up)) .. "\n")
        return false
    end

    temp_sequence = temp_sequence + 1
    local temp_path = path .. ".tmp." .. tostring(temp_sequence)
    local file, open_err = io.open(temp_path, "w")
    if not file then
        reaper.ShowConsoleMsg("Advanced Toolbars: failed to open " .. temp_path .. ": " .. tostring(open_err) .. "\n")
        return false
    end
    local called, write_ok, write_err = pcall(file.write, file, "local config = " .. serialized .. "\n\nreturn config")
    local close_called, close_ok, close_err = pcall(file.close, file)
    if not called or not write_ok or not close_called or not close_ok then
        os.remove(temp_path)
        reaper.ShowConsoleMsg("Advanced Toolbars: failed to write " .. path .. ": "
            .. tostring((not called and write_ok) or write_err or (not close_called and close_ok) or close_err) .. "\n")
        return false
    end

    local renamed, rename_err = os.rename(temp_path, path)
    if not renamed and reaper.GetOS():match("Win") then
        -- Windows cannot rename over an existing file. Keep the old file available
        -- for restoration until the replacement is in place.
        local old_path = temp_path .. ".old"
        local moved_old = os.rename(path, old_path)
        if moved_old then
            renamed, rename_err = os.rename(temp_path, path)
            if renamed then
                os.remove(old_path)
            else
                local restored, restore_err = os.rename(old_path, path)
                if not restored then
                    reaper.ShowConsoleMsg("Advanced Toolbars: restore failed; previous config is at "
                        .. old_path .. ": " .. tostring(restore_err) .. "\n")
                end
            end
        end
    end
    if not renamed then
        os.remove(temp_path)
        reaper.ShowConsoleMsg("Advanced Toolbars: failed to replace " .. path .. ": " .. tostring(rename_err) .. "\n")
        return false
    end
    return true
end

function ConfigManager:saveConfigToFile(config, file_path)
    return writeConfig(self, config, file_path)
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
    local path = shared.getToolbarConfigPath(toolbar_section)
    if writeConfig(self, config_table, path) then
        self:invalidateToolbarConfigCache(toolbar_section)
        if type(config_table) == "table" then
            shared.toolbar_config_cache[toolbar_section] = config_table
        end
        return true
    end
    return false
end
function ConfigManager:saveMainConfig()
    local config_to_save = {}
    for k, v in pairs(CONFIG) do
        config_to_save[k] = v
    end

    local main_path = shared.getMainConfigPath()
    if not writeConfig(self, config_to_save, main_path) then
        self:requestSaveMainConfig()
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
        if self:saveMainConfig() then
            self._pending_main_save = false
            did = true
        else
            self._pending_main_save_at = now + shared.SAVE_DEBOUNCE_SEC
        end
    end

    for section, pending in pairs(self._pending_toolbar_saves) do
        if now >= pending.at and pending.toolbar then
            if self:saveToolbarConfig(pending.toolbar) then
                did = true
            else
                pending.at = now + shared.SAVE_DEBOUNCE_SEC
            end
        end
    end

    return did
end

function ConfigManager:flushAllPendingSavesImmediate()
    local did = false

    if self._pending_main_save then
        if self:saveMainConfig() then
            self._pending_main_save = false
            did = true
        end
    end

    for section, pending in pairs(self._pending_toolbar_saves) do
        if pending.toolbar and self:saveToolbarConfig(pending.toolbar) then
            did = true
        end
    end

    return did
end

function ConfigManager:saveMainConfigImmediate()
    local saved = self:saveMainConfig()
    if saved then
        self._pending_main_save = false
    end
    return saved
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
        self:requestSaveToolbarConfig(toolbar)
        return false
    end
    if toolbar.section and self._pending_toolbar_saves then
        self._pending_toolbar_saves[toolbar.section] = nil
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
