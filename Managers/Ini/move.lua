-- Managers/Ini/move.lua — drag/move and group moves; loaded by Managers/Ini.lua

-- 1-based flat item index -> visual group index (separators id -1 start a new group after them).
local function flatItemGroupIndexForToolbarItems(items, flat_index)
    if not items or flat_index < 1 or flat_index > #items then
        return 1
    end
    local gid = 1
    for j = 1, flat_index - 1 do
        if tostring(items[j].id or "") == "-1" then
            gid = gid + 1
        end
    end
    return gid
end

-- Drag-drop mutates toolbar config STRUCTURE + rekeys props (lossy item_* round-trips cannot preserve duplicate ids).
function IniManager:moveButton(target_button, payload_data, drop_position)
    local target_section = target_button.parent_toolbar.section
    local source_section = payload_data.source_toolbar
    if not target_section or not source_section then
        return false
    end

    local function source_flat_index(cfg)
        if payload_data.is_separator and payload_data.separator_index then
            return CONFIG_MANAGER:findStructureFlatIndexForSeparator(cfg, payload_data.separator_index)
        end
        if payload_data.instance_id then
            return CONFIG_MANAGER:findStructureFlatIndexForInstanceId(cfg, payload_data.instance_id)
        end
        return nil
    end

    local function target_flat_index(cfg)
        if target_button:isSeparator() and target_button.separator_index then
            return CONFIG_MANAGER:findStructureFlatIndexForSeparator(cfg, target_button.separator_index)
        end
        return CONFIG_MANAGER:findStructureFlatIndexForInstanceId(cfg, target_button.instance_id)
    end

    local function shallow_row_copy(row)
        local c = { id = row.id, text = row.text or "" }
        if row.instance_id then
            c.instance_id = row.instance_id
        end
        return c
    end

    if source_section == target_section then
        local cfg = CONFIG_MANAGER:loadToolbarConfig(target_section)
        if type(cfg) ~= "table" then
            cfg = {}
        end
        cfg.STRUCTURE = cfg.STRUCTURE or {}
        cfg.STRUCTURE.items = cfg.STRUCTURE.items or {}
        CONFIG_MANAGER:hydrateStructureItemsInstanceIdsFromPropertyKeys(cfg)
        local items = cfg.STRUCTURE.items

        local si = source_flat_index(cfg)
        local ti = target_flat_index(cfg)
        if not si or not ti or si == ti then
            return false
        end

        local should_inherit_group_colors = false
        if not payload_data.is_separator then
            local source_gid = flatItemGroupIndexForToolbarItems(items, si)
            local row = table.remove(items, si)
            if si < ti then
                ti = ti - 1
            end
            local insert_index = drop_position == "after" and (ti + 1) or ti
            table.insert(items, insert_index, row)
            local dest_gid = flatItemGroupIndexForToolbarItems(items, insert_index)
            should_inherit_group_colors = (source_gid ~= dest_gid)
        else
            local row = table.remove(items, si)
            if si < ti then
                ti = ti - 1
            end
            local insert_index = drop_position == "after" and (ti + 1) or ti
            table.insert(items, insert_index, row)
        end

        cfg.SECTION = target_section
        CONFIG_MANAGER:syncToolbarGroupsToStructureItems(cfg)
        CONFIG_MANAGER:rekeyButtonCustomPropertiesForStructure(cfg)
        if not CONFIG_MANAGER:writeToolbarConfig(target_section, cfg) then
            return false
        end
        self:syncFileStateAfterScriptWrite()
        self:reloadToolbars()
        if should_inherit_group_colors then
            self:inheritGroupColorsForMovedButton(target_button, payload_data, target_section)
        end
        return true
    end

    local src_cfg = CONFIG_MANAGER:loadToolbarConfig(source_section)
    local tgt_cfg = CONFIG_MANAGER:loadToolbarConfig(target_section)
    if type(src_cfg) ~= "table" then
        src_cfg = {}
    end
    if type(tgt_cfg) ~= "table" then
        tgt_cfg = {}
    end
    src_cfg.STRUCTURE = src_cfg.STRUCTURE or {}
    src_cfg.STRUCTURE.items = src_cfg.STRUCTURE.items or {}
    tgt_cfg.STRUCTURE = tgt_cfg.STRUCTURE or {}
    tgt_cfg.STRUCTURE.items = tgt_cfg.STRUCTURE.items or {}

    CONFIG_MANAGER:hydrateStructureItemsInstanceIdsFromPropertyKeys(src_cfg)
    CONFIG_MANAGER:hydrateStructureItemsInstanceIdsFromPropertyKeys(tgt_cfg)

    local src_items = src_cfg.STRUCTURE.items
    local tgt_items = tgt_cfg.STRUCTURE.items

    local si = source_flat_index(src_cfg)
    local ti = target_flat_index(tgt_cfg)
    if not si or not ti then
        return false
    end

    local moved_props = CONFIG_MANAGER:copyPropsForStructureRow(src_cfg, si)
    local row = table.remove(src_items, si)
    local insert_index = drop_position == "after" and (ti + 1) or ti
    local copy = shallow_row_copy(row)
    if moved_props and moved_props.instance_id and not copy.instance_id then
        copy.instance_id = moved_props.instance_id
    end
    table.insert(tgt_items, insert_index, copy)

    if moved_props and moved_props.instance_id then
        tgt_cfg.BUTTON_CUSTOM_PROPERTIES = tgt_cfg.BUTTON_CUSTOM_PROPERTIES or {}
        tgt_cfg.BUTTON_CUSTOM_PROPERTIES["__at_moved_" .. tostring(moved_props.instance_id)] = moved_props
    end

    src_cfg.SECTION = source_section
    tgt_cfg.SECTION = target_section
    CONFIG_MANAGER:syncToolbarGroupsToStructureItems(src_cfg)
    CONFIG_MANAGER:syncToolbarGroupsToStructureItems(tgt_cfg)
    CONFIG_MANAGER:rekeyButtonCustomPropertiesForStructure(src_cfg)
    CONFIG_MANAGER:rekeyButtonCustomPropertiesForStructure(tgt_cfg)

    if not CONFIG_MANAGER:writeToolbarConfig(source_section, src_cfg) then
        return false
    end
    if not CONFIG_MANAGER:writeToolbarConfig(target_section, tgt_cfg) then
        return false
    end

    local should_inherit_group_colors = not payload_data.is_separator
    self:syncFileStateAfterScriptWrite()
    self:reloadToolbars()
    if should_inherit_group_colors then
        self:inheritGroupColorsForMovedButton(target_button, payload_data, target_section)
    end
    return true
end

-- Inclusive flat indices into toolbar.buttons / STRUCTURE.items order for one group.
function IniManager:flatItemRangeForGroup(toolbar, group_index)
    local g = toolbar.groups[group_index]
    if not g or #g.buttons == 0 then
        return nil, nil
    end

    -- Derive flat range by group sizes, not instance_id lookups.
    -- instance_id can be duplicated in copied configs, which can map to the wrong
    -- flat button range and corrupt cross-toolbar group moves.
    local si = 1
    for i = 1, group_index - 1 do
        local prev_group = toolbar.groups[i]
        si = si + ((prev_group and prev_group.buttons and #prev_group.buttons) or 0)
    end
    local ei = si + #g.buttons - 1

    if toolbar.buttons and (#toolbar.buttons < ei or si < 1) then
        return nil, nil
    end
    return si, ei
end

local function reorder_toolbar_group_entries(entries, source_gi, target_gi, drop_position)
    if source_gi == target_gi then
        return false
    end
    local moved = table.remove(entries, source_gi)
    local tg = target_gi
    if source_gi < target_gi then
        tg = target_gi - 1
    end
    local insert_at = drop_position == "before" and tg or (tg + 1)
    if insert_at < 1 then
        insert_at = 1
    end
    if insert_at > #entries + 1 then
        insert_at = #entries + 1
    end
    table.insert(entries, insert_at, moved)
    return true
end

function IniManager:moveGroup(source_section, source_gi, target_toolbar, target_gi, drop_position)
    local source_toolbar = self:findToolbarByMenuSection(source_section)
    if not source_toolbar or not target_toolbar then
        return false
    end
    if source_gi < 1 or source_gi > #source_toolbar.groups then
        return false
    end
    if target_gi < 1 or target_gi > #target_toolbar.groups then
        return false
    end
    if source_toolbar.section == target_toolbar.section and source_gi == target_gi then
        return false
    end

    local si, ei = self:flatItemRangeForGroup(source_toolbar, source_gi)
    local ti_s, ti_e = self:flatItemRangeForGroup(target_toolbar, target_gi)
    if not si or not ei or not ti_s or not ti_e then
        return false
    end

    if source_toolbar.section == target_toolbar.section then
        local cfg = CONFIG_MANAGER:loadToolbarConfig(source_toolbar.section)
        if type(cfg) ~= "table" then
            cfg = {}
        end
        cfg.STRUCTURE = cfg.STRUCTURE or {}
        cfg.STRUCTURE.items = cfg.STRUCTURE.items or {}
        CONFIG_MANAGER:hydrateStructureItemsInstanceIdsFromPropertyKeys(cfg)
        local items = cfg.STRUCTURE.items

        local dest = drop_position == "before" and ti_s or (ti_e + 1)
        local block_len = ei - si + 1
        local block = {}
        for i = ei, si, -1 do
            table.insert(block, 1, table.remove(items, i))
        end
        local new_dest = dest
        if si < dest then
            new_dest = dest - block_len
        end
        if new_dest < 1 then
            new_dest = 1
        end
        if new_dest > #items + 1 then
            new_dest = #items + 1
        end
        for i = 1, #block do
            table.insert(items, new_dest + i - 1, block[i])
        end

        cfg.SECTION = source_toolbar.section
        cfg.TOOLBAR_GROUPS = cfg.TOOLBAR_GROUPS or {}
        CONFIG_MANAGER:sanitizeToolbarGroupsMetadata(cfg, #source_toolbar.groups)
        reorder_toolbar_group_entries(cfg.TOOLBAR_GROUPS, source_gi, target_gi, drop_position)
        CONFIG_MANAGER:syncToolbarGroupsToStructureItems(cfg)
        CONFIG_MANAGER:rekeyButtonCustomPropertiesForStructure(cfg)
        if not CONFIG_MANAGER:writeToolbarConfig(source_toolbar.section, cfg) then
            return false
        end
        self:syncFileStateAfterScriptWrite()
        self:reloadToolbarsNow()
        return true
    end

    local src_cfg = CONFIG_MANAGER:loadToolbarConfig(source_section)
    local tgt_cfg = CONFIG_MANAGER:loadToolbarConfig(target_toolbar.section)
    if type(src_cfg) ~= "table" then
        src_cfg = {}
    end
    if type(tgt_cfg) ~= "table" then
        tgt_cfg = {}
    end
    src_cfg.STRUCTURE = src_cfg.STRUCTURE or {}
    src_cfg.STRUCTURE.items = src_cfg.STRUCTURE.items or {}
    tgt_cfg.STRUCTURE = tgt_cfg.STRUCTURE or {}
    tgt_cfg.STRUCTURE.items = tgt_cfg.STRUCTURE.items or {}
    CONFIG_MANAGER:hydrateStructureItemsInstanceIdsFromPropertyKeys(src_cfg)
    CONFIG_MANAGER:hydrateStructureItemsInstanceIdsFromPropertyKeys(tgt_cfg)

    local source_items = src_cfg.STRUCTURE.items
    local target_items = tgt_cfg.STRUCTURE.items
    if not si or not ei or not ti_s or not ti_e then
        return false
    end
    if si < 1 or ei > #source_items or ti_s < 1 or ti_e > #target_items then
        return false
    end
    local block_len = ei - si + 1
    local block = {}
    for i = ei, si, -1 do
        table.insert(block, 1, table.remove(source_items, i))
    end

    local tdest = drop_position == "before" and ti_s or (ti_e + 1)
    if tdest < 1 then
        tdest = 1
    end
    if tdest > #target_items + 1 then
        tdest = #target_items + 1
    end
    for i = 1, #block do
        table.insert(target_items, tdest + i - 1, block[i])
    end

    src_cfg.TOOLBAR_GROUPS = src_cfg.TOOLBAR_GROUPS or {}
    tgt_cfg.TOOLBAR_GROUPS = tgt_cfg.TOOLBAR_GROUPS or {}
    CONFIG_MANAGER:sanitizeToolbarGroupsMetadata(src_cfg, #source_toolbar.groups)
    CONFIG_MANAGER:sanitizeToolbarGroupsMetadata(tgt_cfg, #target_toolbar.groups)
    local moved_meta = table.remove(src_cfg.TOOLBAR_GROUPS, source_gi)
    local insert_at = drop_position == "before" and target_gi or (target_gi + 1)
    if insert_at < 1 then
        insert_at = 1
    end
    if insert_at > #tgt_cfg.TOOLBAR_GROUPS + 1 then
        insert_at = #tgt_cfg.TOOLBAR_GROUPS + 1
    end
    table.insert(tgt_cfg.TOOLBAR_GROUPS, insert_at, moved_meta)

    src_cfg.SECTION = source_section
    tgt_cfg.SECTION = target_toolbar.section
    CONFIG_MANAGER:syncToolbarGroupsToStructureItems(src_cfg)
    CONFIG_MANAGER:syncToolbarGroupsToStructureItems(tgt_cfg)
    CONFIG_MANAGER:rekeyButtonCustomPropertiesForStructure(src_cfg)
    CONFIG_MANAGER:rekeyButtonCustomPropertiesForStructure(tgt_cfg)
    if not CONFIG_MANAGER:writeToolbarConfig(source_section, src_cfg) then
        return false
    end
    if not CONFIG_MANAGER:writeToolbarConfig(target_toolbar.section, tgt_cfg) then
        return false
    end
    self:syncFileStateAfterScriptWrite()
    self:reloadToolbarsNow()
    return true
end

function IniManager:moveGroupToEmptySection(payload_data, target_section)
    local source_section = payload_data.source_toolbar
    local source_gi = payload_data.source_group_index
    if not source_section or not target_section or source_section == target_section then
        return false
    end
    if not source_gi then
        return false
    end

    local source_toolbar = self:findToolbarByMenuSection(source_section)
    local target_toolbar = self:findToolbarByMenuSection(target_section)
    if not source_toolbar or not target_toolbar then
        return false
    end

    local src_cfg = CONFIG_MANAGER:loadToolbarConfig(source_section)
    local tgt_cfg = CONFIG_MANAGER:loadToolbarConfig(target_section)
    if type(src_cfg) ~= "table" then
        src_cfg = {}
    end
    if type(tgt_cfg) ~= "table" then
        tgt_cfg = {}
    end
    src_cfg.STRUCTURE = src_cfg.STRUCTURE or {}
    src_cfg.STRUCTURE.items = src_cfg.STRUCTURE.items or {}
    tgt_cfg.STRUCTURE = tgt_cfg.STRUCTURE or {}
    tgt_cfg.STRUCTURE.items = tgt_cfg.STRUCTURE.items or {}
    CONFIG_MANAGER:hydrateStructureItemsInstanceIdsFromPropertyKeys(src_cfg)
    CONFIG_MANAGER:hydrateStructureItemsInstanceIdsFromPropertyKeys(tgt_cfg)

    local source_items = src_cfg.STRUCTURE.items
    local target_items = tgt_cfg.STRUCTURE.items
    if #target_items > 0 then
        return false
    end

    local si, ei = self:flatItemRangeForGroup(source_toolbar, source_gi)
    if not si or not ei then
        return false
    end
    if si < 1 or ei > #source_items then
        return false
    end

    local block = {}
    for i = ei, si, -1 do
        table.insert(block, 1, table.remove(source_items, i))
    end
    for j = 1, #block do
        table.insert(target_items, j, block[j])
    end

    src_cfg.TOOLBAR_GROUPS = src_cfg.TOOLBAR_GROUPS or {}
    tgt_cfg.TOOLBAR_GROUPS = tgt_cfg.TOOLBAR_GROUPS or {}
    CONFIG_MANAGER:sanitizeToolbarGroupsMetadata(src_cfg, #source_toolbar.groups)
    local moved_meta = table.remove(src_cfg.TOOLBAR_GROUPS, source_gi)

    src_cfg.SECTION = source_section
    tgt_cfg.SECTION = target_section
    tgt_cfg.TOOLBAR_GROUPS = { moved_meta }
    CONFIG_MANAGER:syncToolbarGroupsToStructureItems(src_cfg)
    CONFIG_MANAGER:syncToolbarGroupsToStructureItems(tgt_cfg)
    CONFIG_MANAGER:rekeyButtonCustomPropertiesForStructure(src_cfg)
    CONFIG_MANAGER:rekeyButtonCustomPropertiesForStructure(tgt_cfg)
    if not CONFIG_MANAGER:writeToolbarConfig(source_section, src_cfg) then
        return false
    end
    if not CONFIG_MANAGER:writeToolbarConfig(target_section, tgt_cfg) then
        return false
    end
    self:syncFileStateAfterScriptWrite()
    self:reloadToolbarsNow()
    return true
end

local function append_structure_row_as_new_group(items, row)
    if #items > 0 and tostring(items[#items].id or "") ~= "-1" then
        table.insert(items, { id = "-1", text = "", instance_id = ID_GENERATOR.generateButtonId() })
    end
    table.insert(items, row)
end

local function inherit_colors_for_trailing_new_group(self, target_section, payload_data)
    if not target_section or not payload_data or not payload_data.instance_id or payload_data.is_separator then
        return
    end
    local toolbar = self:findToolbarByMenuSection(target_section)
    if not toolbar or type(toolbar.buttons) ~= "table" then
        return
    end
    local moved_flat
    for i, b in ipairs(toolbar.buttons) do
        if b.instance_id == payload_data.instance_id then
            moved_flat = i
            break
        end
    end
    if not moved_flat or moved_flat < 2 then
        return
    end
    local donor
    for i = moved_flat - 1, 1, -1 do
        local b = toolbar.buttons[i]
        if b and not b:isSeparator() then
            donor = b
            break
        end
    end
    if donor then
        self:inheritGroupColorsForMovedButton(donor, payload_data, target_section)
    end
end

--- Move a normal button to the end of target section as its own group (inserts a separator when needed).
function IniManager:moveButtonAsNewGroupAtEnd(payload_data, target_section)
    if not target_section or not payload_data or payload_data.is_separator or not payload_data.instance_id then
        return false
    end
    local source_section = payload_data.source_toolbar
    if not source_section then
        return false
    end

    local function source_flat_index(cfg)
        return CONFIG_MANAGER:findStructureFlatIndexForInstanceId(cfg, payload_data.instance_id)
    end

    local function shallow_row_copy(row)
        local c = { id = row.id, text = row.text or "" }
        if row.instance_id then
            c.instance_id = row.instance_id
        end
        return c
    end

    if source_section == target_section then
        local cfg = CONFIG_MANAGER:loadToolbarConfig(target_section)
        if type(cfg) ~= "table" then
            cfg = {}
        end
        cfg.STRUCTURE = cfg.STRUCTURE or {}
        cfg.STRUCTURE.items = cfg.STRUCTURE.items or {}
        CONFIG_MANAGER:hydrateStructureItemsInstanceIdsFromPropertyKeys(cfg)
        local items = cfg.STRUCTURE.items
        local si = source_flat_index(cfg)
        if not si or si < 1 or si > #items then
            return false
        end
        local row = table.remove(items, si)
        append_structure_row_as_new_group(items, row)
        cfg.SECTION = target_section
        CONFIG_MANAGER:syncToolbarGroupsToStructureItems(cfg)
        CONFIG_MANAGER:rekeyButtonCustomPropertiesForStructure(cfg)
        if not CONFIG_MANAGER:writeToolbarConfig(target_section, cfg) then
            return false
        end
        self:syncFileStateAfterScriptWrite()
        self:reloadToolbars()
        inherit_colors_for_trailing_new_group(self, target_section, payload_data)
        return true
    end

    local src_cfg = CONFIG_MANAGER:loadToolbarConfig(source_section)
    local tgt_cfg = CONFIG_MANAGER:loadToolbarConfig(target_section)
    if type(src_cfg) ~= "table" then
        src_cfg = {}
    end
    if type(tgt_cfg) ~= "table" then
        tgt_cfg = {}
    end
    src_cfg.STRUCTURE = src_cfg.STRUCTURE or {}
    src_cfg.STRUCTURE.items = src_cfg.STRUCTURE.items or {}
    tgt_cfg.STRUCTURE = tgt_cfg.STRUCTURE or {}
    tgt_cfg.STRUCTURE.items = tgt_cfg.STRUCTURE.items or {}
    CONFIG_MANAGER:hydrateStructureItemsInstanceIdsFromPropertyKeys(src_cfg)
    CONFIG_MANAGER:hydrateStructureItemsInstanceIdsFromPropertyKeys(tgt_cfg)

    local src_items = src_cfg.STRUCTURE.items
    local tgt_items = tgt_cfg.STRUCTURE.items
    local si = source_flat_index(src_cfg)
    if not si or si < 1 or si > #src_items then
        return false
    end

    local moved_props = CONFIG_MANAGER:copyPropsForStructureRow(src_cfg, si)
    local row = table.remove(src_items, si)
    local copy = shallow_row_copy(row)
    if moved_props and moved_props.instance_id and not copy.instance_id then
        copy.instance_id = moved_props.instance_id
    end
    append_structure_row_as_new_group(tgt_items, copy)

    if moved_props and moved_props.instance_id then
        tgt_cfg.BUTTON_CUSTOM_PROPERTIES = tgt_cfg.BUTTON_CUSTOM_PROPERTIES or {}
        tgt_cfg.BUTTON_CUSTOM_PROPERTIES["__at_moved_" .. tostring(moved_props.instance_id)] = moved_props
    end

    src_cfg.SECTION = source_section
    tgt_cfg.SECTION = target_section
    CONFIG_MANAGER:syncToolbarGroupsToStructureItems(src_cfg)
    CONFIG_MANAGER:syncToolbarGroupsToStructureItems(tgt_cfg)
    CONFIG_MANAGER:rekeyButtonCustomPropertiesForStructure(src_cfg)
    CONFIG_MANAGER:rekeyButtonCustomPropertiesForStructure(tgt_cfg)

    if not CONFIG_MANAGER:writeToolbarConfig(source_section, src_cfg) then
        return false
    end
    if not CONFIG_MANAGER:writeToolbarConfig(target_section, tgt_cfg) then
        return false
    end

    self:syncFileStateAfterScriptWrite()
    self:reloadToolbars()
    inherit_colors_for_trailing_new_group(self, target_section, payload_data)
    return true
end
