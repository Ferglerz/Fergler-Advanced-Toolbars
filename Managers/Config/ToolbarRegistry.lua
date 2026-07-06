return function(ConfigManager, shared)
function ConfigManager:invalidateToolbarConfigCache(section)
    if section then
        shared.toolbar_config_cache[section] = nil
    else
        shared.toolbar_config_cache = {}
    end
    shared.toolbar_sections_cache = nil
end
function ConfigManager:getToolbarConfigSections()
    if shared.toolbar_sections_cache then
        return shared.toolbar_sections_cache
    end

    local dir = shared.getToolbarConfigsDir()
    local files = UTILS.getFilesInDirectory(dir)
    local out = {}
    for _, file in ipairs(files or {}) do
        if type(file) == "string" and file:match("%.lua$") then
            local full = UTILS.joinPath(dir, file)
            local fallback = file:gsub("%.lua$", "")
            local section, order = shared.lightReadToolbarConfigMeta(full, fallback)
            local cached = shared.toolbar_config_cache[section]
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
    shared.toolbar_sections_cache = out
    return out
end

function ConfigManager:nextToolbarConfigOrder()
    local max_order = 0
    for _, s in ipairs(self:getToolbarConfigSections()) do
        max_order = math.max(max_order, tonumber(s.order) or 0)
    end
    return max_order + 1
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

end
