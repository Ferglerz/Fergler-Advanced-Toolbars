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

local cached_default_config = nil

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

local shared = {
    SAVE_DEBOUNCE_SEC = 0.4,
    toolbar_config_cache = {},
    toolbar_sections_cache = nil,
    getMainConfigPath = getMainConfigPath,
    getToolbarConfigPath = getToolbarConfigPath,
    getToolbarConfigsDir = getToolbarConfigsDir,
    lightReadToolbarConfigMeta = lightReadToolbarConfigMeta,
}

require("Managers.Config.Backup")(ConfigManager)
require("Managers.Config.Migration")(ConfigManager)
require("Managers.Config.ColorCache")(ConfigManager)
require("Managers.Config.IniParser")(ConfigManager)
require("Managers.Config.ButtonProperties")(ConfigManager)
require("Managers.Config.StructureItems")(ConfigManager)
require("Managers.Config.Persistence")(ConfigManager, shared)
require("Managers.Config.ToolbarRegistry")(ConfigManager, shared)

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

function ConfigManager:cleanup()
end

return ConfigManager
