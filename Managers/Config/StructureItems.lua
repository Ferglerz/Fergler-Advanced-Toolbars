return function(ConfigManager)
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
    if not toolbar or toolbar.is_toolbar_switch_widget or toolbar.is_ephemeral or not toolbar.section then
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

end
