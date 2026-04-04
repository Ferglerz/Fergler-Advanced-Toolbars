-- Systems/Ini_Manager_core.lua — reaper-menu.ini read + script write sync; loaded by Ini_Manager.lua

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
