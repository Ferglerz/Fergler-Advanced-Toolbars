-- Managers/Config_IniParser.lua
return function(ConfigManager)
function ConfigManager:ensureToolbarStructureStoreInitialized(ini_content)
    local sections = self:getToolbarConfigSections()
    local missing_sections = {}
    for _, s in ipairs(sections) do
        local cfg = self:loadToolbarConfig(s.section)
        local has_structure = type(cfg) == "table" and type(cfg.STRUCTURE) == "table" and type(cfg.STRUCTURE.items) == "table"
        if not has_structure then
            table.insert(missing_sections, s.section)
        end
    end

    if #sections > 0 and #missing_sections == 0 then
        return true
    end

    local parsed = UTILS.parseIniToolbars(ini_content)
    if #parsed == 0 then
        return #sections > 0
    end

    for i, tb in ipairs(parsed) do
        local should_write = (#sections == 0)
        if not should_write then
            for _, missing in ipairs(missing_sections) do
                if missing == tb.section then
                    should_write = true
                    break
                end
            end
        end
        if not should_write then
            goto continue
        end

        local cfg = self:loadToolbarConfig(tb.section)
        if type(cfg) ~= "table" then
            cfg = {}
        end
        cfg.SECTION = tb.section
        cfg.ORDER = i
        cfg.STRUCTURE = {
            items = tb.items or {},
            default = tb.default,
            icons = tb.icons or {},
            title = tb.title
        }
        cfg.BUTTON_CUSTOM_PROPERTIES = cfg.BUTTON_CUSTOM_PROPERTIES or {}
        cfg.TOOLBAR_GROUPS = cfg.TOOLBAR_GROUPS or {}
        cfg.CUSTOM_NAME = cfg.CUSTOM_NAME or tb.title
        if not self:writeToolbarConfig(tb.section, cfg) then
            return false
        end
        ::continue::
    end

    return true
end

-- Canonical toolbar state lives in User/toolbar_configs/*.lua (STRUCTURE.items + BUTTON_CUSTOM_PROPERTIES).
-- Synthetic item_* text built here is only a parse transport (same shape as REAPER menu lines), not a second source of truth.
function ConfigManager:buildRuntimeLinesFromToolbarConfigs(ini_content)
    if not self:ensureToolbarStructureStoreInitialized(ini_content) then
        return nil
    end

    local lines = {}
    local sections = self:getToolbarConfigSections()
    for _, s in ipairs(sections) do
        local cfg = self:loadToolbarConfig(s.section)
        if type(cfg) == "table" and type(cfg.STRUCTURE) == "table" then
            local structure = cfg.STRUCTURE
            table.insert(lines, "[" .. tostring(s.section) .. "]")

            for i, item in ipairs(structure.items or {}) do
                local id = tostring(item.id or "")
                local text = tostring(item.text or "")
                table.insert(lines, UTILS.formatToolbarItemLine(i - 1, id, text))
            end

            if structure.default ~= nil and structure.default ~= "" then
                table.insert(lines, "default=" .. tostring(structure.default))
            end

            local icon_keys = {}
            for k in pairs(structure.icons or {}) do
                if type(k) == "number" then
                    table.insert(icon_keys, k)
                end
            end
            table.sort(icon_keys)
            for _, k in ipairs(icon_keys) do
                table.insert(lines, string.format("icon_%d=%s", k, tostring(structure.icons[k])))
            end

            local title = structure.title or cfg.CUSTOM_NAME
            if title and title ~= "" then
                table.insert(lines, "title=" .. tostring(title))
            end
        end
    end

    return lines
end

function ConfigManager:buildRuntimeIniContentFromToolbarConfigs(ini_content)
    local lines = self:buildRuntimeLinesFromToolbarConfigs(ini_content)
    if not lines then
        return nil
    end
    return table.concat(lines, "\n")
end

function ConfigManager:listTemplateEntriesFromIni(ini_content)
    local out = {}
    for _, tb in ipairs(UTILS.parseIniToolbars(ini_content)) do
        table.insert(
            out,
            {
                section = tb.section,
                name = (tb.title and tb.title ~= "") and tb.title or tb.section
            }
        )
    end
    return out
end

function ConfigManager:createToolbarFromIniTemplate(template_section, ini_content)
    local template = nil
    for _, tb in ipairs(UTILS.parseIniToolbars(ini_content)) do
        if tb.section == template_section then
            template = tb
            break
        end
    end
    if not template then
        return nil
    end

    local existing = {}
    for _, s in ipairs(self:getToolbarConfigSections()) do
        existing[s.section] = true
    end

    local base = ((template.title and template.title ~= "") and template.title or template.section) .. " Copy"
    local section = base
    local n = 2
    while existing[section] do
        section = string.format("%s (%d)", base, n)
        n = n + 1
    end

    local cfg = {
        SECTION = section,
        ORDER = self:nextToolbarConfigOrder(),
        CUSTOM_NAME = section,
        BUTTON_CUSTOM_PROPERTIES = {},
        TOOLBAR_GROUPS = {},
        STRUCTURE = {
            items = template.items or {},
            default = template.default,
            icons = template.icons or {},
            title = section
        }
    }
    if not self:writeToolbarConfig(section, cfg) then
        return nil
    end
    return section
end


end
