-- Systems/Ini_Manager.lua

local IniManager = {}
IniManager.__index = IniManager

function IniManager.new()
    local self = setmetatable({}, IniManager)
    
    -- File monitoring state
    self.last_file_size = nil
    self.cached_content = nil
    self.cached_path = nil
    
    return self
end

function IniManager:getMenuIniPath()
    return reaper.GetResourcePath() .. "/reaper-menu.ini"
end

function IniManager:loadMenuIni()
    local menu_path = self:getMenuIniPath()
    local file = io.open(menu_path, "r")
    if not file then
        reaper.ShowMessageBox("Could not open reaper-menu.ini", "Error", 0)
        return nil, nil
    end
    local content = file:read("*all")
    file:close()
    
    -- Cache the content and path
    self.cached_content = content
    self.cached_path = menu_path
    
    return content, menu_path
end

function IniManager:checkForFileChanges()
    local menu_path = self:getMenuIniPath()

    -- Get current file size
    local file = io.open(menu_path, "r")
    if not file then
        return false
    end

    -- Get current file size
    local current_size = file:seek("end")
    file:close()

    -- Initialize last known size if not set
    if not self.last_file_size then
        self.last_file_size = current_size
        return false
    end

    -- Check if file size has changed
    if current_size ~= self.last_file_size then
        -- Update stored value and clear cache
        self.last_file_size = current_size
        self.cached_content = nil
        self.cached_path = nil
        return true -- File has changed
    end

    return false -- No changes detected
end

function IniManager:hasFileChanged()
    return self:checkForFileChanges()
end

function IniManager:getCachedContent()
    if not self.cached_content then
        self:loadMenuIni()
    end
    return self.cached_content, self.cached_path
end

function IniManager:createIniBackup()
    local backup_dir = UTILS.joinPath(SCRIPT_PATH, "User/ini_backups")
    if not UTILS.ensureDirectoryExists(backup_dir) then
        return false, "Failed to create backup directory"
    end
    
    local menu_path = self:getMenuIniPath()
    local timestamp = os.date("%Y%m%d_%H%M%S")
    local backup_path = UTILS.joinPath(backup_dir, "reaper-menu_" .. timestamp .. ".ini")
    
    -- Read original file
    local source_file = io.open(menu_path, "r")
    if not source_file then
        return false, "Failed to read original menu file"
    end
    
    local content = source_file:read("*all")
    source_file:close()
    
    -- Write backup
    local backup_file = io.open(backup_path, "w")
    if not backup_file then
        return false, "Failed to create backup file"
    end
    
    backup_file:write(content)
    backup_file:close()
    
    return true, backup_path
end

function IniManager:writeIniFile(lines)
    local menu_path = self:getMenuIniPath()
    local output_file = io.open(menu_path, "w")
    if not output_file then 
        return false 
    end
    
    for _, line in ipairs(lines) do
        output_file:write(line .. "\n")
    end
    output_file:close()
    
    -- Clear cache after writing
    self.cached_content = nil
    self.cached_path = nil
    
    return true
end

function IniManager:readIniLines()
    local content, _ = self:getCachedContent()
    if not content then
        return nil
    end
    
    local lines = {}
    for line in content:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end
    
    return lines
end

function IniManager:insertButtonInIni(target_button, new_button, position)
    local lines = self:readIniLines()
    if not lines then
        return false
    end
    
    local toolbar_section = target_button.parent_toolbar.section
    local section_start, section_end = self:findToolbarSection(lines, toolbar_section)
    
    if not section_start or not section_end then 
        return false 
    end
    
    local items = self:extractToolbarItems(lines, section_start, section_end)
    
    -- Find target position
    local target_index
    for i, item in ipairs(items) do
        if item.id == target_button.id then
            target_index = i
            break
        end
    end
    
    if not target_index then 
        return false 
    end
    
    -- Create new item
    local new_item = {
        original_line = string.format("item_999=%s %s", new_button.id, new_button.original_text),
        id = new_button.id,
        text = new_button.original_text
    }
    
    -- Insert at correct position
    local insert_index = position == "after" and target_index + 1 or target_index
    table.insert(items, insert_index, new_item)
    
    -- Renumber items
    for i, item in ipairs(items) do
        local id, text = item.original_line:match("^item_%d+=(%S+)%s*(.*)$")
        item.original_line = string.format("item_%d=%s %s", i, id, text)
    end
    
    -- Replace section
    self:replaceToolbarSection(lines, section_start, section_end, items)
    
    return self:writeIniFile(lines)
end

function IniManager:deleteButtonFromIni(button_to_delete)
    local lines = self:readIniLines()
    if not lines then
        return false
    end
    
    local toolbar_section = button_to_delete.parent_toolbar.section
    local section_start, section_end = self:findToolbarSection(lines, toolbar_section)
    
    if not section_start or not section_end then 
        return false 
    end
    
    local items = self:extractToolbarItems(lines, section_start, section_end)
    
    -- Remove the target item
    for i = #items, 1, -1 do
        if items[i].id == button_to_delete.id then
            table.remove(items, i)
            break
        end
    end
    
    -- Renumber items
    for i, item in ipairs(items) do
        local id, text = item.original_line:match("^item_%d+=(%S+)%s*(.*)$")
        item.original_line = string.format("item_%d=%s %s", i, id, text)
    end
    
    -- Replace section
    self:replaceToolbarSection(lines, section_start, section_end, items)
    
    return self:writeIniFile(lines)
end

function IniManager:moveButtonInIni(target_button, payload_data, drop_position)
    local lines = self:readIniLines()
    if not lines then
        return false
    end
    
    local toolbar_section = target_button.parent_toolbar.section
    local section_start, section_end = self:findToolbarSection(lines, toolbar_section)
    
    if not section_start or not section_end then
        return false
    end
    
    local items = self:extractToolbarItems(lines, section_start, section_end)
    
    -- FIXED: Find source and target items using separator indexing
    local source_item, source_index
    local target_index
    
    if payload_data.is_separator and payload_data.separator_index then
        -- For separators, find by counting separator occurrences
        local separator_count = 0
        for i, item in ipairs(items) do
            if item.id == "-1" then
                separator_count = separator_count + 1
                if separator_count == payload_data.separator_index then
                    source_item = item
                    source_index = i
                    break
                end
            end
        end
    else
        -- For regular buttons, find by ID (should be unique)
        for i, item in ipairs(items) do
            if item.id == payload_data.button_id then
                source_item = item
                source_index = i
                break
            end
        end
    end
    
    -- Find target button
    if target_button:isSeparator() and target_button.separator_index then
        -- Target is a separator, find by separator index
        local separator_count = 0
        for i, item in ipairs(items) do
            if item.id == "-1" then
                separator_count = separator_count + 1
                if separator_count == target_button.separator_index then
                    target_index = i
                    break
                end
            end
        end
    else
        -- Target is a regular button, find by ID
        for i, item in ipairs(items) do
            if item.id == target_button.id then
                target_index = i
                break
            end
        end
    end
    
    if not source_item or not target_index or source_index == target_index then
        return false
    end
    
    -- Remove source item first
    table.remove(items, source_index)
    
    -- Adjust target index if source was before target
    if source_index < target_index then
        target_index = target_index - 1
    end
    
    -- Insert at new position
    local insert_index = drop_position == "after" and target_index + 1 or target_index
    table.insert(items, insert_index, source_item)
    
    -- Renumber all items
    for i, item in ipairs(items) do
        local id, text = item.original_line:match("^item_%d+=(%S+)%s*(.*)$")
        item.original_line = string.format("item_%d=%s %s", i, id, text)
    end
    
    -- Replace section
    self:replaceToolbarSection(lines, section_start, section_end, items)
    
    return self:writeIniFile(lines)
end

function IniManager:findToolbarSection(lines, toolbar_section)
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

function IniManager:extractToolbarItems(lines, section_start, section_end)
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

function IniManager:replaceToolbarSection(lines, section_start, section_end, items)
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

function IniManager:reloadToolbars()
    -- Reload all toolbar controllers
    for _, controller_data in ipairs(_G.TOOLBAR_CONTROLLERS) do
        if controller_data.controller and controller_data.controller.loader then
            reaper.defer(function()
                controller_data.controller.loader:loadToolbars()
            end)
            break 
        end
    end
end

function IniManager:validateIcon(icon_path)
    if not icon_path then
        return false
    end

    local success, file =
        pcall(
        function()
            return io.open(icon_path, "r")
        end
    )
    if not success or not file then
        return false
    end

    file:close()
    return true
end

return IniManager.new()