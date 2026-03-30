-- Systems/Ini_Manager.lua

local IniManager = {}
IniManager.__index = IniManager
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

function IniManager.new()
    local self = setmetatable({}, IniManager)
    self.last_file_size = nil
    self.last_file_hash = nil
    self.last_script_write_time = nil
    self.cached_content = nil
    return self
end

-- Core file operations
function IniManager:getMenuIniPath()
    return reaper.GetResourcePath() .. "/reaper-menu.ini"
end

function IniManager:loadContent(silent)
    local menu_path = self:getMenuIniPath()
    local file = io.open(menu_path, "r")
    if not file then
        if not silent then
            reaper.ShowMessageBox("Could not open reaper-menu.ini", "Error", 0)
        end
        return nil
    end

    local content = file:read("*all")
    file:close()

    self.cached_content = content
    return content
end

function IniManager:checkForFileChanges()
    -- Runtime is sourced from User toolbar config files. reaper-menu.ini is template-only.
    return false
end

--- Call when leaving Advanced Toolbar edit mode so we do not reload on the next tick after REAPER rewrote the file mid-edit.
function IniManager:onExitToolbarEditMode()
    return
end

--- Call after writing reaper-menu.ini from this script so the file watcher matches disk and grace applies.
function IniManager:syncFileStateAfterScriptWrite()
    self.last_script_write_time = reaper.time_precise()
end

function IniManager:getContent()
    if not self.cached_content then
        return self:loadContent()
    end
    return self.cached_content
end

function IniManager:getLines()
    local ini_content = self:loadContent(true)
    return CONFIG_MANAGER:buildRuntimeLinesFromToolbarConfigs(ini_content)
end

function IniManager:writeFile(lines)
    local ok = CONFIG_MANAGER:writeRuntimeLinesToToolbarConfigs(lines)
    if not ok then
        reaper.ShowConsoleMsg("Advanced Toolbars: failed to write runtime toolbar config structure\n")
        return false
    end

    self:syncFileStateAfterScriptWrite()
    self:reloadToolbars()
    return true
end

-- Toolbar section operations
function IniManager:findSection(lines, toolbar_section)
    local section_start, section_end
    local in_section = false

    for i, line in ipairs(lines) do
        local section_match = line:match("%[(.+)%]")
        if section_match then
            if section_match == toolbar_section then
                section_start = i
                in_section = true
            elseif in_section then
                section_end = i - 1
                break
            end
        end
    end

    if in_section and not section_end then
        section_end = #lines
    end

    return section_start, section_end
end

function IniManager:extractItems(lines, section_start, section_end)
    local items = {}

    for i = section_start + 1, section_end do
        local line = lines[i]
        if line:match("^item_%d+") then
            local id, text = line:match("^item_%d+=(%S+)%s*(.*)$")
            if id then
                table.insert(items, {
                    original_line = line,
                    id = id,
                    text = text
                })
            end
        end
    end

    return items
end

function IniManager:renumberItems(items)
    for i, item in ipairs(items) do
        if item.id == "-1" then
            item.original_line = string.format("item_%d=%s", i-1, item.id)
        else
            item.original_line = string.format("item_%d=%s %s", i-1, item.id, item.text)
        end
    end
end

function IniManager:replaceSection(lines, section_start, section_end, items)
    -- Remove old items
    for i = section_end, section_start + 1, -1 do
        if lines[i] and lines[i]:match("^item_%d+") then
            table.remove(lines, i)
        end
    end

    -- Insert new items
    for i, item in ipairs(items) do
        table.insert(lines, section_start + i, item.original_line)
    end
end

local function deepCopyTable(value)
    if type(value) ~= "table" then
        return value
    end
    if CONFIG_MANAGER and CONFIG_MANAGER.deepCopy then
        return CONFIG_MANAGER:deepCopy(value)
    end
    local out = {}
    for k, v in pairs(value) do
        out[k] = deepCopyTable(v)
    end
    return out
end

function IniManager:captureInsertionStyleSnapshot(target_button)
    if not target_button then
        return nil
    end

    local source_button = target_button
    if C.ButtonRenderer and C.ButtonRenderer.getInsertionColorSource then
        source_button = C.ButtonRenderer:getInsertionColorSource(target_button) or target_button
    end

    if not source_button then
        return nil
    end

    return {
        custom_color = source_button.custom_color and deepCopyTable(source_button.custom_color) or nil,
        user_colors = source_button.user_colors and deepCopyTable(source_button.user_colors) or nil,
        border_offset = source_button.border_offset and {
            saturation = source_button.border_offset.saturation or 0.0,
            value = source_button.border_offset.value or 0.0
        } or nil
    }
end

function IniManager:applyStyleSnapshotToInsertedRange(toolbar_section, start_index, count, style_snapshot)
    if not toolbar_section or not style_snapshot or not start_index or start_index < 1 or (count or 0) < 1 then
        return false
    end

    -- writeFile() schedules reload on defer; force a synchronous reload here so we edit the
    -- freshly inserted buttons instead of saving stale pre-insert toolbar state.
    self:reloadToolbarsNow()

    local toolbar = self:findToolbarByMenuSection(toolbar_section)
    if not toolbar or type(toolbar.buttons) ~= "table" then
        return false
    end

    local applied = false
    local last_index = math.min(#toolbar.buttons, start_index + count - 1)
    for i = start_index, last_index do
        local button = toolbar.buttons[i]
        if button and not button:isSeparator() then
            button.custom_color = style_snapshot.custom_color and deepCopyTable(style_snapshot.custom_color) or nil
            button.user_colors = style_snapshot.user_colors and deepCopyTable(style_snapshot.user_colors) or nil
            if style_snapshot.border_offset then
                button.border_offset = {
                    saturation = style_snapshot.border_offset.saturation or 0.0,
                    value = style_snapshot.border_offset.value or 0.0
                }
            end
            if button.clearLayoutCache then
                button:clearLayoutCache()
            elseif button.clearCache then
                button:clearCache()
            end
            applied = true
        end
    end

    if applied and CONFIG_MANAGER then
        CONFIG_MANAGER:saveToolbarConfig(toolbar)
    end

    return applied
end

-- Unified button finder
function IniManager:findButton(button, items)
    -- Try by toolbar position first
    if button.parent_toolbar and button.parent_toolbar.buttons then
        for i, toolbar_button in ipairs(button.parent_toolbar.buttons) do
            if toolbar_button.instance_id == button.instance_id then
                return i
            end
        end
    end

    -- For separators, use separator index
    if button:isSeparator() and button.separator_index then
        local separator_count = 0
        for i, item in ipairs(items) do
            if item.id == "-1" then
                separator_count = separator_count + 1
                if separator_count == button.separator_index then
                    return i
                end
            end
        end
    end

    -- Fallback to ID match
    for i, item in ipairs(items) do
        if item.id == button.id then
            return i
        end
    end

    return nil
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
        original_line = new_button.id == "-1" and
            string.format("item_0=%s", new_button.id) or
            string.format("item_0=%s %s", new_button.id, new_button.original_text),
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

    -- Create new item
    local new_item = {
        original_line = new_button.id == "-1" and
            string.format("item_0=%s", new_button.id) or
            string.format("item_0=%s %s", new_button.id, new_button.original_text),
        id = new_button.id,
        text = new_button.original_text
    }

    -- Insert at correct position
    local insert_index = position == "after" and target_index + 1 or target_index
    table.insert(items, insert_index, new_item)

    -- Write changes
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
                original_line = string.format("item_0=%s %s", aid, label),
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

    -- Find the current group's end in flat item order.
    local group_end_index = #items
    for i = target_index, #items do
        if tostring(items[i].id or "") == "-1" then
            group_end_index = i
            break
        end
    end

    -- Ensure there is a separator between current group and inserted group.
    local insert_index = group_end_index + 1
    if not (group_end_index <= #items and tostring(items[group_end_index].id or "") == "-1") then
        table.insert(
            items,
            insert_index,
            {
                original_line = "item_0=-1",
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
                original_line = string.format("item_0=%s %s", row.action_id, row.name),
                id = row.action_id,
                text = row.name
            }
        )
        inserted_actions = inserted_actions + 1
    end

    -- Always terminate the inserted cluster with a separator to keep it as a distinct group.
    table.insert(
        items,
        insert_index + inserted_actions,
        {
            original_line = "item_0=-1",
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

function IniManager:moveButton(target_button, payload_data, drop_position)
    local lines = self:getLines()
    if not lines then return false end

    local target_section = target_button.parent_toolbar.section
    local source_section = payload_data.source_toolbar
    if not target_section or not source_section then return false end

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

    if source_section == target_section then
        local section_start, section_end = self:findSection(lines, target_section)
        if not section_start or not section_end then return false end

        local items = self:extractItems(lines, section_start, section_end)
        local source_item, source_index = find_source_in_items(items)
        local target_index = self:findButton(target_button, items)

        if not source_item or not target_index or source_index == target_index then
            return false
        end

        table.remove(items, source_index)
        if source_index < target_index then
            target_index = target_index - 1
        end

        local insert_index = drop_position == "after" and target_index + 1 or target_index
        table.insert(items, insert_index, source_item)

        self:renumberItems(items)
        self:replaceSection(lines, section_start, section_end, items)
        return self:writeFile(lines)
    end

    -- Cross-toolbar: remove from source INI section, insert relative to target in another section
    local source_start, source_end = self:findSection(lines, source_section)
    local target_start, target_end = self:findSection(lines, target_section)
    if not source_start or not source_end or not target_start or not target_end then
        return false
    end

    local source_items = self:extractItems(lines, source_start, source_end)
    local target_items = self:extractItems(lines, target_start, target_end)

    local source_item, source_index = find_source_in_items(source_items)
    local target_index = self:findButton(target_button, target_items)

    if not source_item or not target_index then
        return false
    end

    table.remove(source_items, source_index)
    local insert_index = drop_position == "after" and target_index + 1 or target_index
    table.insert(target_items, insert_index, source_item)

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

function IniManager:findToolbarByMenuSection(section)
    if not section then
        return nil
    end
    for _, cd in ipairs(_G.TOOLBAR_CONTROLLERS or {}) do
        local c = cd.controller
        if c and c.toolbars then
            for _, tb in ipairs(c.toolbars) do
                if tb.section == section then
                    return tb
                end
            end
        end
    end
    return nil
end

-- Inclusive flat indices into toolbar.buttons / extractItems order for one group.
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

    -- Sanity-check against extracted section item count shape; when out of sync,
    -- fail fast and let callers abort the move instead of mutating wrong groups.
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

    local lines = self:getLines()
    if not lines then
        return false
    end

    if source_toolbar.section == target_toolbar.section then
        local section_start, section_end = self:findSection(lines, source_toolbar.section)
        if not section_start or not section_end then
            return false
        end
        local items = self:extractItems(lines, section_start, section_end)
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
        self:renumberItems(items)
        self:replaceSection(lines, section_start, section_end, items)

        local entries = CONFIG_MANAGER:collectToolbarGroups(source_toolbar)
        reorder_toolbar_group_entries(entries, source_gi, target_gi, drop_position)
        if not CONFIG_MANAGER:saveToolbarGroupsOnly(source_toolbar.section, entries) then
            reaper.ShowConsoleMsg(
                "Advanced Toolbars: failed to save TOOLBAR_GROUPS after group move (" .. tostring(source_toolbar.section) .. ")\n"
            )
        end
        return self:writeFile(lines)
    end

    local source_start, source_end = self:findSection(lines, source_section)
    local target_start, target_end = self:findSection(lines, target_toolbar.section)
    if not source_start or not source_end or not target_start or not target_end then
        return false
    end

    local source_items = self:extractItems(lines, source_start, source_end)
    local target_items = self:extractItems(lines, target_start, target_end)

    si, ei = self:flatItemRangeForGroup(source_toolbar, source_gi)
    ti_s, ti_e = self:flatItemRangeForGroup(target_toolbar, target_gi)
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

    self:renumberItems(source_items)
    self:renumberItems(target_items)

    local src_entries = CONFIG_MANAGER:collectToolbarGroups(source_toolbar)
    local tgt_entries = CONFIG_MANAGER:collectToolbarGroups(target_toolbar)
    local moved_meta = table.remove(src_entries, source_gi)
    local insert_at = drop_position == "before" and target_gi or (target_gi + 1)
    if insert_at < 1 then
        insert_at = 1
    end
    if insert_at > #tgt_entries + 1 then
        insert_at = #tgt_entries + 1
    end
    table.insert(tgt_entries, insert_at, moved_meta)

    if not CONFIG_MANAGER:saveToolbarGroupsOnly(source_toolbar.section, src_entries) then
        reaper.ShowConsoleMsg(
            "Advanced Toolbars: failed to save TOOLBAR_GROUPS after group move (" .. tostring(source_toolbar.section) .. ")\n"
        )
    end
    if not CONFIG_MANAGER:saveToolbarGroupsOnly(target_toolbar.section, tgt_entries) then
        reaper.ShowConsoleMsg(
            "Advanced Toolbars: failed to save TOOLBAR_GROUPS after group move (" .. tostring(target_toolbar.section) .. ")\n"
        )
    end

    if source_start < target_start then
        self:replaceSection(lines, target_start, target_end, target_items)
        source_start, source_end = self:findSection(lines, source_section)
        self:replaceSection(lines, source_start, source_end, source_items)
    else
        self:replaceSection(lines, source_start, source_end, source_items)
        target_start, target_end = self:findSection(lines, target_toolbar.section)
        self:replaceSection(lines, target_start, target_end, target_items)
    end

    return self:writeFile(lines)
end

function IniManager:moveGroupToEmptySection(payload_data, target_section)
    local lines = self:getLines()
    if not lines then
        return false
    end
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

    local si, ei = self:flatItemRangeForGroup(source_toolbar, source_gi)
    if not si or not ei then
        return false
    end
    if si < 1 or ei > #source_items then
        return false
    end

    local block_len = ei - si + 1
    local block = {}
    for i = ei, si, -1 do
        table.insert(block, 1, table.remove(source_items, i))
    end
    for j = 1, #block do
        table.insert(target_items, j, block[j])
    end

    self:renumberItems(source_items)
    self:renumberItems(target_items)

    local src_entries = CONFIG_MANAGER:collectToolbarGroups(source_toolbar)
    local moved_meta = table.remove(src_entries, source_gi)
    local tgt_entries = { moved_meta }
    if not CONFIG_MANAGER:saveToolbarGroupsOnly(source_toolbar.section, src_entries) then
        reaper.ShowConsoleMsg(
            "Advanced Toolbars: failed to save TOOLBAR_GROUPS after group move (" .. tostring(source_toolbar.section) .. ")\n"
        )
    end
    if not CONFIG_MANAGER:saveToolbarGroupsOnly(target_toolbar.section, tgt_entries) then
        reaper.ShowConsoleMsg(
            "Advanced Toolbars: failed to save TOOLBAR_GROUPS after group move (" .. tostring(target_toolbar.section) .. ")\n"
        )
    end

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

-- Utility functions
function IniManager:createBackup()
    local backup_dir = UTILS.joinPath(SCRIPT_PATH, "User/ini_backups")
    if not UTILS.ensureDirectoryExists(backup_dir) then
        return false, "Failed to create backup directory"
    end

    local source_path = self:getMenuIniPath()
    local timestamp = os.date("%Y%m%d_%H%M%S")
    local backup_path = UTILS.joinPath(backup_dir, "reaper-menu_" .. timestamp .. ".ini")

    local source_file = io.open(source_path, "r")
    if not source_file then
        return false, "Failed to read runtime toolbar store"
    end

    local content = source_file:read("*all")
    source_file:close()

    local backup_file = io.open(backup_path, "w")
    if not backup_file then
        return false, "Failed to create backup file"
    end

    backup_file:write(content)
    backup_file:close()

    return true, backup_path
end

function IniManager:reloadToolbars()
    reaper.defer(function()
        for _, controller_data in ipairs(_G.TOOLBAR_CONTROLLERS or {}) do
            if controller_data.controller and controller_data.controller.loader then
                controller_data.controller.loader:loadToolbars()
            end
        end
    end)
end

function IniManager:reloadToolbarsNow()
    for _, controller_data in ipairs(_G.TOOLBAR_CONTROLLERS or {}) do
        if controller_data.controller and controller_data.controller.loader then
            controller_data.controller.loader:loadToolbars()
        end
    end
end

function IniManager:validateIcon(icon_path)
    if not icon_path then return false end

    local file = io.open(icon_path, "r")
    if not file then return false end

    file:close()
    return true
end


return IniManager.new()