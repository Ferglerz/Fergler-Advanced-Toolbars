-- Systems/Ini_Manager.lua

local SCRIPT_WRITE_GRACE_SEC = 1.5

-- Stable fingerprint for reaper-menu.ini (size alone misses same-length edits)
local function hash_content(content)
    local h = 2166136261
    for i = 1, #content do
        h = (h ~ string.byte(content, i)) * 16777619
    end
    return h & 0xFFFFFFFF
end

local IniManager = {}
IniManager.__index = IniManager

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

function IniManager:loadContent()
    local menu_path = self:getMenuIniPath()
    local file = io.open(menu_path, "r")
    if not file then
        reaper.ShowMessageBox("Could not open reaper-menu.ini", "Error", 0)
        return nil
    end

    local content = file:read("*all")
    file:close()

    self.cached_content = content
    return content
end

function IniManager:checkForFileChanges()
    -- Throttle checks to once every 2 seconds
    local current_time = _G.FRAME_TIME or reaper.time_precise()
    if self.last_check_time and (current_time - self.last_check_time) < 2.0 then
        return false
    end
    self.last_check_time = current_time

    -- Ignore external changes briefly after our own write (avoids double reload / host races)
    if self.last_script_write_time and
       (current_time - self.last_script_write_time) < SCRIPT_WRITE_GRACE_SEC then
        return false
    end

    -- While editing, REAPER may rewrite reaper-menu.ini; do not reload from disk until edit mode ends
    if _G.anyToolbarInEditMode and _G.anyToolbarInEditMode() then
        return false
    end

    local menu_path = self:getMenuIniPath()
    local file = io.open(menu_path, "r")
    if not file then return false end

    local content = file:read("*all")
    file:close()

    local current_size = #content
    local current_hash = hash_content(content)

    if not self.last_file_hash then
        self.last_file_size = current_size
        self.last_file_hash = current_hash
        return false
    end

    if current_size ~= self.last_file_size or current_hash ~= self.last_file_hash then
        self.last_file_size = current_size
        self.last_file_hash = current_hash
        self.cached_content = nil
        return true
    end

    return false
end

--- Call after writing reaper-menu.ini from this script so the file watcher matches disk and grace applies.
function IniManager:syncFileStateAfterScriptWrite()
    local menu_path = self:getMenuIniPath()
    local file = io.open(menu_path, "r")
    if not file then return end
    local content = file:read("*all")
    file:close()
    self.last_file_size = #content
    self.last_file_hash = hash_content(content)
    self.last_script_write_time = reaper.time_precise()
end

function IniManager:getContent()
    if not self.cached_content then
        return self:loadContent()
    end
    return self.cached_content
end

function IniManager:getLines()
    local content = self:getContent()
    if not content then return nil end

    local lines = {}
    for line in content:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end
    return lines
end

function IniManager:writeFile(lines)
    local menu_path = self:getMenuIniPath()
    local file = io.open(menu_path, "w")
    if not file then return false end

    for _, line in ipairs(lines) do
        file:write(line .. "\n")
    end
    file:close()

    self.cached_content = nil
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
    return self:writeFile(lines)
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
    return self:writeFile(lines)
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

-- Utility functions
function IniManager:createBackup()
    local backup_dir = UTILS.joinPath(SCRIPT_PATH, "User/ini_backups")
    if not UTILS.ensureDirectoryExists(backup_dir) then
        return false, "Failed to create backup directory"
    end

    local menu_path = self:getMenuIniPath()
    local timestamp = os.date("%Y%m%d_%H%M%S")
    local backup_path = UTILS.joinPath(backup_dir, "reaper-menu_" .. timestamp .. ".ini")

    local source_file = io.open(menu_path, "r")
    if not source_file then
        return false, "Failed to read original menu file"
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

function IniManager:validateIcon(icon_path)
    if not icon_path then return false end

    local file = io.open(icon_path, "r")
    if not file then return false end

    file:close()
    return true
end


return IniManager.new()