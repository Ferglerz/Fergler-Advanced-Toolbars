-- Systems/Ini_Manager_query.lua — resolve toolbar / button positions; loaded by Ini_Manager.lua

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

-- Unified button finder
function IniManager:findButton(button, items)
    if button.parent_toolbar and button.parent_toolbar.buttons then
        for i, toolbar_button in ipairs(button.parent_toolbar.buttons) do
            if toolbar_button.instance_id == button.instance_id then
                return i
            end
        end
    end

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

    for i, item in ipairs(items) do
        if item.id == button.id then
            return i
        end
    end

    return nil
end
