-- Menus/Button_Settings_Menu.lua

local ButtonSettingsMenu = {}
ButtonSettingsMenu.__index = ButtonSettingsMenu

function ButtonSettingsMenu.new()
    local self = setmetatable({}, ButtonSettingsMenu)

    return self
end

function ButtonSettingsMenu:handleButtonSettingsMenu(ctx, button, active_group, is_vertical_layout)
    -- Use instance_id for unique popup identification
    local popup_id = "button_settings_menu_" .. button.instance_id

    local colorCount, styleCount = C.GlobalStyle.apply(ctx)
    if not reaper.ImGui_BeginPopup(ctx, popup_id) then
        C.GlobalStyle.reset(ctx, colorCount, styleCount)
        return false
    end

    -- Show button type in header
    if button:isSeparator() then
        reaper.ImGui_TextDisabled(ctx, "Separator Button")
        reaper.ImGui_Separator(ctx)
        
        -- Limited options for separators
        if reaper.ImGui_MenuItem(ctx, "Name and Icon") then
            C.IconSelector:show(button, ctx)
        end

        if reaper.ImGui_MenuItem(ctx, "Hide Name", nil, button.hide_label) then
            button.hide_label = not button.hide_label
            if button.clearLayoutCache then
                button:clearLayoutCache()
            else
                button:clearCache()
            end
            button:saveChanges()
        end

        if reaper.ImGui_BeginMenu(ctx, "Text Alignment") then
            self:handleAlignmentMenu(ctx, button)
            reaper.ImGui_EndMenu(ctx)
        end

        reaper.ImGui_Separator(ctx)

        -- Colors and icons for separators
        self:addColorMenus(ctx, button)
        reaper.ImGui_Separator(ctx)

        local icon_actions = {
            ["Choose Image Icon"] = function()
                self:handleIconPathChange(button)
            end,
            ["Remove Icon"] = function()
                self:handleRemoveIcon(button)
            end
        }

        for label, action in pairs(icon_actions) do
            if label ~= "Remove Icon" or (button.icon_path or button.icon_char) then
                if reaper.ImGui_MenuItem(ctx, label) then
                    action()
                    button:saveChanges()
                end
            end
        end
    else
        -- Full options for normal buttons
        local has_widget = button.widget ~= nil

        if not has_widget then
            if reaper.ImGui_MenuItem(ctx, "Name and Icon") then
                C.IconSelector:show(button, ctx)
            end

            if reaper.ImGui_MenuItem(ctx, "Hide Name", nil, button.hide_label) then
                button.hide_label = not button.hide_label
                if button.clearLayoutCache then
                    button:clearLayoutCache()
                else
                    button:clearCache()
                end
                button:saveChanges()
            end

            if reaper.ImGui_BeginMenu(ctx, "Text Alignment") then
                self:handleAlignmentMenu(ctx, button)
                reaper.ImGui_EndMenu(ctx)
            end

            if C.ActionSearch and reaper.ImGui_MenuItem(ctx, "Assign Action…") then
                C.ActionSearch:open({ mode = "change_action", button = button, ctx = ctx })
            end

            reaper.ImGui_Separator(ctx)

            -- Right-click behavior (only when no widget — widget owns interaction)
            self:handleRightClickMenu(ctx, button)
            if button.right_click == "dropdown" and reaper.ImGui_MenuItem(ctx, "Edit Dropdown Items") then
                self.dropdown_edit_button = button
            elseif button.right_click == "launch" and reaper.ImGui_MenuItem(ctx, "Choose Right-Click Action…") then
                if C.ActionSearch then
                    C.ActionSearch:open({ mode = "right_click_action", button = button, ctx = ctx })
                else
                    self:handleRightClickAction(button)
                end
            end
        end

        reaper.ImGui_Separator(ctx)

        -- Widget handling (only for normal buttons)
        if WIDGETS then
            if reaper.ImGui_MenuItem(ctx, button.widget and "Change Widget" or "Assign Widget") then
                self:showWidgetSelector(button, ctx)
            end

            if button.widget and reaper.ImGui_MenuItem(ctx, "Remove Widget") then
                C.WidgetsManager:removeWidgetFromButton(button)
                button:clearCache()
                button:saveChanges()
            end
        end

        if self.show_widget_selector then
            -- Selector is rendered globally from ToolbarWindow:renderUIElements().
            -- Do not render it here as well, or duplicate windows can appear.
            self.show_widget_selector = false
        end

        reaper.ImGui_Separator(ctx)

        self:addColorMenus(ctx, button)
        if not has_widget then
            reaper.ImGui_Separator(ctx)

            local icon_actions = {
                ["Choose Image Icon"] = function()
                    self:handleIconPathChange(button)
                end,
                ["Remove Icon"] = function()
                    self:handleRemoveIcon(button)
                end
            }

            for label, action in pairs(icon_actions) do
                if label ~= "Remove Icon" or (button.icon_path or button.icon_char) then
                    if reaper.ImGui_MenuItem(ctx, label) then
                        action()
                        button:saveChanges()
                    end
                end
            end
        end
    end

    reaper.ImGui_Separator(ctx)
    if reaper.ImGui_MenuItem(ctx, "Open toolbar settings") then
        reaper.ImGui_CloseCurrentPopup(ctx)
        if C.Interactions then
            C.Interactions.open_toolbar_settings_deferred = true
            C.Interactions.button_settings_button = nil
            C.Interactions.button_settings_group = nil
        end
    end

    -- Group options (available to both types)
    if active_group and CONFIG.UI.USE_GROUP_LABELS then
        reaper.ImGui_Separator(ctx)
        
        local group_label = #active_group.group_label.text > 0 and "Rename Group" or "Name Group"
        if reaper.ImGui_MenuItem(ctx, group_label) then
            local retval, new_name =
                reaper.GetUserInputs("Group Name", 1, "Group Name:,extrawidth=100", active_group.group_label.text or "")
            if retval then
                active_group.group_label.text = new_name
                button:saveChanges()
            end
        end

        -- Add the split option; axis label follows current toolbar orientation.
        local split_label = is_vertical_layout and "Up/Down Split From This Group" or "Left/Right Split From This Group"
        if reaper.ImGui_MenuItem(ctx, split_label, nil, active_group.is_split_point) then
            active_group.is_split_point = not active_group.is_split_point
            button:saveChanges()
        end
    end

    reaper.ImGui_Separator(ctx)

    -- Remove Button option in red color at the bottom
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0xFF4444FF) -- Red color
    if reaper.ImGui_MenuItem(ctx, button:isSeparator() and "Remove Separator" or "Remove Button") then
        self:handleRemoveButton(button)
    end
    reaper.ImGui_PopStyleColor(ctx)

    C.GlobalStyle.reset(ctx, colorCount, styleCount)
    reaper.ImGui_EndPopup(ctx)
    return true
end

-- Right-click behavior submenu (only for normal buttons)
function ButtonSettingsMenu:handleRightClickMenu(ctx, button)
    if not reaper.ImGui_BeginMenu(ctx, "Right-Click Behavior") then
        return false
    end

    local options = {
        ["Arm Command"] = "arm",
        ["Show Dropdown"] = "dropdown", 
        ["Launch Action"] = "launch",
        ["No Action"] = "none"
    }

    for label, value in pairs(options) do
        if reaper.ImGui_MenuItem(ctx, label, nil, button.right_click == value) then
            button.right_click = value
            button:saveChanges()
        end
    end

    reaper.ImGui_EndMenu(ctx)
    return true
end

-- Text alignment submenu
function ButtonSettingsMenu:handleAlignmentMenu(ctx, button)
    local alignments = {"left", "center", "right"}
    for _, align in ipairs(alignments) do
        if reaper.ImGui_MenuItem(ctx, align:gsub("^%l", string.upper), nil, button.alignment == align) then
            button.alignment = align
            if button.clearLayoutCache then
                button:clearLayoutCache()
            else
                button:clearCache()
            end
            button:saveChanges()
        end
    end
end

-- Icon path change handler
function ButtonSettingsMenu:handleIconPathChange(button)
    local retval, icon_path = reaper.GetUserFileNameForRead("", "Select Icon File", "")
    if not retval then
        return false
    end

    -- Normalize path to consistent form
    icon_path = UTILS.normalizeSlashes(icon_path)

    -- Verify the image can be loaded
    local test_texture = reaper.ImGui_CreateImage(icon_path)
    if not test_texture then
        reaper.ShowMessageBox("Failed to load icon: " .. icon_path, "Error", 0)
        return false
    end

    button.icon_path = icon_path
    button.icon_char = nil
    button.icon_font = nil
    if button.clearLayoutCache then
        button:clearLayoutCache()
    else
        button:clearCache()
    end
    C.ButtonManager:clearIconCache()
    button:saveChanges()
    return true
end

-- Remove icon handler
function ButtonSettingsMenu:handleRemoveIcon(button)
    if not (button.icon_path or button.icon_char) then
        return false
    end

    button.icon_path = nil
    button.icon_char = nil
    button.icon_font = nil
    if button.clearLayoutCache then
        button:clearLayoutCache()
    else
        button:clearCache()
    end
    C.ButtonManager:clearIconCache()
    button:saveChanges()
    return true
end

-- Remove button handler
function ButtonSettingsMenu:handleRemoveButton(button)
    return C.IniManager:deleteButton(button)
end

function ButtonSettingsMenu:handleRightClickAction(button)
    local current_action = button.right_click_action or ""
    local retval, new_action = reaper.GetUserInputs(
        "Set Right-Click Action",
        1,
        "Command ID:,extrawidth=80",
        current_action
    )

    if not retval then
        return false
    end

    button.right_click_action = new_action
    button:saveChanges()
    return true
end

-- Load color presets from external file
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
        CONFIG_MANAGER:saveMainConfig()
    end
    
    -- Link Background/Border toggle
    local link_bg_border_changed, link_bg_border = reaper.ImGui_Checkbox(ctx, "Link Background/Border", CONFIG.COLOR_SETTINGS.LINK_BG_BORDER)
    if link_bg_border_changed then
        CONFIG.COLOR_SETTINGS.LINK_BG_BORDER = link_bg_border
        CONFIG_MANAGER:saveMainConfig()
    end
    
    -- Link Text/Icon toggle
    local link_text_icon_changed, link_text_icon = reaper.ImGui_Checkbox(ctx, "Link Text/Icon", CONFIG.COLOR_SETTINGS.LINK_TEXT_ICON)
    if link_text_icon_changed then
        CONFIG.COLOR_SETTINGS.LINK_TEXT_ICON = link_text_icon
        CONFIG_MANAGER:saveMainConfig()
    end
    
    reaper.ImGui_Separator(ctx)

    -- Color presets section at the top
    reaper.ImGui_Text(ctx, "Color Presets:")
    reaper.ImGui_Separator(ctx)
    
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
    
    reaper.ImGui_Separator(ctx)

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
function ButtonSettingsMenu:showWidgetSelector(button, owner_ctx_or_opts)
    local widget_list = C.WidgetsManager:getWidgetList()
    local opts = {}
    local owner_ctx = nil
    if type(owner_ctx_or_opts) == "table" then
        opts = owner_ctx_or_opts
        owner_ctx = opts.owner_ctx
    else
        owner_ctx = owner_ctx_or_opts
    end

    self.widget_selection = {
        widget_list = widget_list,
        button = button,
        owner_ctx = owner_ctx,
        selected_index = #widget_list > 0 and 1 or 0,
        is_open = true,
        preview_cache = {},
        preview_style_custom = button.custom_color and CONFIG_MANAGER:deepCopy(button.custom_color) or nil,
        preview_style_user = button.user_colors and CONFIG_MANAGER:deepCopy(button.user_colors) or nil,
        preview_style_border = button.border_offset
            and { saturation = button.border_offset.saturation, value = button.border_offset.value }
            or nil,
        preview_button_shell = self._widget_preview_shell,
        insert_new_button = opts and opts.insert_new_button == true,
        target_button = opts and opts.target_button or button,
        insert_position = (opts and opts.position) or "before"
    }

    if not self._widget_preview_shell then
        local shell = C.ButtonDefinition.createNoopButton("")
        shell.saveChanges = function() end
        self._widget_preview_shell = shell
        self.widget_selection.preview_button_shell = shell
    end

    if C.PopupContext then
        C.PopupContext.open(self.widget_selection, owner_ctx)
    end

    -- Set a flag to open the widget selector popup in the next frame
    self.show_widget_selector = true
end

function ButtonSettingsMenu:renderWidgetSelector(ctx)
    if C.PopupContext then
        if not C.PopupContext.shouldRender(self.widget_selection, ctx) then
            return false
        end
    elseif (not self.widget_selection or not self.widget_selection.is_open) then
        return false
    end

    local vp = reaper.ImGui_GetMainViewport(ctx)
    local cx, cy = reaper.ImGui_Viewport_GetWorkCenter(vp)
    reaper.ImGui_SetNextWindowPos(ctx, cx, cy, reaper.ImGui_Cond_Appearing(), 0.5, 0.5)
    reaper.ImGui_SetNextWindowSize(ctx, 760, 520, reaper.ImGui_Cond_FirstUseEver())

    local window_flags = reaper.ImGui_WindowFlags_NoCollapse() | reaper.ImGui_WindowFlags_NoDocking()
    if reaper.ImGui_WindowFlags_NoScrollbar then
        window_flags = window_flags | reaper.ImGui_WindowFlags_NoScrollbar()
    end
    if reaper.ImGui_WindowFlags_NoScrollWithMouse then
        window_flags = window_flags | reaper.ImGui_WindowFlags_NoScrollWithMouse()
    end
    local colorCount, styleCount = C.GlobalStyle.apply(ctx)

    local window_title = "Select Widget##" .. self.widget_selection.button.instance_id
    local visible, open = reaper.ImGui_Begin(ctx, window_title, true, window_flags)
    self.widget_selection.is_open = open
    UTILS.snapWindowToMinimum(ctx, 0, 0, true)
    local esc_pressed = reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape())

    if not open or esc_pressed then
        if C.PopupContext then
            C.PopupContext.close(self.widget_selection)
        else
            self.widget_selection.is_open = false
        end
        reaper.ImGui_End(ctx)
        C.GlobalStyle.reset(ctx, colorCount, styleCount)
        return false
    end

    if visible then
        local sel = self.widget_selection

        local function applySelectedWidget()
            local idx = sel.selected_index
            if type(idx) ~= "number" or idx < 1 or idx > #sel.widget_list then
                return
            end
            local w = sel.widget_list[idx]
            if not w then
                return
            end
            local function closeSelector()
                if C.PopupContext then
                    C.PopupContext.close(sel)
                else
                    sel.is_open = false
                end
            end

            if sel.insert_new_button then
                local target = sel.target_button
                if not target or not target.parent_toolbar then
                    reaper.ShowMessageBox("Could not find toolbar target for widget insertion", "Error", 0)
                    return
                end

                local section = target.parent_toolbar.section
                local insert_at = nil
                if target.parent_toolbar.buttons then
                    for i, b in ipairs(target.parent_toolbar.buttons) do
                        if b.instance_id == target.instance_id then
                            insert_at = i
                            break
                        end
                    end
                end

                if not insert_at then
                    reaper.ShowMessageBox("Could not determine insertion index for widget button", "Error", 0)
                    return
                end

                local new_button = C.ButtonDefinition.createNoopButton()
                new_button.parent_toolbar = target.parent_toolbar
                local new_instance_id = new_button.instance_id

                if C.ButtonRenderer and C.ButtonRenderer.getInsertionColorSource then
                    local color_source = C.ButtonRenderer:getInsertionColorSource(target)
                    if color_source then
                        C.ButtonRenderer:copyColorProperties(color_source, new_button)
                    end
                elseif C.ButtonRenderer then
                    C.ButtonRenderer:copyColorProperties(target, new_button)
                end

                local insert_position = sel.insert_position or "before"
                if not C.IniManager:insertButton(target, new_button, insert_position) then
                    reaper.ShowMessageBox("Failed to create button for widget", "Error", 0)
                    return
                end

                -- insertButton already ran reloadToolbarsNow; grab parsed toolbar from any controller (same disk).
                local fresh_tb
                for _, controller_data in ipairs(_G.TOOLBAR_CONTROLLERS or {}) do
                    local ctrl = controller_data.controller
                    if ctrl and ctrl.toolbars then
                        for _, tb in ipairs(ctrl.toolbars) do
                            if tb.section == section then
                                fresh_tb = tb
                                break
                            end
                        end
                    end
                    if fresh_tb then
                        break
                    end
                end
                if not fresh_tb or not fresh_tb.buttons then
                    reaper.ShowMessageBox("Failed to locate toolbar section after insert", "Error", 0)
                    return
                end

                local target_idx
                for i, b in ipairs(fresh_tb.buttons) do
                    if b.instance_id == target.instance_id then
                        target_idx = i
                        break
                    end
                end
                if not target_idx then
                    reaper.ShowMessageBox("Failed to locate anchor button after insert", "Error", 0)
                    return
                end

                local inserted = nil
                for _, b in ipairs(fresh_tb.buttons) do
                    if b.instance_id == new_instance_id then
                        inserted = b
                        break
                    end
                end
                if not inserted then
                    local inserted_index = insert_position == "before" and (target_idx - 1) or (target_idx + 1)
                    if inserted_index >= 1 and inserted_index <= #fresh_tb.buttons then
                        inserted = fresh_tb.buttons[inserted_index]
                    end
                end
                if not inserted then
                    reaper.ShowMessageBox("Failed to locate inserted widget button", "Error", 0)
                    return
                end

                if C.WidgetsManager:assignWidgetToButton(inserted, w.name) then
                    inserted:clearCache()
                    CONFIG_MANAGER:saveToolbarConfig(inserted.parent_toolbar)
                    C.IniManager:reloadToolbarsNow()
                    closeSelector()
                else
                    reaper.ShowMessageBox("Failed to assign widget to new button", "Error", 0)
                end
            else
                if C.WidgetsManager:assignWidgetToButton(sel.button, w.name) then
                    sel.button:clearCache()
                    CONFIG_MANAGER:saveToolbarConfig(sel.button.parent_toolbar)
                    C.IniManager:reloadToolbarsNow()
                    closeSelector()
                else
                    reaper.ShowMessageBox("Failed to assign widget to button", "Error", 0)
                end
            end
        end

        local intro = self.widget_selection.insert_new_button
            and "Select a widget for the new button. Preview uses the target button's colors."
            or "Preview uses this button's colors. Double-click a tile or select one and click OK to assign."
        reaper.ImGui_TextWrapped(ctx, intro)
        reaper.ImGui_Separator(ctx)

        local avail_w, avail_h = reaper.ImGui_GetContentRegionAvail(ctx)
        avail_w = math.max(0, avail_w or 0)
        avail_h = math.max(0, avail_h or 0)
        local grid_inner_pad = 16
        local usable_grid_w = math.max(0, avail_w - (grid_inner_pad * 2))
        local sp_x = select(1, reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing()))
        local min_cell_w = 120
        local columns = math.max(1, math.floor((usable_grid_w + sp_x) / (min_cell_w + sp_x)))
        local cell_w = math.max(min_cell_w, math.floor((usable_grid_w - sp_x * (columns - 1)) / columns))
        local cell_h = CONFIG.SIZES.HEIGHT + 42
        local pad = 8
        local tile_rounding = math.max(6, math.floor((CONFIG.SIZES.ROUNDING or 6) * 0.75))

        local shell = sel.preview_button_shell or self._widget_preview_shell
        shell.custom_color = sel.preview_style_custom
        shell.user_colors = sel.preview_style_user
        shell.border_offset = sel.preview_style_border
        if shell.cache.colors then
            shell.cache.colors = nil
        end

        -- Reserve/pin footer space (help + action buttons) so only the list region scrolls.
        local footer_reserved_h = 124
        local list_start_y = reaper.ImGui_GetCursorPosY(ctx)
        local scroll_h = math.max(120, avail_h - footer_reserved_h)
        local grid_child_flags = reaper.ImGui_ChildFlags_Border and reaper.ImGui_ChildFlags_Border() or 0
        local hovered_widget = nil
        local selected_widget = (sel.selected_index and sel.widget_list[sel.selected_index]) or nil
        reaper.ImGui_BeginChild(ctx, "WidgetPreviewGrid", 0, scroll_h, grid_child_flags)
        reaper.ImGui_SetCursorPos(ctx, grid_inner_pad, grid_inner_pad)
        local grid_col = 0
        local prev_category
        local prev_subcategory
        for i, widget_entry in ipairs(sel.widget_list) do
                local cat = widget_entry.category or ""
                local sub = widget_entry.subcategory or ""
                if (prev_category or "") ~= cat then
                    if grid_col > 0 then
                        reaper.ImGui_NewLine(ctx)
                        grid_col = 0
                    end
                    reaper.ImGui_Separator(ctx)
                    reaper.ImGui_Text(ctx, cat ~= "" and cat or "General")
                    reaper.ImGui_Dummy(ctx, 0, 6)
                    prev_category = cat
                    prev_subcategory = nil
                end
                if sub ~= "" and sub ~= prev_subcategory then
                    if grid_col > 0 then
                        reaper.ImGui_NewLine(ctx)
                        grid_col = 0
                    end
                    reaper.ImGui_TextDisabled(ctx, sub)
                    reaper.ImGui_Dummy(ctx, 0, 4)
                    prev_subcategory = sub
                elseif sub == "" then
                    prev_subcategory = nil
                end

                if grid_col == 0 then
                    reaper.ImGui_SetCursorPosX(ctx, grid_inner_pad)
                else
                    reaper.ImGui_SameLine(ctx, 0, sp_x)
                end

                local tile_x = reaper.ImGui_GetCursorPosX(ctx)
                local tile_y = reaper.ImGui_GetCursorPosY(ctx)
                local tile_screen_x, tile_screen_y = reaper.ImGui_GetCursorScreenPos(ctx)

                reaper.ImGui_InvisibleButton(ctx, "##tile_pick_" .. widget_entry.name, cell_w, cell_h)
                local tile_hovered = reaper.ImGui_IsItemHovered(ctx)
                local tile_clicked = reaper.ImGui_IsItemClicked(ctx, 0)
                local tile_double_clicked = tile_hovered and reaper.ImGui_IsMouseDoubleClicked(ctx, 0)
                local is_selected = i == sel.selected_index

                if tile_clicked then
                    sel.selected_index = i
                    is_selected = true
                    selected_widget = widget_entry
                end
                if tile_double_clicked then
                    sel.selected_index = i
                    selected_widget = widget_entry
                    applySelectedWidget()
                end
                if tile_hovered then
                    hovered_widget = widget_entry
                end

                if not sel.preview_cache[widget_entry.name] then
                    sel.preview_cache[widget_entry.name] = C.WidgetsManager:cloneWidgetInstance(widget_entry.name)
                end
                shell.widget = sel.preview_cache[widget_entry.name]
                shell.widget._preview_mode = true
                shell:clearLayoutCache()
                local max_inner = cell_w - pad * 2
                shell.widget._preview_width_cap = max_inner
                C.LayoutManager:calculateWidgetButtonWidth(ctx, shell)
                local layout = shell.cache.layout
                local draw_w = max_inner

                local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
                local base_tile_bg = tile_hovered and 0x383838FF or 0x2D2D2DFF
                local tile_border = is_selected and 0xE8E5DCFF or (tile_hovered and 0x7D7D7DFF or 0x4F4F4FFF)
                reaper.ImGui_DrawList_AddRectFilled(
                    draw_list,
                    tile_screen_x,
                    tile_screen_y,
                    tile_screen_x + cell_w,
                    tile_screen_y + cell_h,
                    base_tile_bg,
                    tile_rounding
                )
                reaper.ImGui_DrawList_AddRect(
                    draw_list,
                    tile_screen_x,
                    tile_screen_y,
                    tile_screen_x + cell_w,
                    tile_screen_y + cell_h,
                    tile_border,
                    tile_rounding,
                    0,
                    is_selected and 2 or 1
                )

                local coords = COORDINATES.new(ctx)
                local state_key = C.Interactions:determineStateKey(shell)
                local bg_color, border_color = COLOR_UTILS.getButtonColors(shell, state_key, "NORMAL")
                local draw_layout = {
                    width = draw_w,
                    height = CONFIG.SIZES.HEIGHT,
                    extra_padding = layout.extra_padding or 0
                }
                local preview_x = tile_x + pad
                local preview_y = tile_y + pad
                C.ButtonRenderer:renderBackground(draw_list, shell, preview_x, preview_y, draw_w, bg_color, border_color, coords, false)
                C.WidgetRenderer:renderWidgetPreview(ctx, shell, preview_x, preview_y, coords, draw_list, draw_layout)
                shell.widget._preview_mode = nil
                shell.widget._preview_width_cap = nil

                local label_x, label_y = coords:relativeToDrawList(tile_x + pad, tile_y + pad + CONFIG.SIZES.HEIGHT + 6)
                reaper.ImGui_DrawList_AddText(draw_list, label_x, label_y, 0xD0D0D0FF, widget_entry.display_name)

                grid_col = grid_col + 1
                if grid_col >= columns then
                    grid_col = 0
                end
        end
        reaper.ImGui_EndChild(ctx)

        shell.widget = nil

        -- Anchor footer start to a deterministic Y, independent of content flow.
        local footer_start_y = list_start_y + scroll_h
        reaper.ImGui_SetCursorPosY(ctx, footer_start_y)

        reaper.ImGui_Separator(ctx)
        local info = hovered_widget or selected_widget
        if info then
            reaper.ImGui_Text(ctx, "Name: " .. (info.display_name or info.name or ""))
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_TextDisabled(ctx, "Type: " .. (info.type or ""))
            if info.description and info.description ~= "" then
                reaper.ImGui_TextWrapped(ctx, info.description)
            else
                reaper.ImGui_TextDisabled(ctx, "No help text available for this widget.")
            end
        else
            reaper.ImGui_TextDisabled(ctx, "Select a widget to see help information.")
        end

        -- Pin action buttons to the bottom edge of the reserved footer region.
        local sp_y = select(2, reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing()))
        local fp_y = select(2, reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding()))
        local button_h = reaper.ImGui_GetTextLineHeight(ctx) + (fp_y * 2)
        local buttons_y = footer_start_y + footer_reserved_h - button_h
        reaper.ImGui_SetCursorPosY(ctx, buttons_y)

        local btn_width = (reaper.ImGui_GetWindowWidth(ctx) - 20) / 2
        if reaper.ImGui_Button(ctx, "OK", btn_width, 0) then
            applySelectedWidget()
        end

        reaper.ImGui_SameLine(ctx, 0, sp_x)
        if reaper.ImGui_Button(ctx, "Cancel", btn_width, 0) then
            if C.PopupContext then
                C.PopupContext.close(sel)
            else
                sel.is_open = false
            end
        end
    end

    reaper.ImGui_End(ctx)
    C.GlobalStyle.reset(ctx, colorCount, styleCount)
    return self.widget_selection.is_open
end

return ButtonSettingsMenu