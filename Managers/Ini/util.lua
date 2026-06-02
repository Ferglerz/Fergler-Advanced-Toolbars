-- Managers/Ini/util.lua — reload and misc; loaded by Managers/Ini.lua

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

function IniManager:validateIcon(icon_path)
    if not icon_path then return false end

    local file = io.open(icon_path, "r")
    if not file then return false end

    file:close()
    return true
end
