-- Managers/Config_Migration.lua
return function(ConfigManager)
-- User-config load policy (see .cursor/rules/no-backwards-compatibility.mdc):
--   migrateConfig — merge missing keys from DEFAULT_CONFIG only; never rename/read old key names.
--   stripRetired* — one-way removal of obsolete keys from disk on load (not aliasing).
--   normalizeToolbarControllerKeys — coerce numeric map keys to strings; not schema migration.
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

-- Button height cannot go below SIZES.MIN_HEIGHT (28).
function ConfigManager:enforceSizeLimits(config)
    if not config or type(config.SIZES) ~= "table" then
        return
    end
    local min_h = config.SIZES.MIN_HEIGHT or 28
    if type(config.SIZES.HEIGHT) == "number" then
        config.SIZES.HEIGHT = math.max(min_h, config.SIZES.HEIGHT)
    end
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

-- Remove obsolete pin-to-toolbar experiment keys from disk (one-way cleanup; not key aliasing).
function ConfigManager:stripRetiredToolbarPinExperiment(config_table)
    if type(config_table) ~= "table" or type(config_table.TOOLBAR_CONTROLLERS) ~= "table" then
        return false
    end
    local changed = false
    for _, t in pairs(config_table.TOOLBAR_CONTROLLERS) do
        if type(t) == "table" then
            if t.ui_pin_auto_offset ~= nil then
                t.ui_pin_auto_offset = nil
                changed = true
            end
            if t.toolbar_index ~= nil then
                t.toolbar_index = nil
                changed = true
            end
            local a = t.ui_anchor
            if type(a) == "string" and a:match("^toolbar:%d+$") then
                t.ui_pin = false
                t.ui_anchor = "off"
                changed = true
            end
        end
    end
    return changed
end

-- Migrate toolbar switch widget from global CONFIG.UI to per-toolbar-controller.
-- Also ensure every controller entry has an extra_rows array.
function ConfigManager:migrateToolbarSwitchToPerToolbar(config_table)
    if type(config_table) ~= "table" or type(config_table.TOOLBAR_CONTROLLERS) ~= "table" then
        return false
    end
    local changed = false
    -- Read the old global default (may already be absent on fresh installs)
    local global_switch = true
    if type(config_table.UI) == "table" and config_table.UI.ENABLE_TOOLBAR_SWITCH_WIDGET ~= nil then
        global_switch = config_table.UI.ENABLE_TOOLBAR_SWITCH_WIDGET == true
    end
    for _, t in pairs(config_table.TOOLBAR_CONTROLLERS) do
        if type(t) == "table" then
            if t.enable_toolbar_switch == nil then
                t.enable_toolbar_switch = global_switch
                changed = true
            end
            if t.extra_rows == nil then
                t.extra_rows = {}
                changed = true
            end
        end
    end
    return changed
end


end
