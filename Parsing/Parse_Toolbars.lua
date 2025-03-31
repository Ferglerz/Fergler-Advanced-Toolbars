-- Parsing/Parse_Toolbars.lua

local ToolbarParser = {}
ToolbarParser.__index = ToolbarParser

function ToolbarParser.new()
    local self = setmetatable({}, ToolbarParser)
    return self
end

function ToolbarParser:loadMenuIni()
    local menu_path = reaper.GetResourcePath() .. "/reaper-menu.ini"
    local file = io.open(menu_path, "r")
    if not file then
        reaper.ShowMessageBox("Could not open reaper-menu.ini", "Error", 0)
        return nil
    end
    local content = file:read("*all")
    file:close()
    return content, menu_path
end

function ToolbarParser:validateIcon(icon_path)
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

function ToolbarParser:createToolbar(section_name, state)
    local toolbar = {
        name = section_name:gsub("toolbar:", ""):gsub("_", " "),
        section = section_name,
        custom_name = nil,
        buttons = {},
        groups = {},
        state = state,
        updateName = function(self, new_name)
            self.custom_name = new_name
            self.name = new_name or self.section:gsub("toolbar:", ""):gsub("_", " ")
        end,
        addButton = function(self, button)
            table.insert(self.buttons, button)
            if #self.groups == 0 then
                table.insert(self.groups, C.ParseGrouping.new())
            end
            self.groups[#self.groups]:addButton(button)
            C.ButtonManager:registerButton(button)
        end
    }

    local toolbar_config = CONFIG_MANAGER:loadToolbarConfig(section_name)
    if toolbar_config and toolbar_config.CUSTOM_NAME then
        toolbar:updateName(toolbar_config.CUSTOM_NAME)
    end
    return toolbar
end

function ToolbarParser:handleGroups(toolbar, buttons)
    local toolbar_config = CONFIG_MANAGER:loadToolbarConfig(toolbar.section)
    local group_configs = toolbar_config and toolbar_config.TOOLBAR_GROUPS or {}
    local current_group = C.ParseGrouping.new()
    local group_index = 1

    -- Rest of the function remains the same, but use C.ParseGrouping.new() instead
    for _, button in ipairs(buttons) do
        button.parent_toolbar = toolbar

        table.insert(toolbar.buttons, button)
        C.ButtonManager:registerButton(button)

        if button.is_separator then
            if #current_group.buttons > 0 then
                -- Set the group label from saved config
                if group_configs[group_index] and group_configs[group_index].group_label then
                    current_group.group_label.text = group_configs[group_index].group_label.text or ""
                end
                
                -- Set the split point if defined in config
                if group_configs[group_index] and group_configs[group_index].is_split_point then
                    current_group.is_split_point = group_configs[group_index].is_split_point
                end
                
                table.insert(toolbar.groups, current_group)
                group_index = group_index + 1
                current_group = C.ParseGrouping.new()
            end
        else
            current_group:addButton(button)
        end
    end

    if #current_group.buttons > 0 then
        -- Set the group label from saved config for the last group
        if group_configs[group_index] and group_configs[group_index].group_label then
            current_group.group_label.text = group_configs[group_index].group_label.text or ""
        end
        
        -- Set the split point if defined in config for the last group
        if group_configs[group_index] and group_configs[group_index].is_split_point then
            current_group.is_split_point = group_configs[group_index].is_split_point
        end
        
        table.insert(toolbar.groups, current_group)
    end
end

function ToolbarParser:parseToolbars(iniContent)
    if not iniContent then
        return {}
    end

    local state = C.ButtonManager.new()
    local toolbars = {}
    local current_toolbar, current_buttons = nil, {}

    local function applyButtonProperties(button, props)
        if not props then
            return
        end

        local properties = {
            {"name", "display_text"},
            {"hide_label", "hide_label"},
            {"justification", "alignment"},
            {"icon_path", "icon_path"},
            {"icon_char", "icon_char"},
            {"icon_font", "icon_font"},
            {"custom_color", "custom_color"},
            {"right_click", "right_click"}
        }

        for _, prop in ipairs(properties) do
            if props[prop[1]] ~= nil then
                button[prop[2]] = props[prop[1]]
            end
        end

        if props.dropdown_menu then
            local sanitized_dropdown = {}
            local items = type(props.dropdown_menu[1]) == "nil" and props.dropdown_menu or {table.unpack(props.dropdown_menu)}
            for k, item in pairs(items) do
                if item.is_separator then
                    table.insert(sanitized_dropdown, {is_separator = true})
                else
                    table.insert(
                        sanitized_dropdown,
                        {
                            name = item.name or "Unnamed",
                            action_id = tostring(item.action_id or "")
                        }
                    )
                end
            end
            button.dropdown_menu = sanitized_dropdown
        end

        if props.widget and props.widget.name and WIDGETS then
            if C.WidgetsManager:assignWidgetToButton(button, props.widget.name) and props.widget.width and button.widget then
                button.widget.width = props.widget.width
            end
        end
    end

    for line in iniContent:gmatch("[^\r\n]+") do
        local toolbar_section = line:match("%[(.+)%]")
        if toolbar_section then
            if current_toolbar and #current_buttons > 0 then
                self:handleGroups(current_toolbar, current_buttons)
            end
            current_toolbar = self:createToolbar(toolbar_section, state)
            table.insert(toolbars, current_toolbar)
            current_buttons = {}
        elseif current_toolbar then
            local title = line:match("^title=(.+)$")
            if title then
                current_toolbar:updateName(title)
            elseif line:match("^item_%d+") then
                local id, text = line:match("^item_%d+=(%S+)%s*(.*)$")
                if id then
                    local button =
                        id == "-1" and C.ButtonDefinition.createButton("-1", "SEPARATOR") or C.ButtonDefinition.createButton(id, text)

                    local toolbar_config = CONFIG_MANAGER:loadToolbarConfig(current_toolbar.section)
                    if toolbar_config and toolbar_config.BUTTON_CUSTOM_PROPERTIES then
                        applyButtonProperties(button, toolbar_config.BUTTON_CUSTOM_PROPERTIES[button.property_key])
                    end
                    table.insert(current_buttons, button)
                end
            end
        end
    end

    if current_toolbar and #current_buttons > 0 then
        self:handleGroups(current_toolbar, current_buttons)
    end

    return toolbars, state
end

return ToolbarParser.new()
