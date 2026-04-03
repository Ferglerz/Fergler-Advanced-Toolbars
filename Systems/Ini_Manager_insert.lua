-- Systems/Ini_Manager_insert.lua — insert / preset / delete operations; loaded by Ini_Manager.lua

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

-- First item in a section that currently has no item_* lines (empty toolbar in reaper-menu.ini).
function IniManager:insertFirstButtonInSection(toolbar_section, new_button)
    local lines = self:getLines()
    if not lines then return false end

    local section_start, section_end = self:findSection(lines, toolbar_section)
    if not section_start or not section_end then return false end

    local items = self:extractItems(lines, section_start, section_end)
    if #items > 0 then
        return false
    end

    local new_item = {
        original_line = UTILS.formatToolbarItemLine(0, new_button.id, new_button.original_text),
        id = new_button.id,
        text = new_button.original_text
    }
    table.insert(items, new_item)
    self:renumberItems(items)
    self:replaceSection(lines, section_start, section_end, items)
    local ok = self:writeFile(lines)
    if ok and actionNameRequiresAutoArmNotice(new_button and new_button.original_text) then
        queueUnderMouseAutoArmNotice()
    end
    return ok
end

-- Move a dragged item into a toolbar section that has no items (drop landing zone).
function IniManager:movePayloadToEmptySection(payload_data, target_section)
    local lines = self:getLines()
    if not lines then return false end

    local source_section = payload_data.source_toolbar
    if not source_section or not target_section or source_section == target_section then
        return false
    end

    local source_start, source_end = self:findSection(lines, source_section)
    local target_start, target_end = self:findSection(lines, target_section)
    if not source_start or not source_end or not target_start or not target_end then
        return false
    end

    local source_items = self:extractItems(lines, source_start, source_end)
    local target_items = self:extractItems(lines, target_start, target_end)
    if #target_items > 0 then
        return false
    end

    local function find_source_in_items(items)
        if payload_data.is_separator and payload_data.separator_index then
            local separator_count = 0
            for i, item in ipairs(items) do
                if item.id == "-1" then
                    separator_count = separator_count + 1
                    if separator_count == payload_data.separator_index then
                        return item, i
                    end
                end
            end
        else
            for i, item in ipairs(items) do
                if item.id == payload_data.button_id then
                    return item, i
                end
            end
        end
        return nil, nil
    end

    local source_item, source_index = find_source_in_items(source_items)
    if not source_item then
        return false
    end

    table.remove(source_items, source_index)
    table.insert(target_items, source_item)

    self:renumberItems(source_items)
    self:renumberItems(target_items)

    if source_start < target_start then
        self:replaceSection(lines, target_start, target_end, target_items)
        source_start, source_end = self:findSection(lines, source_section)
        self:replaceSection(lines, source_start, source_end, source_items)
    else
        self:replaceSection(lines, source_start, source_end, source_items)
        target_start, target_end = self:findSection(lines, target_section)
        self:replaceSection(lines, target_start, target_end, target_items)
    end

    return self:writeFile(lines)
end

-- Main operations (simplified)
function IniManager:insertButton(target_button, new_button, position)
    local lines = self:getLines()
    if not lines then return false end

    local style_snapshot = self:captureInsertionStyleSnapshot(target_button)
    local section_start, section_end = self:findSection(lines, target_button.parent_toolbar.section)
    if not section_start or not section_end then return false end

    local items = self:extractItems(lines, section_start, section_end)
    local target_index = self:findButton(target_button, items)
    if not target_index then return false end

    local new_item = {
        original_line = UTILS.formatToolbarItemLine(0, new_button.id, new_button.original_text),
        id = new_button.id,
        text = new_button.original_text
    }

    local insert_index = position == "after" and target_index + 1 or target_index
    table.insert(items, insert_index, new_item)

    self:renumberItems(items)
    self:replaceSection(lines, section_start, section_end, items)
    local ok = self:writeFile(lines)
    if not ok then
        return false
    end
    self:applyStyleSnapshotToInsertedRange(target_button.parent_toolbar.section, insert_index, 1, style_snapshot)
    if actionNameRequiresAutoArmNotice(new_button and new_button.original_text) then
        queueUnderMouseAutoArmNotice()
    end
    return true
end

-- Insert multiple toolbar items from preset action rows (id + display name) in order.
-- position "before" | "after" matches insertButton: new block sits before/after the target button.
function IniManager:insertPresetButtonSequence(target_button, action_rows, position)
    if not target_button or type(action_rows) ~= "table" or #action_rows == 0 then
        return false
    end

    local lines = self:getLines()
    if not lines then
        return false
    end

    local style_snapshot = self:captureInsertionStyleSnapshot(target_button)
    local section_start, section_end = self:findSection(lines, target_button.parent_toolbar.section)
    if not section_start or not section_end then
        return false
    end

    local items = self:extractItems(lines, section_start, section_end)
    local target_index = self:findButton(target_button, items)
    if not target_index then
        return false
    end

    local start_index = (position == "after") and (target_index + 1) or target_index
    local inserted_count = 0
    local should_warn_under_mouse_auto_arm = false
    for _, row in ipairs(action_rows) do
        local aid = tostring(row.action_id or "")
        local label = tostring(row.name or "Action")
        if aid ~= "" then
            if actionNameRequiresAutoArmNotice(label) then
                should_warn_under_mouse_auto_arm = true
            end
            local new_item = {
                original_line = UTILS.formatToolbarItemLine(0, aid, label),
                id = aid,
                text = label
            }
            inserted_count = inserted_count + 1
            table.insert(items, start_index + inserted_count - 1, new_item)
        end
    end

    if inserted_count == 0 then
        return false
    end

    self:renumberItems(items)
    self:replaceSection(lines, section_start, section_end, items)
    local ok = self:writeFile(lines)
    if not ok then
        return false
    end
    self:applyStyleSnapshotToInsertedRange(target_button.parent_toolbar.section, start_index, inserted_count, style_snapshot)
    if should_warn_under_mouse_auto_arm then
        queueUnderMouseAutoArmNotice()
    end
    return true
end

-- Insert a preset/cluster as its own group directly after the target button's current group.
-- Behavior:
--   1) Ensures a separator exists between current group and inserted group.
--   2) Inserts all action rows as buttons.
--   3) Appends a trailing separator so the inserted block is always a distinct group.
function IniManager:insertPresetGroupAfterCurrentGroup(target_button, action_rows)
    if not target_button or type(action_rows) ~= "table" or #action_rows == 0 then
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

    local lines = self:getLines()
    if not lines then
        return false
    end

    local style_snapshot = self:captureInsertionStyleSnapshot(target_button)
    local section_start, section_end = self:findSection(lines, target_button.parent_toolbar.section)
    if not section_start or not section_end then
        return false
    end

    local items = self:extractItems(lines, section_start, section_end)
    local target_index = self:findButton(target_button, items)
    if not target_index then
        return false
    end

    local group_end_index = #items
    for i = target_index, #items do
        if tostring(items[i].id or "") == "-1" then
            group_end_index = i
            break
        end
    end

    local insert_index = group_end_index + 1
    if not (group_end_index <= #items and tostring(items[group_end_index].id or "") == "-1") then
        table.insert(
            items,
            insert_index,
            {
                original_line = UTILS.formatToolbarItemLine(0, "-1", ""),
                id = "-1",
                text = ""
            }
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
                original_line = UTILS.formatToolbarItemLine(0, row.action_id, row.name),
                id = row.action_id,
                text = row.name
            }
        )
        inserted_actions = inserted_actions + 1
    end

    table.insert(
        items,
        insert_index + inserted_actions,
        {
            original_line = UTILS.formatToolbarItemLine(0, "-1", ""),
            id = "-1",
            text = ""
        }
    )

    self:renumberItems(items)
    self:replaceSection(lines, section_start, section_end, items)
    local ok = self:writeFile(lines)
    if not ok then
        return false
    end

    self:applyStyleSnapshotToInsertedRange(
        target_button.parent_toolbar.section,
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
    local lines = self:getLines()
    if not lines then return false end

    local section_start, section_end = self:findSection(lines, button_to_delete.parent_toolbar.section)
    if not section_start or not section_end then return false end

    local items = self:extractItems(lines, section_start, section_end)
    local button_position = self:findButton(button_to_delete, items)

    if button_position and button_position > 0 and button_position <= #items then
        table.remove(items, button_position)
    else
        return false
    end

    self:renumberItems(items)
    self:replaceSection(lines, section_start, section_end, items)
    return self:writeFile(lines)
end
