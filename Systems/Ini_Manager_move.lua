-- Systems/Ini_Manager_move.lua — drag/move and group moves; loaded by Ini_Manager.lua

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

        local should_inherit_group_colors = false
        if not payload_data.is_separator then
            local source_gid = flatItemGroupIndexForToolbarItems(items, source_index)
            table.remove(items, source_index)
            if source_index < target_index then
                target_index = target_index - 1
            end
            local insert_index = drop_position == "after" and target_index + 1 or target_index
            table.insert(items, insert_index, source_item)
            local dest_gid = flatItemGroupIndexForToolbarItems(items, insert_index)
            should_inherit_group_colors = (source_gid ~= dest_gid)
        else
            table.remove(items, source_index)
            if source_index < target_index then
                target_index = target_index - 1
            end
            local insert_index = drop_position == "after" and target_index + 1 or target_index
            table.insert(items, insert_index, source_item)
        end

        self:renumberItems(items)
        self:replaceSection(lines, section_start, section_end, items)
        local ok = self:writeFile(lines)
        if ok and should_inherit_group_colors then
            self:inheritGroupColorsForMovedButton(target_button, payload_data, target_section)
        end
        return ok
    end

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

    local should_inherit_group_colors = not payload_data.is_separator
    local ok = self:writeFile(lines)
    if ok and should_inherit_group_colors then
        self:inheritGroupColorsForMovedButton(target_button, payload_data, target_section)
    end
    return ok
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
