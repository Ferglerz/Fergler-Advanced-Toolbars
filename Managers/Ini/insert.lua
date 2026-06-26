-- Managers/Ini/insert.lua — insert / preset / delete operations; loaded by Managers/Ini.lua

local UNDER_MOUSE_CURSOR_PATTERN = "under mouse cursor"

local function actionNameRequiresAutoArmNotice(action_name)
    local name = tostring(action_name or ""):lower()
    return name:find(UNDER_MOUSE_CURSOR_PATTERN, 1, true) ~= nil
end

local function queueUnderMouseAutoArmNotice()
    if C and C.Interactions and C.Interactions.queueUnderMouseAutoArmNotice then
        C.Interactions:queueUnderMouseAutoArmNotice()
    end
end

-- First button in a toolbar section with no STRUCTURE rows (empty slot / placeholder click).
function IniManager:insertFirstButtonInSection(toolbar_section, new_button)
    if not toolbar_section or not new_button then
        return false
    end

    local cfg = CONFIG_MANAGER:loadToolbarConfig(toolbar_section)
    if type(cfg) ~= "table" then
        cfg = {}
    end
    cfg.STRUCTURE = cfg.STRUCTURE or {}
    cfg.STRUCTURE.items = cfg.STRUCTURE.items or {}
    if #(cfg.STRUCTURE.items) > 0 then
        return false
    end

    if not new_button.instance_id then
        new_button.instance_id = ID_GENERATOR.generateButtonId()
    end

    table.insert(
        cfg.STRUCTURE.items,
        {
            id = new_button.id,
            text = new_button.original_text or "",
            instance_id = new_button.instance_id
        }
    )
    cfg.SECTION = toolbar_section
    if not cfg.TOOLBAR_GROUPS or #cfg.TOOLBAR_GROUPS == 0 then
        cfg.TOOLBAR_GROUPS = { { group_label = { text = "" }, is_split_point_h = false, is_split_point_v = false } }
    end
    CONFIG_MANAGER:rekeyButtonCustomPropertiesForStructure(cfg)
    if not CONFIG_MANAGER:writeToolbarConfig(toolbar_section, cfg) then
        return false
    end
    self:reloadToolbarsNow()
    if actionNameRequiresAutoArmNotice(new_button and new_button.original_text) then
        queueUnderMouseAutoArmNotice()
    end
    return true
end

-- Move a dragged item into a toolbar section that has no items (drop landing zone).
function IniManager:movePayloadToEmptySection(payload_data, target_section)
    local source_section = payload_data.source_toolbar
    if not source_section or not target_section or source_section == target_section then
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

    if #(tgt_cfg.STRUCTURE.items) > 0 then
        return false
    end

    local si
    if payload_data.is_separator and payload_data.separator_index then
        si = CONFIG_MANAGER:findStructureFlatIndexForSeparator(src_cfg, payload_data.separator_index)
    elseif payload_data.instance_id then
        si = CONFIG_MANAGER:findStructureFlatIndexForInstanceId(src_cfg, payload_data.instance_id)
    end
    if not si then
        return false
    end

    local moved_props = CONFIG_MANAGER:copyPropsForStructureRow(src_cfg, si)
    local row = table.remove(src_cfg.STRUCTURE.items, si)
    local function shallow_row_copy(r)
        local c = { id = r.id, text = r.text or "" }
        if r.instance_id then
            c.instance_id = r.instance_id
        end
        return c
    end
    local copy = shallow_row_copy(row)
    if moved_props and moved_props.instance_id and not copy.instance_id then
        copy.instance_id = moved_props.instance_id
    end
    table.insert(tgt_cfg.STRUCTURE.items, copy)

    if moved_props and moved_props.instance_id then
        tgt_cfg.BUTTON_CUSTOM_PROPERTIES = tgt_cfg.BUTTON_CUSTOM_PROPERTIES or {}
        tgt_cfg.BUTTON_CUSTOM_PROPERTIES["__at_moved_" .. tostring(moved_props.instance_id)] = moved_props
    end

    src_cfg.SECTION = source_section
    tgt_cfg.SECTION = target_section
    CONFIG_MANAGER:rekeyButtonCustomPropertiesForStructure(src_cfg)
    CONFIG_MANAGER:rekeyButtonCustomPropertiesForStructure(tgt_cfg)

    if not CONFIG_MANAGER:writeToolbarConfig(source_section, src_cfg) then
        return false
    end
    if not CONFIG_MANAGER:writeToolbarConfig(target_section, tgt_cfg) then
        return false
    end

    self:reloadToolbars()
    return true
end

-- Insert via toolbar config (STRUCTURE.items + instance_id). Lines+merge breaks duplicate id/text rows (e.g. multiple widgets).
function IniManager:insertButton(target_button, new_button, position)
    if not target_button or not new_button or not target_button.parent_toolbar then
        return false
    end

    local section = target_button.parent_toolbar.section
    local style_snapshot = self:captureInsertionStyleSnapshot(target_button)

    local cfg = CONFIG_MANAGER:loadToolbarConfig(section)
    if type(cfg) ~= "table" then
        cfg = {}
    end
    cfg.STRUCTURE = cfg.STRUCTURE or {}
    cfg.STRUCTURE.items = cfg.STRUCTURE.items or {}
    CONFIG_MANAGER:hydrateStructureItemsInstanceIdsFromPropertyKeys(cfg)

    local ti
    if target_button:isSeparator() and target_button.separator_index then
        ti = CONFIG_MANAGER:findStructureFlatIndexForSeparator(cfg, target_button.separator_index)
    else
        ti = CONFIG_MANAGER:findStructureFlatIndexForInstanceId(cfg, target_button.instance_id)
    end
    if not ti then
        return false
    end

    if tostring(new_button.id or "") == "-1" and position == "after" and ti >= #(cfg.STRUCTURE.items) then
        return false
    end

    if not new_button.instance_id then
        new_button.instance_id = ID_GENERATOR.generateButtonId()
    end

    local insert_at = position == "after" and (ti + 1) or ti
    table.insert(
        cfg.STRUCTURE.items,
        insert_at,
        {
            id = new_button.id,
            text = new_button.original_text or "",
            instance_id = new_button.instance_id
        }
    )

    cfg.SECTION = section
    CONFIG_MANAGER:syncToolbarGroupsToStructureItems(cfg)
    CONFIG_MANAGER:rekeyButtonCustomPropertiesForStructure(cfg)
    if not CONFIG_MANAGER:writeToolbarConfig(section, cfg) then
        return false
    end
    self:applyStyleSnapshotToInsertedRange(section, insert_at, 1, style_snapshot)
    if actionNameRequiresAutoArmNotice(new_button and new_button.original_text) then
        queueUnderMouseAutoArmNotice()
    end
    return true
end

-- Insert multiple toolbar items from preset action rows (id + display name) in order.
-- position "before" | "after" matches insertButton: new block sits before/after the target button.
function IniManager:insertPresetButtonSequence(target_button, action_rows, position)
    if not target_button or not target_button.parent_toolbar or type(action_rows) ~= "table" or #action_rows == 0 then
        return false
    end

    local section = target_button.parent_toolbar.section
    local style_snapshot = self:captureInsertionStyleSnapshot(target_button)

    local cfg = CONFIG_MANAGER:loadToolbarConfig(section)
    if type(cfg) ~= "table" then
        cfg = {}
    end
    cfg.STRUCTURE = cfg.STRUCTURE or {}
    cfg.STRUCTURE.items = cfg.STRUCTURE.items or {}
    CONFIG_MANAGER:hydrateStructureItemsInstanceIdsFromPropertyKeys(cfg)

    local ti
    if target_button:isSeparator() and target_button.separator_index then
        ti = CONFIG_MANAGER:findStructureFlatIndexForSeparator(cfg, target_button.separator_index)
    else
        ti = CONFIG_MANAGER:findStructureFlatIndexForInstanceId(cfg, target_button.instance_id)
    end
    if not ti then
        return false
    end

    local start_index = (position == "after") and (ti + 1) or ti
    local insert_at = start_index
    local inserted_count = 0
    local should_warn_under_mouse_auto_arm = false
    for _, row in ipairs(action_rows) do
        local aid = tostring(row.action_id or "")
        local label = tostring(row.name or "Action")
        if aid ~= "" then
            if actionNameRequiresAutoArmNotice(label) then
                should_warn_under_mouse_auto_arm = true
            end
            table.insert(
                cfg.STRUCTURE.items,
                insert_at,
                {
                    id = aid,
                    text = label,
                    instance_id = ID_GENERATOR.generateButtonId()
                }
            )
            inserted_count = inserted_count + 1
            insert_at = insert_at + 1
        end
    end

    if inserted_count == 0 then
        return false
    end

    cfg.SECTION = section
    CONFIG_MANAGER:syncToolbarGroupsToStructureItems(cfg)
    CONFIG_MANAGER:rekeyButtonCustomPropertiesForStructure(cfg)
    if not CONFIG_MANAGER:writeToolbarConfig(section, cfg) then
        return false
    end
    self:applyStyleSnapshotToInsertedRange(section, start_index, inserted_count, style_snapshot)
    if should_warn_under_mouse_auto_arm then
        queueUnderMouseAutoArmNotice()
    end
    return true
end

-- Insert a preset/cluster as its own group directly after the target button's current group.
-- Behavior:
--   1) Ensures a separator exists between current group and inserted group.
--   2) Inserts all action rows as buttons.
--   3) Appends a separator after the block only when more items follow (never a trailing toolbar separator).
function IniManager:insertPresetGroupAfterCurrentGroup(target_button, action_rows)
    if not target_button or not target_button.parent_toolbar or type(action_rows) ~= "table" or #action_rows == 0 then
        return false
    end

    local valid_rows = {}
    local should_warn_under_mouse_auto_arm = false
    for _, row in ipairs(action_rows) do
        local aid = tostring(row.action_id or "")
        if aid ~= "" then
            local label = tostring(row.name or "Action")
            if actionNameRequiresAutoArmNotice(label) then
                should_warn_under_mouse_auto_arm = true
            end
            table.insert(
                valid_rows,
                {
                    action_id = aid,
                    name = label
                }
            )
        end
    end
    if #valid_rows == 0 then
        return false
    end

    local section = target_button.parent_toolbar.section
    local style_snapshot = self:captureInsertionStyleSnapshot(target_button)

    local cfg = CONFIG_MANAGER:loadToolbarConfig(section)
    if type(cfg) ~= "table" then
        cfg = {}
    end
    cfg.STRUCTURE = cfg.STRUCTURE or {}
    cfg.STRUCTURE.items = cfg.STRUCTURE.items or {}
    CONFIG_MANAGER:hydrateStructureItemsInstanceIdsFromPropertyKeys(cfg)

    local items = cfg.STRUCTURE.items
    local ti
    if target_button:isSeparator() and target_button.separator_index then
        ti = CONFIG_MANAGER:findStructureFlatIndexForSeparator(cfg, target_button.separator_index)
    else
        ti = CONFIG_MANAGER:findStructureFlatIndexForInstanceId(cfg, target_button.instance_id)
    end
    if not ti then
        return false
    end

    local group_end_index = #items
    for i = ti, #items do
        if tostring(items[i].id or "") == "-1" then
            group_end_index = i
            break
        end
    end

    local had_following_items = group_end_index < #items

    local insert_index = group_end_index + 1
    if not (group_end_index >= 1 and group_end_index <= #items and tostring(items[group_end_index].id or "") == "-1") then
        table.insert(
            items,
            insert_index,
            { id = "-1", text = "", instance_id = ID_GENERATOR.generateButtonId() }
        )
        insert_index = insert_index + 1
    end

    local first_action_index = insert_index
    local inserted_actions = 0
    for _, row in ipairs(valid_rows) do
        table.insert(
            items,
            insert_index + inserted_actions,
            {
                id = row.action_id,
                text = row.name,
                instance_id = ID_GENERATOR.generateButtonId()
            }
        )
        inserted_actions = inserted_actions + 1
    end

    if had_following_items then
        table.insert(
            items,
            insert_index + inserted_actions,
            { id = "-1", text = "", instance_id = ID_GENERATOR.generateButtonId() }
        )
    end

    cfg.SECTION = section
    CONFIG_MANAGER:syncToolbarGroupsToStructureItems(cfg)
    CONFIG_MANAGER:rekeyButtonCustomPropertiesForStructure(cfg)
    if not CONFIG_MANAGER:writeToolbarConfig(section, cfg) then
        return false
    end
    self:applyStyleSnapshotToInsertedRange(
        section,
        first_action_index,
        inserted_actions,
        style_snapshot
    )
    if should_warn_under_mouse_auto_arm then
        queueUnderMouseAutoArmNotice()
    end
    return true
end

function IniManager:deleteButton(button_to_delete)
    if not button_to_delete or not button_to_delete.parent_toolbar then
        return false
    end

    local section = button_to_delete.parent_toolbar.section
    local cfg = CONFIG_MANAGER:loadToolbarConfig(section)
    if type(cfg) ~= "table" then
        return false
    end
    cfg.STRUCTURE = cfg.STRUCTURE or {}
    cfg.STRUCTURE.items = cfg.STRUCTURE.items or {}
    CONFIG_MANAGER:hydrateStructureItemsInstanceIdsFromPropertyKeys(cfg)

    local pi
    if button_to_delete:isSeparator() and button_to_delete.separator_index then
        pi = CONFIG_MANAGER:findStructureFlatIndexForSeparator(cfg, button_to_delete.separator_index)
    else
        pi = CONFIG_MANAGER:findStructureFlatIndexForInstanceId(cfg, button_to_delete.instance_id)
    end
    if not pi or pi < 1 or pi > #cfg.STRUCTURE.items then
        return false
    end

    table.remove(cfg.STRUCTURE.items, pi)
    cfg.SECTION = section
    CONFIG_MANAGER:removeEmptyGroupsFromStructureItems(cfg)
    CONFIG_MANAGER:syncToolbarGroupsToStructureItems(cfg)
    CONFIG_MANAGER:rekeyButtonCustomPropertiesForStructure(cfg)
    if not CONFIG_MANAGER:writeToolbarConfig(section, cfg) then
        return false
    end
    self:reloadToolbarsNow()
    return true
end
