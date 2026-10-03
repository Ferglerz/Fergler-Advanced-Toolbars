-- Local toolbar editing and shared runtime reloads.
function ToolbarEditor.new()
    return setmetatable({}, ToolbarEditor)
end

function ToolbarEditor:findToolbarBySection(section)
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

function ToolbarEditor:reloadToolbars()
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

function ToolbarEditor:reloadToolbarsNow()
    if C.SharedToolbars then
        C.SharedToolbars:invalidate()
    end
    for _, controller_data in ipairs(_G.TOOLBAR_CONTROLLERS or {}) do
        if controller_data.controller and controller_data.controller.loader then
            controller_data.controller.loader:loadToolbars()
        end
    end
end
