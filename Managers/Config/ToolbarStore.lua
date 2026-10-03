-- Independent toolbar documents. REAPER toolbar definitions are only read by ToolbarImport.
return function(ConfigManager)
function ConfigManager:ensureToolbarStructureStoreInitialized()
    if #self:getToolbarConfigSections() == 0 then
        return self:createToolbar("New Toolbar") ~= nil
    end
    return true
end

function ConfigManager:createToolbar(name, items, button_properties)
    local existing, names = {}, {}
    for _, entry in ipairs(self:getToolbarConfigSections()) do
        existing[UTILS.getSafeFilename(entry.section):lower()] = true
        local cfg = self:loadToolbarConfig(entry.section)
        if cfg then
            names[cfg.CUSTOM_NAME or (cfg.STRUCTURE and cfg.STRUCTURE.title) or entry.section] = true
        end
    end

    local base = (type(name) == "string" and name:match("%S")) and name or "New Toolbar"
    name = base
    local suffix = 2
    while names[name] do
        name = string.format("%s (%d)", base, suffix)
        suffix = suffix + 1
    end

    -- Identity is independent of the display name and any native REAPER section.
    local section
    repeat
        section = "toolbar_" .. ID_GENERATOR.generateUUID()
    until not existing[section:lower()]

    local cfg = {
        SECTION = section,
        ORDER = self:nextToolbarConfigOrder(),
        CUSTOM_NAME = name,
        BUTTON_CUSTOM_PROPERTIES = self:deepCopy(button_properties or {}),
        TOOLBAR_GROUPS = {},
        STRUCTURE = { title = name, items = self:deepCopy(items or {}) },
    }
    self:hydrateStructureItemsInstanceIdsFromPropertyKeys(cfg)
    self:syncToolbarGroupsToStructureItems(cfg)
    if not self:writeToolbarConfig(section, cfg) then
        return nil
    end
    return section
end
end
