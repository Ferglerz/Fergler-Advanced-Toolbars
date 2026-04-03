-- Systems/Ini_Manager_core.lua — file I/O and section line primitives; loaded by Ini_Manager.lua

function IniManager.new()
    local self = setmetatable({}, IniManager)
    self.last_file_size = nil
    self.last_file_hash = nil
    self.last_script_write_time = nil
    self.cached_content = nil
    return self
end

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
            local _, id, text = UTILS.parseToolbarItemLine(line)
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
        item.original_line = UTILS.formatToolbarItemLine(i - 1, item.id, item.text)
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
