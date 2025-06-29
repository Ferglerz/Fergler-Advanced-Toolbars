-- Parsing/Parse_Toolbars.lua

local ToolbarParser = {}
ToolbarParser.__index = ToolbarParser

function ToolbarParser.new()
    local self = setmetatable({}, ToolbarParser)
    return self
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
    
    -- Count and index separators
    local separator_count = 0
    for _, button in ipairs(buttons) do
        if button:isSeparator() then
            separator_count = separator_count + 1
            button.separator_index = separator_count
        end
    end

    -- New grouping logic: separators become the last button in a group, then start a new group
    for _, button in ipairs(buttons) do
        button.parent_toolbar = toolbar

        table.insert(toolbar.buttons, button)
        C.ButtonManager:registerButton(button)

        -- Add button to current group
        current_group:addButton(button)

        -- If this button is a separator, end the current group and start a new one
        if button:isSeparator() then
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
            
            -- Start a new group (unless this is the last button)
            local button_index = 0
            for i, b in ipairs(buttons) do
                if b == button then
                    button_index = i
                    break
                end
            end
            
            if button_index < #buttons then
                current_group = C.ParseGrouping.new()
            end
        end
    end

    -- Add the final group if it has buttons and isn't empty
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

        -- Apply instance_id if it exists, otherwise keep the generated one
        if props.instance_id then
            button.instance_id = props.instance_id
        end

        local properties = {
            {"name", "display_text"},
            {"hide_label", "hide_label"},
            {"justification", "alignment"},
            {"icon_path", "icon_path"},
            {"icon_char", "icon_char"},
            {"icon_font", "icon_font"},
            {"custom_color", "custom_color"},
            {"button_type", "button_type"}  -- Support saved button type
        }

        -- Only apply these properties to normal buttons
        if not button:isSeparator() then
            table.insert(properties, {"right_click", "right_click"})
            table.insert(properties, {"right_click_action", "right_click_action"})
        end

        for _, prop in ipairs(properties) do
            if props[prop[1]] ~= nil then
                button[prop[2]] = props[prop[1]]
            end
        end

        -- Only handle dropdown and widget for normal buttons
        if not button:isSeparator() then
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
                local item_number, id, text = line:match("^item_(%d+)=(%S+)%s*(.*)$")
                if id then
                    local button = C.ButtonDefinition.createButton(id, text or "", item_number)

                    local toolbar_config = CONFIG_MANAGER:loadToolbarConfig(current_toolbar.section)
                    if toolbar_config and toolbar_config.BUTTON_CUSTOM_PROPERTIES then
                        local button_config = nil
                        
                        -- Try property_key first (new format)
                        button_config = toolbar_config.BUTTON_CUSTOM_PROPERTIES[button.property_key]
                        
                        -- If not found, try to find a config for this button from the old format
                        if not button_config then
                            -- Look for configs that match this button's action but have different suffixes
                            local base_pattern = "^" .. button.id:gsub("%-", "%%-") .. "_" .. button.original_text:gsub("%-", "%%-"):gsub("%.", "%%."):gsub("%s", "%%s") .. "_"
                            for config_key, config_props in pairs(toolbar_config.BUTTON_CUSTOM_PROPERTIES) do
                                if config_key:match(base_pattern) then
                                    -- Found a config for this action, migrate it to the new key
                                    button_config = config_props
                                    -- Remove old config and it will be saved with new key
                                    toolbar_config.BUTTON_CUSTOM_PROPERTIES[config_key] = nil
                                    break
                                end
                            end
                        end
                        
                        applyButtonProperties(button, button_config)
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