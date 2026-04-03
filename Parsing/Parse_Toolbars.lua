-- Parsing/Parse_Toolbars.lua

local ToolbarParser = {}
ToolbarParser.__index = ToolbarParser
local warned_group_mismatch = {}

function ToolbarParser.new()
    local self = setmetatable({}, ToolbarParser)
    return self
end

function ToolbarParser:createToolbar(section_name, state, toolbar_config)
    local toolbar = {
        name = section_name:gsub("toolbar:", ""):gsub("_", " "),
        section = section_name,
        custom_name = nil,
        ini_title = nil,
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

    local tc = toolbar_config or CONFIG_MANAGER:loadToolbarConfig(section_name)
    if tc and type(tc.CUSTOM_NAME) == "string" and tc.CUSTOM_NAME ~= "" then
        toolbar:updateName(tc.CUSTOM_NAME)
    end
    -- One load per toolbar; reused for every item line and for handleGroups (no per-item disk read).
    toolbar.cached_toolbar_config = tc
    return toolbar
end

function ToolbarParser:applyButtonProperties(button, props)
    if not props then
        return
    end

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
        {"button_type", "button_type"}
    }

    if not button:isSeparator() then
        table.insert(properties, {"right_click", "right_click"})
        table.insert(properties, {"right_click_action", "right_click_action"})
    end

    for _, prop in ipairs(properties) do
        if props[prop[1]] ~= nil then
            button[prop[2]] = props[prop[1]]
        end
    end

    if not button:isSeparator() then
        if props.dropdown_menu then
            local sanitized_dropdown = {}
            local items = type(props.dropdown_menu[1]) == "nil" and props.dropdown_menu or {table.unpack(props.dropdown_menu)}
            for _, item in ipairs(items) do
                if item.is_separator then
                    table.insert(sanitized_dropdown, {is_separator = true})
                elseif item.is_heading then
                    table.insert(sanitized_dropdown, {is_heading = true, name = item.name or ""})
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
            if button.widget and props.widget.options and button.widget.applyPersistedOptions then
                pcall(button.widget.applyPersistedOptions, button.widget, props.widget.options)
            end
        end
    end
end

-- Synthetic toolbar (no reaper-menu.ini section): built-in Toolbars List widget prepended when ENABLE_TOOLBAR_SWITCH_WIDGET is on.
function ToolbarParser:buildToolbarSwitchWidgetToolbar(state, toolbar_config)
    if not toolbar_config or not toolbar_config.SYNTHETIC_ITEMS or #toolbar_config.SYNTHETIC_ITEMS == 0 then
        return nil
    end

    local toolbar = self:createToolbar("toolbar:AdvancedToolbars_ToolbarSwitch", state, toolbar_config)
    toolbar.is_toolbar_switch_widget = true

    local buttons = {}
    for _, item in ipairs(toolbar_config.SYNTHETIC_ITEMS) do
        local pos = tostring(item.pos or item.position or #buttons)
        local button = C.ButtonDefinition.createButton(item.id or C.ButtonDefinition.NOOP_ACTION_ID, item.text or "", pos)
        local props = toolbar_config.BUTTON_CUSTOM_PROPERTIES and toolbar_config.BUTTON_CUSTOM_PROPERTIES[button.property_key]
        self:applyButtonProperties(button, props)
        if not button.widget and item.widget and item.widget.name and WIDGETS then
            if C.WidgetsManager:assignWidgetToButton(button, item.widget.name) and item.widget.width and button.widget then
                button.widget.width = item.widget.width
            end
        end
        table.insert(buttons, button)
    end

    self:handleGroups(toolbar, buttons, toolbar_config)
    return toolbar
end

function ToolbarParser:handleGroups(toolbar, buttons, toolbar_config_override)
    local toolbar_config = toolbar_config_override or toolbar.cached_toolbar_config or CONFIG_MANAGER:loadToolbarConfig(toolbar.section)
    local group_configs = toolbar_config and toolbar_config.TOOLBAR_GROUPS or {}
    local current_group = C.ParseGrouping.new()
    local group_index = 1
    local last_was_separator = false
    
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
            last_was_separator = true
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
        else
            last_was_separator = false
        end
    end

    -- Add final group only when the loop did not just close it on a trailing separator.
    if #current_group.buttons > 0 and not last_was_separator then
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

    -- Diagnostic: this catches stale/misaligned TOOLBAR_GROUPS metadata after disk races or partial writes.
    local configured_count = type(group_configs) == "table" and #group_configs or 0
    if configured_count > 0 and configured_count ~= #toolbar.groups and not warned_group_mismatch[toolbar.section] then
        warned_group_mismatch[toolbar.section] = true
        reaper.ShowConsoleMsg(
            "Advanced Toolbars: TOOLBAR_GROUPS mismatch for " .. tostring(toolbar.section) ..
            " (config=" .. tostring(configured_count) .. ", parsed=" .. tostring(#toolbar.groups) .. ")\n"
        )
    end
end

function ToolbarParser:parseToolbars(iniContent)
    if not iniContent then
        return {}
    end

    local state = C.ButtonManager.new()
    local toolbars = {}
    local current_toolbar, current_buttons = nil, {}

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
                current_toolbar.ini_title = title
                -- Canonical precedence: user CUSTOM_NAME overrides REAPER title= when present.
                if not current_toolbar.custom_name or current_toolbar.custom_name == "" then
                    current_toolbar:updateName(title)
                end
            elseif line:match("^item_%d+") then
                local item_number, id, text = UTILS.parseToolbarItemLine(line)
                if id then
                    local button = C.ButtonDefinition.createButton(id, text or "", item_number)

                    local toolbar_config = current_toolbar.cached_toolbar_config
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
                        
                        self:applyButtonProperties(button, button_config)
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


return ToolbarParser