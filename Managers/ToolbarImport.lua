-- Read-only boundary for importing a snapshot of a native REAPER toolbar.
local STRINGS = require("Utils.Core.string_utils")
local ToolbarImport = {}

local function isToolbarSection(section)
    local name = section:lower()
    return name == "main toolbar"
        or name == "midi piano roll toolbar"
        or name == "midi event list toolbar"
        or name == "media explorer toolbar"
        or name:match("^floating toolbar %d+$") ~= nil
        or name:match("^floating midi toolbar %d+$") ~= nil
end

function ToolbarImport.parse(content)
    local templates = {}
    for _, toolbar in ipairs(STRINGS.parseIniToolbars(content)) do
        if isToolbarSection(toolbar.section) then
            templates[#templates + 1] = toolbar
        end
    end
    return templates
end

function ToolbarImport.read()
    local file = io.open(reaper.GetResourcePath() .. "/reaper-menu.ini", "r")
    if not file then
        return {}, "No saved REAPER toolbars found. Save a customized toolbar in REAPER, then refresh."
    end
    local content, err = file:read("*a")
    file:close()
    if not content then
        return {}, "Could not read REAPER toolbars: " .. tostring(err)
    end
    return ToolbarImport.parse(content)
end

function ToolbarImport.create(template)
    if not template or not isToolbarSection(template.section or "") then
        return nil
    end
    local properties = {}
    for i, item in ipairs(template.items or {}) do
        local icon = template.icons and template.icons[i - 1]
        if icon and icon ~= "" and tostring(item.id) ~= "-1" then
            local key = C.ButtonDefinition.createPropertyKey(item.id, item.text or "", i - 1)
            properties[key] = { reaper_icon_path = icon }
        end
    end
    local name = template.title and template.title ~= "" and template.title or template.section
    return CONFIG_MANAGER:createToolbar(name, template.items, properties)
end

return ToolbarImport
