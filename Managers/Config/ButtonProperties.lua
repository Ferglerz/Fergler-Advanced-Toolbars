return function(ConfigManager)
function ConfigManager:collectButtonProperties(toolbar)
    local button_properties = {}
    if not toolbar then
        return button_properties
    end

    for i, button in ipairs(toolbar.buttons) do
        local canonical_key = C.ButtonDefinition.createPropertyKey(button.id, button.original_text, i - 1)
        button.property_key = canonical_key

        local props = {}
        
        -- Always save instance_id to maintain uniqueness
        if button.instance_id then
            props.instance_id = button.instance_id
        end
        
        -- Save button type for proper reconstruction
        if button.button_type and button.button_type ~= "normal" then
            props.button_type = button.button_type
        end
        
        if button.display_text ~= button.original_text then
            props.name = button.display_text
        end
        if button.hide_label then
            props.hide_label = button.hide_label
        end
        if button.hide_bg_shadow then
            props.hide_bg_shadow = button.hide_bg_shadow
        end
        if button.alignment ~= "center" then
            props.justification = button.alignment
        end
        if button.icon_path then
            props.icon_path = button.icon_path
        end
        if button.reaper_icon_path then
            props.reaper_icon_path = button.reaper_icon_path
        end
        if button.reaper_track_icon_path then
            props.reaper_track_icon_path = button.reaper_track_icon_path
        end
        if button.icon_char then
            props.icon_char = button.icon_char
        end
        if button.icon_font then
            props.icon_font = button.icon_font
        end
        if button.custom_color then
            props.custom_color = button.custom_color
        end
        
        -- Only save these properties for normal buttons
        if not button:isSeparator() then
            if button.right_click ~= "arm" then
                props.right_click = button.right_click
            end
            if button.right_click_action and not button.right_click_action == "" then
                props.right_click_action = button.right_click_action
            end

            if button.dropdown_menu and #button.dropdown_menu > 0 then
                local sanitized_dropdown = {}
                for _, item in ipairs(button.dropdown_menu) do
                    if item.is_separator then
                        table.insert(sanitized_dropdown, {is_separator = true})
                    elseif item.is_heading then
                        table.insert(
                            sanitized_dropdown,
                            {is_heading = true, name = item.name or ""}
                        )
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
                props.dropdown_menu = sanitized_dropdown
            end

            if button.widget then
                props.widget = {
                    name = button.widget.name,
                }
                if button.widget.exportPersistedOptions then
                    local ok, extra = pcall(button.widget.exportPersistedOptions, button.widget)
                    if ok and type(extra) == "table" then
                        props.widget.options = extra
                    end
                end
                if button.widget.default_snap_disabled ~= nil then
                    props.widget.options = props.widget.options or {}
                    props.widget.options.default_snap_disabled = button.widget.default_snap_disabled
                end
                if button.widget.knob_bg_direction ~= nil then
                    props.widget.options = props.widget.options or {}
                    props.widget.options.knob_bg_direction = button.widget.knob_bg_direction
                end
            end
        end

        if next(props) then
            button_properties[canonical_key] = props
        end
    end

    return button_properties
end

function ConfigManager:collectToolbarGroups(toolbar)
    local toolbar_groups = {}
    if toolbar.groups and #toolbar.groups > 0 then
        for _, group in ipairs(toolbar.groups) do
            local gl = group.group_label
            table.insert(
                toolbar_groups,
                {
                    group_label = {text = (gl and gl.text) or ""},
                    is_split_point_h = group.is_split_point_h or false,
                    is_split_point_v = group.is_split_point_v or false
                }
            )
        end
    end
    return toolbar_groups
end

end
