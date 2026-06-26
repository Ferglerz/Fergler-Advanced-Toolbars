-- Managers/Config.lua

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

local SAVE_DEBOUNCE_SEC = 0.4

local cached_default_config = nil
local toolbar_config_cache = {}
local toolbar_sections_cache = nil

local function loadDefaultConfigTable()
    if cached_default_config then
        return cached_default_config
    end
    local default_config_path = UTILS.joinPath(SCRIPT_PATH, "Systems/DEFAULT_CONFIG.lua")
    local default_config_loader = assert(loadfile(default_config_path), "Failed to load default config file")
    cached_default_config = default_config_loader()
    assert(type(cached_default_config) == "table", "Default config didn't return a valid table")
    return cached_default_config
end

local function lightReadToolbarConfigMeta(full_path, fallback_section)
    local file = io.open(full_path, "r")
    if not file then
        return fallback_section, 999999
    end
    local content = file:read("*a")
    file:close()
    if not content or content:match("^%s*$") then
        return fallback_section, 999999
    end
    local section = content:match('SECTION%s*=%s*"([^"]+)"')
        or content:match("SECTION%s*=%s*'([^']+)'")
        or fallback_section
    local order = tonumber(content:match("ORDER%s*=%s*(%d+)")) or 999999
    return section, order
end


require("Managers.Config.Backup")(ConfigManager)
require("Managers.Config.Migration")(ConfigManager)
require("Managers.Config.ColorCache")(ConfigManager)
require("Managers.Config.IniParser")(ConfigManager)
-- Helper function to save config to file
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

function ConfigManager.new()
    local self = setmetatable({}, ConfigManager)
    self.cached_colors = {}
    self._pending_main_save = false
    self._pending_main_save_at = 0
    self._pending_toolbar_saves = {}

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
            local default_config = loadDefaultConfigTable()
            local user_config = self:deepCopy(default_config)

            if self:saveConfigToFile(user_config, config_path) then
                _G.CONFIG = user_config
                self:enforceSizeLimits(_G.CONFIG)
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

            local default_config = loadDefaultConfigTable()

            -- Apply load policy: defaults merge, retired-key strip, controller key normalization
            local needs_save = self:migrateConfig(user_config, default_config)
            if self:normalizeToolbarControllerKeys(user_config) then
                needs_save = true
            end
            if self:stripRetiredToolbarPinExperiment(user_config) then
                needs_save = true
            end
            if self:migrateToolbarSwitchToPerToolbar(user_config) then
                needs_save = true
            end

            if needs_save then
                reaper.ShowConsoleMsg("Advanced Toolbars: Saved user config updates (missing defaults and/or retired-key cleanup)\n")
                -- Save the updated config
                self:saveConfigToFile(user_config, config_path)
            end

            _G.CONFIG = user_config
            self:enforceSizeLimits(_G.CONFIG)
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

    for i, button in ipairs(toolbar.buttons) do
        local canonical_key = C.ButtonDefinition.createPropertyKey(button.id, button.original_text, i - 1)
        button.property_key = canonical_key

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
                }
                if button.widget.exportPersistedOptions then
                    local ok, extra = pcall(button.widget.exportPersistedOptions, button.widget)
                    if ok and type(extra) == "table" then
                        props.widget.options = extra
                    end
                end
                if button.widget.default_snap_disabled ~= nil then
                    props.widget.options = props.widget.options or {}
                    props.widget.options.default_snap_disabled = button.widget.default_snap_disabled
                end
                if button.widget.knob_bg_direction ~= nil then
                    props.widget.options = props.widget.options or {}
                    props.widget.options.knob_bg_direction = button.widget.knob_bg_direction
                end
            end
        end

        if next(props) then
            button_properties[canonical_key] = props
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
                    is_split_point_h = group.is_split_point_h or false,
                    is_split_point_v = group.is_split_point_v or false
                }
            )
        end
    end
    return toolbar_groups
end

function ConfigManager:invalidateToolbarConfigCache(section)
    if section then
        toolbar_config_cache[section] = nil
    else
        toolbar_config_cache = {}
    end
    toolbar_sections_cache = nil
end

function ConfigManager:loadToolbarConfig(toolbar_section)
    if toolbar_config_cache[toolbar_section] then
        return toolbar_config_cache[toolbar_section]
    end

    local config_path = getToolbarConfigPath(toolbar_section)

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

    toolbar_config_cache[toolbar_section] = config
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

    local path = getToolbarConfigPath(toolbar_section)
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
            toolbar_config_cache[toolbar_section] = config_table
        end
    end
    return ok and true or false
end

function ConfigManager:getToolbarConfigSections()
    if toolbar_sections_cache then
        return toolbar_sections_cache
    end

    local dir = getToolbarConfigsDir()
    local files = UTILS.getFilesInDirectory(dir)
    local out = {}
    for _, file in ipairs(files or {}) do
        if type(file) == "string" and file:match("%.lua$") then
            local full = UTILS.joinPath(dir, file)
            local fallback = file:gsub("%.lua$", "")
            local section, order = lightReadToolbarConfigMeta(full, fallback)
            local cached = toolbar_config_cache[section]
            if cached then
                if type(cached.SECTION) == "string" and cached.SECTION ~= "" then
                    section = cached.SECTION
                end
                if cached.ORDER ~= nil then
                    order = tonumber(cached.ORDER) or order
                end
            end
            if section and section ~= "" then
                table.insert(out, { section = section, order = order })
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
    toolbar_sections_cache = out
    return out
end

function ConfigManager:nextToolbarConfigOrder()
    local max_order = 0
    for _, s in ipairs(self:getToolbarConfigSections()) do
        max_order = math.max(max_order, tonumber(s.order) or 0)
    end
    return max_order + 1
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

    local main_path = getMainConfigPath()
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
    self._pending_main_save_at = reaper.time_precise() + SAVE_DEBOUNCE_SEC
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
    if not toolbar or not toolbar.section then
        return false
    end
    self._pending_toolbar_saves[toolbar.section] = {
        toolbar = toolbar,
        at = reaper.time_precise() + SAVE_DEBOUNCE_SEC,
    }
    return true
end

function ConfigManager:saveToolbarConfig(toolbar)
    if not toolbar then
        reaper.ShowConsoleMsg("Error: Attempt to save nil toolbar\n")
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
    return self:requestSaveMainConfig()
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
    return self:requestSaveMainConfig()
end

function ConfigManager:saveConfig()
    return self:requestSaveMainConfig()
end

function ConfigManager:loadToolbarIndex(toolbar_id)
    local t = getControllerSettingsById(toolbar_id)
    if not t then
        return 1
    end
    return tonumber(t.last_toolbar_index) or 1
end

function ConfigManager:cleanup()
end

--- Copy instance_id from position-matched BUTTON_CUSTOM_PROPERTIES onto STRUCTURE.items, and assign new ids
--- for legacy props that lack them. Call only while STRUCTURE.items order matches property_key positions.
function ConfigManager:hydrateStructureItemsInstanceIdsFromPropertyKeys(cfg)
    if not cfg or type(cfg.STRUCTURE) ~= "table" then
        return false
    end
    local items = cfg.STRUCTURE.items
    if not items then
        return false
    end
    cfg.BUTTON_CUSTOM_PROPERTIES = cfg.BUTTON_CUSTOM_PROPERTIES or {}
    local props = cfg.BUTTON_CUSTOM_PROPERTIES
    local changed = false
    for i, item in ipairs(items) do
        local pk = C.ButtonDefinition.createPropertyKey(item.id, item.text, i - 1)
        local p = props[pk]
        if type(p) == "table" then
            if item.instance_id then
                -- STRUCTURE wins: insert/move assign row ids before BUTTON_CUSTOM_PROPERTIES has that slot.
                if p.instance_id ~= item.instance_id then
                    p.instance_id = item.instance_id
                    changed = true
                end
            elseif p.instance_id then
                item.instance_id = p.instance_id
                changed = true
            elseif not p.instance_id then
                local nid = ID_GENERATOR.generateButtonId()
                p.instance_id = nid
                item.instance_id = nid
                changed = true
            end
        elseif not item.instance_id then
            item.instance_id = ID_GENERATOR.generateButtonId()
            changed = true
        end
    end
    return changed
end

--- Remove trailing separator rows (id -1) from STRUCTURE.items; returns true if any removed.
function ConfigManager:stripTrailingSeparatorsFromStructureItems(cfg)
    if not cfg or type(cfg.STRUCTURE) ~= "table" then
        return false
    end
    local items = cfg.STRUCTURE.items
    if type(items) ~= "table" or #items == 0 then
        return false
    end
    local changed = false
    while #items > 0 and tostring(items[#items].id or "") == "-1" do
        table.remove(items)
        changed = true
    end
    return changed
end

--- Remove leading separators, collapse consecutive -1 rows, and strip trailing separators so STRUCTURE
--- has no empty groups (segments with no non-separator buttons). Returns true if any row was removed.
function ConfigManager:removeEmptyGroupsFromStructureItems(cfg)
    if not cfg or type(cfg.STRUCTURE) ~= "table" then
        return false
    end
    local items = cfg.STRUCTURE.items
    if type(items) ~= "table" or #items == 0 then
        return false
    end
    local changed = false
    changed = self:stripTrailingSeparatorsFromStructureItems(cfg) or changed
    while #items > 0 and tostring(items[1].id or "") == "-1" do
        table.remove(items, 1)
        changed = true
    end
    changed = self:stripTrailingSeparatorsFromStructureItems(cfg) or changed
    local again = true
    while again do
        again = false
        local i = 1
        while i < #items do
            if tostring(items[i].id or "") == "-1" and tostring(items[i + 1].id or "") == "-1" then
                table.remove(items, i + 1)
                changed = true
                again = true
            else
                i = i + 1
            end
        end
    end
    changed = self:stripTrailingSeparatorsFromStructureItems(cfg) or changed
    while #items > 0 and tostring(items[1].id or "") == "-1" do
        table.remove(items, 1)
        changed = true
    end
    changed = self:stripTrailingSeparatorsFromStructureItems(cfg) or changed
    return changed
end

--- Group count implied by STRUCTURE.items order (must match Parsing/Parse_Toolbars.handleGroups).
function ConfigManager:countGroupsFromStructureItems(items)
    if not items or #items == 0 then
        return 0
    end
    local last_was_separator = false
    local groups = 0
    local current_size = 0
    for i, item in ipairs(items) do
        local is_sep = tostring(item.id or "") == "-1"
        current_size = current_size + 1
        if is_sep then
            last_was_separator = true
            groups = groups + 1
            if i < #items then
                current_size = 0
            end
        else
            last_was_separator = false
        end
    end
    if current_size > 0 and not last_was_separator then
        groups = groups + 1
    end
    return groups
end

--- Keep TOOLBAR_GROUPS length aligned with STRUCTURE.items (call after any flat row insert/remove).
function ConfigManager:syncToolbarGroupsToStructureItems(cfg)
    if not cfg or type(cfg.STRUCTURE) ~= "table" then
        return false
    end
    local items = cfg.STRUCTURE.items or {}
    local n = self:countGroupsFromStructureItems(items)
    if n < 1 then
        cfg.TOOLBAR_GROUPS = cfg.TOOLBAR_GROUPS or {}
        if #cfg.TOOLBAR_GROUPS > 0 then
            cfg.TOOLBAR_GROUPS = {}
            return true
        end
        return false
    end
    return self:sanitizeToolbarGroupsMetadata(cfg, n)
end

--- Trim or pad TOOLBAR_GROUPS so length matches derived group count from buttons (avoids empty/extra metadata).
function ConfigManager:sanitizeToolbarGroupsMetadata(cfg, num_groups)
    if not cfg or type(num_groups) ~= "number" or num_groups < 1 then
        return false
    end
    cfg.TOOLBAR_GROUPS = cfg.TOOLBAR_GROUPS or {}
    local tg = cfg.TOOLBAR_GROUPS
    local changed = false
    while #tg > num_groups do
        table.remove(tg)
        changed = true
    end
    while #tg < num_groups do
        table.insert(
            tg,
            {
                group_label = { text = "" },
                is_split_point_h = false,
                is_split_point_v = false
            }
        )
        changed = true
    end
    return changed
end

--- Hydrate ids + fix TOOLBAR_GROUPS length; write disk if anything changed (safe to call after parse).
function ConfigManager:persistToolbarConfigSanitize(toolbar)
    if not toolbar or toolbar.is_toolbar_switch_widget or not toolbar.section then
        return false
    end
    local cfg = self:loadToolbarConfig(toolbar.section)
    if type(cfg) ~= "table" then
        return false
    end
    cfg.STRUCTURE = cfg.STRUCTURE or {}
    cfg.STRUCTURE.items = cfg.STRUCTURE.items or {}
    local s = self:stripTrailingSeparatorsFromStructureItems(cfg)
    local e = self:removeEmptyGroupsFromStructureItems(cfg)
    if s or e then
        self:rekeyButtonCustomPropertiesForStructure(cfg)
    end
    local h = self:hydrateStructureItemsInstanceIdsFromPropertyKeys(cfg)
    local g = self:syncToolbarGroupsToStructureItems(cfg)
    if not s and not e and not h and not g then
        return false
    end
    cfg.SECTION = toolbar.section
    return self:writeToolbarConfig(toolbar.section, cfg)
end

--- Rebuild BUTTON_CUSTOM_PROPERTY keys from current STRUCTURE.items order (uses instance_id on each row).
function ConfigManager:rekeyButtonCustomPropertiesForStructure(cfg)
    if not cfg or type(cfg.STRUCTURE) ~= "table" then
        return
    end
    local items = cfg.STRUCTURE.items or {}
    local old_props = cfg.BUTTON_CUSTOM_PROPERTIES or {}
    local by_inst = {}
    for _, p in pairs(old_props) do
        if type(p) == "table" and p.instance_id then
            by_inst[p.instance_id] = p
        end
    end
    local new_props = {}
    for i, item in ipairs(items) do
        local key = C.ButtonDefinition.createPropertyKey(item.id, item.text, i - 1)
        local p = item.instance_id and by_inst[item.instance_id] or nil
        if p then
            new_props[key] = p
        end
    end
    cfg.BUTTON_CUSTOM_PROPERTIES = new_props
end

function ConfigManager:findStructureFlatIndexForSeparator(cfg, separator_index)
    if not cfg or not separator_index then
        return nil
    end
    local items = cfg.STRUCTURE and cfg.STRUCTURE.items
    if not items then
        return nil
    end
    local count = 0
    for i, item in ipairs(items) do
        if tostring(item.id or "") == "-1" then
            count = count + 1
            if count == separator_index then
                return i
            end
        end
    end
    return nil
end

function ConfigManager:findStructureFlatIndexForInstanceId(cfg, instance_id)
    if not cfg or not instance_id then
        return nil
    end
    local items = cfg.STRUCTURE and cfg.STRUCTURE.items
    if not items then
        return nil
    end
    for i, item in ipairs(items) do
        if item.instance_id == instance_id then
            return i
        end
    end
    for i, item in ipairs(items) do
        local pk = C.ButtonDefinition.createPropertyKey(item.id, item.text, i - 1)
        local p = cfg.BUTTON_CUSTOM_PROPERTIES and cfg.BUTTON_CUSTOM_PROPERTIES[pk]
        if type(p) == "table" and p.instance_id == instance_id then
            return i
        end
    end
    return nil
end

function ConfigManager:copyPropsForStructureRow(cfg, flat_index)
    if not cfg or not flat_index or flat_index < 1 then
        return nil
    end
    local items = cfg.STRUCTURE and cfg.STRUCTURE.items
    local item = items and items[flat_index]
    if not item then
        return nil
    end
    local key = C.ButtonDefinition.createPropertyKey(item.id, item.text, flat_index - 1)
    return cfg.BUTTON_CUSTOM_PROPERTIES and cfg.BUTTON_CUSTOM_PROPERTIES[key] or nil
end

-- Collect every toolbar index currently in use by any controller (primary + extra_rows).
function ConfigManager:getAllUsedToolbarIndices()
    local used = {}
    if not CONFIG or not CONFIG.TOOLBAR_CONTROLLERS then
        return used
    end
    for _, ctrl in pairs(CONFIG.TOOLBAR_CONTROLLERS) do
        if type(ctrl) == "table" then
            if ctrl.last_toolbar_index then
                used[tonumber(ctrl.last_toolbar_index)] = true
            end
            if type(ctrl.extra_rows) == "table" then
                for _, row in ipairs(ctrl.extra_rows) do
                    if type(row) == "table" and row.toolbar_index then
                        used[tonumber(row.toolbar_index)] = true
                    end
                end
            end
        end
    end
    return used
end

-- Find the first toolbar index not used by any controller (primary or extra row).
function ConfigManager:findNextUnusedToolbarIndex(toolbars)
    if not toolbars or #toolbars == 0 then
        return 1
    end
    local used = self:getAllUsedToolbarIndices()
    for i = 1, #toolbars do
        if not used[i] then
            return i
        end
    end
    -- All in use; return 1 as fallback
    return 1
end

return ConfigManager