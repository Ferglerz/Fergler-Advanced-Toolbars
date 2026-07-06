local function loadColorPresets()
    local presets_path = SCRIPT_PATH .. "User/Button_Color_Presets.lua"
    local success, presets = pcall(dofile, presets_path)
    if success and presets then
        return presets
    else
        -- Fallback presets if file can't be loaded
        local fallback_presets = {
            {name = "Red", bg = "#E68888FF", border = "#D96666FF", hover_bg = "#EDA1A1FF", hover_border = "#E48F8FFF", active_bg = "#DF7A7AFF", active_border = "#D85555FF", text = "#000000FF", icon = "#000000FF"},
            {name = "Orange", bg = "#E6B888FF", border = "#D9A666FF", hover_bg = "#EDC9A1FF", hover_border = "#E4BE8FFF", active_bg = "#DFAB7AFF", active_border = "#D89855FF", text = "#000000FF", icon = "#000000FF"},
            {name = "Yellow", bg = "#E6E688FF", border = "#D9D966FF", hover_bg = "#EDEDA1FF", hover_border = "#E4E48FFF", active_bg = "#DFDF7AFF", active_border = "#D8D855FF", text = "#000000FF", icon = "#000000FF"},
            {name = "Blue", bg = "#88B8E6FF", border = "#66A6D9FF", hover_bg = "#A1C9EDFF", hover_border = "#8FBEE4FF", active_bg = "#7AABDFFF", active_border = "#5598D8FF", text = "#000000FF", icon = "#000000FF"},
            {name = "Purple", bg = "#B888E6FF", border = "#A666D9FF", hover_bg = "#C9A1EDFF", hover_border = "#BE8FE4FF", active_bg = "#AB7ADFFF", active_border = "#9855D8FF", text = "#000000FF", icon = "#000000FF"},
            {name = "Green", bg = "#88E688FF", border = "#66D966FF", hover_bg = "#A1EDA1FF", hover_border = "#8FE48FFF", active_bg = "#7ADF7AFF", active_border = "#55D855FF", text = "#000000FF", icon = "#000000FF"},
            {name = "Cream", bg = "#F5F0E8FF", border = "#E8E0D0FF", hover_bg = "#F8F5F0FF", hover_border = "#ECE5D8FF", active_bg = "#F0EADDFF", active_border = "#E0D5C0FF", text = "#000000FF", icon = "#000000FF"},
            {name = "Dark Gray", bg = "#9999A6FF", border = "#8080A0FF", hover_bg = "#A6A6B3FF", hover_border = "#9999AAFF", active_bg = "#8F8F9CFF", active_border = "#737388FF", text = "#FFFFFFFF", icon = "#FFFFFFFF"},
            {name = "Coral", bg = "#F09888FF", border = "#E07868FF", hover_bg = "#F8B0A0FF", hover_border = "#E89080FF", active_bg = "#E88070FF", active_border = "#D86858FF", text = "#000000FF", icon = "#000000FF"},
            {name = "Mint", bg = "#88E8C8FF", border = "#66D9B0FF", hover_bg = "#A0F0D8FF", hover_border = "#88E8C8FF", active_bg = "#78D8B8FF", active_border = "#55C8A0FF", text = "#000000FF", icon = "#000000FF"},
            {name = "Lavender", bg = "#C8A8F0FF", border = "#B088E0FF", hover_bg = "#D8C0F8FF", hover_border = "#C8A8F0FF", active_bg = "#B898E8FF", active_border = "#A078D8FF", text = "#000000FF", icon = "#000000FF"},
            {name = "Peach", bg = "#FFD0B8FF", border = "#F0B898FF", hover_bg = "#FFE0D0FF", hover_border = "#F8C8B0FF", active_bg = "#F8C0A0FF", active_border = "#E8A888FF", text = "#000000FF", icon = "#000000FF"},
            {name = "Sky", bg = "#98D8F8FF", border = "#78C8E8FF", hover_bg = "#B0E8FFFF", hover_border = "#90D8F0FF", active_bg = "#88D0F0FF", active_border = "#68B8E0FF", text = "#000000FF", icon = "#000000FF"},
            {name = "Rose", bg = "#F0A0D0FF", border = "#E888B8FF", hover_bg = "#F8B8E0FF", hover_border = "#F0A0C8FF", active_bg = "#E890C0FF", active_border = "#D878A8FF", text = "#000000FF", icon = "#000000FF"},
            {name = "Lime", bg = "#D0F888FF", border = "#B8E868FF", hover_bg = "#E0FFA0FF", hover_border = "#D0F888FF", active_bg = "#C8F070FF", active_border = "#B0E858FF", text = "#000000FF", icon = "#000000FF"},
            {name = "Teal", bg = "#70D8D0FF", border = "#58C8C0FF", hover_bg = "#88E8E0FF", hover_border = "#70D8D8FF", active_bg = "#60C8C0FF", active_border = "#48B8B0FF", text = "#000000FF", icon = "#000000FF"},
            {name = "Black", bg = "#2C2C32FF", border = "#1E1E24FF", hover_bg = "#383840FF", hover_border = "#282830FF", active_bg = "#24242AFF", active_border = "#18181EFF", text = "#FFFFFFFF", icon = "#FFFFFFFF"},
            {name = "White", bg = "#FAFAFAFF", border = "#DCDCDCFF", hover_bg = "#FFFFFFFF", hover_border = "#E8E8E8FF", active_bg = "#F0F0F0FF", active_border = "#D0D0D0FF", text = "#000000FF", icon = "#000000FF"},
            {name = "Slate", bg = "#94A8B8FF", border = "#7890A8FF", hover_bg = "#A8B8C8FF", hover_border = "#90A0B8FF", active_bg = "#88A0B0FF", active_border = "#708898FF", text = "#000000FF", icon = "#000000FF"},
            {name = "Amber", bg = "#F0C878FF", border = "#E8B050FF", hover_bg = "#F8D898FF", hover_border = "#F0C870FF", active_bg = "#E8B860FF", active_border = "#D8A040FF", text = "#000000FF", icon = "#000000FF"}
        }
        
        -- Try to create the file with fallback presets
        local file_content = "-- Button Color Presets\n-- This file contains color preset definitions that users can customize\n-- Each preset includes colors for normal, hover, and active states\n\nreturn {\n"
        for i, preset in ipairs(fallback_presets) do
            file_content = file_content .. string.format(
                "    {name = \"%s\", bg = \"%s\", border = \"%s\", hover_bg = \"%s\", hover_border = \"%s\", active_bg = \"%s\", active_border = \"%s\", text = \"%s\", icon = \"%s\"}%s\n",
                preset.name, preset.bg, preset.border, preset.hover_bg, preset.hover_border, preset.active_bg, preset.active_border, preset.text, preset.icon,
                i < #fallback_presets and "," or ""
            )
        end
        file_content = file_content .. "}"
        
        local file = io.open(presets_path, "w")
        if file then
            file:write(file_content)
            file:close()
        end
        
        return fallback_presets
    end
end

local COLOR_PRESETS = loadColorPresets()

-- Draw color preset circle
function ButtonSettingsMenu:drawColorPresetCircle(ctx, preset, size)
    local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
    local pos_x, pos_y = reaper.ImGui_GetCursorScreenPos(ctx)
    local center_x = pos_x + size * 0.5
    local center_y = pos_y + size * 0.5
    local radius = size * 0.4
    
    -- Convert colors
    local bg_color = COLOR_UTILS.toImGuiColor(preset.bg)
    local border_color = COLOR_UTILS.toImGuiColor(preset.border)
    
    -- Draw background circle
    reaper.ImGui_DrawList_AddCircleFilled(draw_list, center_x, center_y, radius, bg_color)
    
    -- Draw border circle
    reaper.ImGui_DrawList_AddCircle(draw_list, center_x, center_y, radius, border_color, 0, 2.0)
    
    -- Invisible button for interaction
    reaper.ImGui_InvisibleButton(ctx, "preset_" .. preset.name, size, size)
    
    return reaper.ImGui_IsItemClicked(ctx)
end

-- Color menus
function ButtonSettingsMenu:addColorMenus(ctx, button)
    if not reaper.ImGui_BeginMenu(ctx, "Button Colors") then
        return false
    end

    -- Global color settings
    reaper.ImGui_Text(ctx, "Color Options:")
    
    -- Apply to Group toggle
    local apply_to_group_changed, apply_to_group = reaper.ImGui_Checkbox(ctx, "Apply to Group", CONFIG.COLOR_SETTINGS.APPLY_TO_GROUP)
    if apply_to_group_changed then
        CONFIG.COLOR_SETTINGS.APPLY_TO_GROUP = apply_to_group
        -- Save to user config
        CONFIG_MANAGER:requestSaveMainConfig()
    end
    
    -- Link Background/Border toggle
    local link_bg_border_changed, link_bg_border = reaper.ImGui_Checkbox(ctx, "Link Background/Border", CONFIG.COLOR_SETTINGS.LINK_BG_BORDER)
    if link_bg_border_changed then
        CONFIG.COLOR_SETTINGS.LINK_BG_BORDER = link_bg_border
        CONFIG_MANAGER:requestSaveMainConfig()
    end
    
    -- Link Text/Icon toggle
    local link_text_icon_changed, link_text_icon = reaper.ImGui_Checkbox(ctx, "Link Text/Icon", CONFIG.COLOR_SETTINGS.LINK_TEXT_ICON)
    if link_text_icon_changed then
        CONFIG.COLOR_SETTINGS.LINK_TEXT_ICON = link_text_icon
        CONFIG_MANAGER:requestSaveMainConfig()
    end
    
    self:drawSeparator(ctx)

    -- Color presets section at the top
    reaper.ImGui_Text(ctx, "Color Presets:")
    self:drawSeparator(ctx)
    
    local preset_size = 24
    local presets_per_row = 4
    
    for i, preset in ipairs(COLOR_PRESETS) do
        if (i - 1) % presets_per_row ~= 0 then
            reaper.ImGui_SameLine(ctx)
        end
        
        if self:drawColorPresetCircle(ctx, preset, preset_size) then
            -- Apply the color preset to the button
            self:applyColorPreset(button, preset)
            -- Close the menu after applying preset
            reaper.ImGui_CloseCurrentPopup(ctx)
        end
        
        if reaper.ImGui_IsItemHovered(ctx) then
            reaper.ImGui_SetTooltip(ctx, preset.name)
        end
    end
    
    self:drawSeparator(ctx)

    -- Separators only need line color; regular buttons use background, border, and text/icon (merged when linked)
    if button:isSeparator() then
        if reaper.ImGui_BeginMenu(ctx, "Line Color") then
            C.ButtonColorEditor:renderColorPicker(ctx, button, "line")
            reaper.ImGui_EndMenu(ctx)
        end
    else
        if reaper.ImGui_BeginMenu(ctx, "Background Color") then
            C.ButtonColorEditor:renderColorPicker(ctx, button, "background")
            reaper.ImGui_EndMenu(ctx)
        end

        local border_menu_title = CONFIG.COLOR_SETTINGS.LINK_BG_BORDER and "Border Offset" or "Border Color"
        local border_picker = CONFIG.COLOR_SETTINGS.LINK_BG_BORDER and "border_offset" or "border"
        if reaper.ImGui_BeginMenu(ctx, border_menu_title) then
            C.ButtonColorEditor:renderColorPicker(ctx, button, border_picker)
            reaper.ImGui_EndMenu(ctx)
        end

        if CONFIG.COLOR_SETTINGS.LINK_TEXT_ICON then
            if reaper.ImGui_BeginMenu(ctx, "Text/icon Color") then
                C.ButtonColorEditor:renderColorPicker(ctx, button, "text_icon")
                reaper.ImGui_EndMenu(ctx)
            end
        else
            if reaper.ImGui_BeginMenu(ctx, "Text Color") then
                C.ButtonColorEditor:renderColorPicker(ctx, button, "text")
                reaper.ImGui_EndMenu(ctx)
            end
            if reaper.ImGui_BeginMenu(ctx, "Icon Color") then
                C.ButtonColorEditor:renderColorPicker(ctx, button, "icon")
                reaper.ImGui_EndMenu(ctx)
            end
        end
    end

    -- Copy colors to group option (only show if button is in a group with other buttons)
    if button.parent_group and #button.parent_group.buttons > 1 then
        if reaper.ImGui_MenuItem(ctx, "Copy Colors to Group") then
            -- Copy colors from this button to all other buttons in the group
            for _, targetButton in ipairs(button.parent_group.buttons) do
                if targetButton.instance_id ~= button.instance_id then
                    C.ButtonRenderer:copyColorProperties(button, targetButton)
                    targetButton:clearCache()
                    targetButton:saveChanges()
                end
            end
        end
    end

    -- Reset all colors option
    if reaper.ImGui_MenuItem(ctx, "Reset All Colors") then
        -- Get target buttons based on global setting
        local targetButtons = {button}
        if CONFIG.COLOR_SETTINGS.APPLY_TO_GROUP and button.parent_group then
            targetButtons = button.parent_group.buttons
        end
        
        -- Reset colors for all target buttons
        for _, targetButton in ipairs(targetButtons) do
            targetButton.custom_color = nil
            targetButton.border_offset = { saturation = 0.0, value = 0.0 }
            targetButton:clearCache()
        end
        
        button:saveChanges()
    end

    reaper.ImGui_EndMenu(ctx)
    return true
end

-- Apply color preset to button
function ButtonSettingsMenu:applyColorPreset(button, preset)
    -- Get target buttons based on "Apply to Group" setting
    local targetButtons = {button}
    if CONFIG.COLOR_SETTINGS.APPLY_TO_GROUP and button.parent_group then
        targetButtons = button.parent_group.buttons
    end
    
    -- Apply colors to all target buttons
    for _, targetButton in ipairs(targetButtons) do
        -- Initialize custom_color if it doesn't exist
        if not targetButton.custom_color then
            targetButton.custom_color = {}
        end
        
        -- Set colors using the correct structure that the system expects
        targetButton.custom_color.background = { normal = preset.bg }
        targetButton.custom_color.border = { normal = preset.border }
        targetButton.custom_color.text = { normal = preset.text or "#FFFFFFFF" }
        targetButton.custom_color.icon = { normal = preset.icon or "#FFFFFFFF" }
        
        -- Add hover and active states
        targetButton.custom_color.hover = {
            background = preset.hover_bg,
            border = preset.hover_border
        }
        targetButton.custom_color.active = {
            background = preset.active_bg,
            border = preset.active_border
        }
        
        -- Clear cache and save changes
        targetButton:clearCache()
        targetButton:saveChanges()
    end
end

-- Widget selector functions (only for normal buttons)
-- opts: optional { insert_new_button = bool, target_button = button, position = "before"|"after" }
