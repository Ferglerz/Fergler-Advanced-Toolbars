-- Managers/Ini/core.lua — reaper-menu.ini read + script write sync; loaded by Managers/Ini.lua

function IniManager.new()
    local self = setmetatable({}, IniManager)
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

function IniManager:getContent()
    if not self.cached_content then
        return self:loadContent()
    end
    return self.cached_content
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

function IniManager:reloadToolbars()
    reaper.defer(function()
        if C.SharedToolbars then
            C.SharedToolbars:invalidate()
        end
        for _, controller_data in ipairs(_G.TOOLBAR_CONTROLLERS or {}) do
            if controller_data.controller and controller_data.controller.loader then
                controller_data.controller.loader:loadToolbars()
            end
        end
    end)
end

function IniManager:reloadToolbarsNow()
    if C.SharedToolbars then
        C.SharedToolbars:invalidate()
    end
    for _, controller_data in ipairs(_G.TOOLBAR_CONTROLLERS or {}) do
        if controller_data.controller and controller_data.controller.loader then
            controller_data.controller.loader:loadToolbars()
        end
    end
end
