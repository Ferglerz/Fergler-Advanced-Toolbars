-- Menus/Global_Settings_Menu.lua

local GlobalSettingsMenu = {}
GlobalSettingsMenu.__index = GlobalSettingsMenu

function GlobalSettingsMenu.new()
    local self = setmetatable({}, GlobalSettingsMenu)

    return self
end

function GlobalSettingsMenu:renderSettingsRow(ctx, label, fn, control_id, value, min, max, format)
    -- Align text and control on same line with consistent spacing
    reaper.ImGui_AlignTextToFramePadding(ctx)
    reaper.ImGui_Text(ctx, label)

    -- Set control width and position
    reaper.ImGui_SameLine(ctx, reaper.ImGui_GetWindowWidth(ctx) / 4 - 10)
    reaper.ImGui_SetNextItemWidth(ctx, 120)

    -- Call the control function with appropriate parameters
    return fn(ctx, control_id, value, min, max, format)
end

function GlobalSettingsMenu:renderToolbarSelector(
    ctx,
    toolbars,
    currentToolbarIndex,
    setCurrentToolbar,
    toolbarController,
    toggleEditingMode)
    if not toolbars or #toolbars == 0 then
        reaper.ImGui_Text(ctx, "No toolbars found in reaper-menu.ini")
        return
    end

    reaper.ImGui_Separator(ctx)

    -- Create a row with left and right justified elements
    local content_width = reaper.ImGui_GetContentRegionAvail(ctx)

    -- Left side - Toolbar Selection text
    reaper.ImGui_TextDisabled(ctx, "Toolbar Selection:")

    -- Use toolbarController directly for all controller-related properties
    local dock_text = "Dock ID: " .. (toolbarController.current_dock_id or "!")
    local display_text = dock_text .. " | ID: " .. toolbarController.toolbar_id
    local display_text_width = reaper.ImGui_CalcTextSize(ctx, display_text)
    reaper.ImGui_SameLine(ctx, content_width - display_text_width)

    reaper.ImGui_TextDisabled(ctx, display_text)

    -- Use a combo box for selecting toolbars
    local current_toolbar = toolbars[currentToolbarIndex]
    local current_name = current_toolbar and (current_toolbar.custom_name or current_toolbar.name) or "None"

    reaper.ImGui_SetNextItemWidth(ctx, -1)
    if reaper.ImGui_BeginCombo(ctx, "##ToolbarSelector", current_name) then
        for i, toolbar in ipairs(toolbars) do
            local displayName = toolbar.custom_name or toolbar.name
            local is_selected = (currentToolbarIndex == i)

            if reaper.ImGui_Selectable(ctx, displayName, is_selected) then
                setCurrentToolbar(i)
                reaper.SetExtState("AdvancedToolbars", "last_toolbar_index", tostring(i), true)

                toolbarController.loader:loadToolbars()
            end

            if is_selected then
                reaper.ImGui_SetItemDefaultFocus(ctx)
            end

            if toolbar.custom_name and reaper.ImGui_IsItemHovered(ctx) then
                reaper.ImGui_BeginTooltip(ctx)
                reaper.ImGui_Text(ctx, toolbar.section)
                reaper.ImGui_EndTooltip(ctx)
            end
        end
        reaper.ImGui_EndCombo(ctx)
    end

    -- Toolbar management buttons
    if current_toolbar then
        reaper.ImGui_Spacing(ctx)

        -- Edit Toolbar button (moved to first position)
        local is_editing_mode = toggleEditingMode(nil, true)
        if reaper.ImGui_Button(ctx, "Edit Toolbar") then
            toggleEditingMode(not is_editing_mode)
            -- Close the Global Settings menu to get it out of the way
            reaper.ImGui_CloseCurrentPopup(ctx)
        end

        reaper.ImGui_SameLine(ctx)

        if reaper.ImGui_Button(ctx, "Rename Toolbar") then
            local current_name = current_toolbar.custom_name or current_toolbar.name
            local retval, new_name = reaper.GetUserInputs("Rename Toolbar", 1, "New Name:,extrawidth=100", current_name)

            if retval then
                current_toolbar:updateName(new_name)
                CONFIG_MANAGER:saveToolbarConfig(current_toolbar)
            end
        end

        reaper.ImGui_SameLine(ctx)

        if current_toolbar.custom_name and reaper.ImGui_Button(ctx, "Reset Name") then
            current_toolbar.custom_name = nil
            current_toolbar:updateName(nil)
            CONFIG_MANAGER:saveToolbarConfig(current_toolbar)
        end

        reaper.ImGui_SameLine(ctx)

        if reaper.ImGui_Button(ctx, "Create New Toolbar") then
            _G.CreateNewToolbar()
        end

        reaper.ImGui_SameLine(ctx)

        -- Delete Toolbar button with red text
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0xFF4444FF) -- Red color
        if reaper.ImGui_Button(ctx, "Delete Toolbar") then
            -- Remove the current toolbar controller from the global list
            if CONFIG.TOOLBAR_CONTROLLERS and next(CONFIG.TOOLBAR_CONTROLLERS) then
                local toolbar_id_str = tostring(toolbarController.toolbar_id)
                
                -- First check if we have at least 2 toolbar controllers
                local controller_count = 0
                for _ in pairs(CONFIG.TOOLBAR_CONTROLLERS) do
                    controller_count = controller_count + 1
                end
                
                if controller_count > 1 then
                    -- Remove this controller from CONFIG.TOOLBAR_CONTROLLERS
                    CONFIG.TOOLBAR_CONTROLLERS[toolbar_id_str] = nil
                    
                    -- Also remove from the global array
                    for i, controller_data in ipairs(_G.TOOLBAR_CONTROLLERS) do
                        if controller_data.controller.toolbar_id == toolbarController.toolbar_id then
                            table.remove(_G.TOOLBAR_CONTROLLERS, i)
                            break
                        end
                    end
                    
                    -- Save the updated configuration
                    CONFIG_MANAGER:saveMainConfig()
                    
                    -- Close the toolbar
                    toolbarController:setOpen(false)
                else
                    -- Don't allow deleting the last toolbar
                    reaper.ShowMessageBox("Cannot delete the last toolbar", "Error", 0)
                end
            end
        end
        reaper.ImGui_PopStyleColor(ctx) -- Pop the red color
    end
end

function GlobalSettingsMenu:render(
    ctx,
    saveCallback,
    toggleColorEditor,
    toggleEditingMode,
    toolbars,
    currentToolbarIndex,
    setCurrentToolbarIndex,
    toolbarController)
    -- Apply global style
    local colorCount, styleCount = C.GlobalStyle.apply(ctx)

    -- Render toolbar selector at the top
    self:renderToolbarSelector(ctx, toolbars, currentToolbarIndex, setCurrentToolbarIndex, toolbarController, toggleEditingMode)

    reaper.ImGui_TextDisabled(ctx, "Settings:")
    reaper.ImGui_Separator(ctx)

    -- Use two columns for settings
    local settings = {
        {
            label = "Button Height",
            control = reaper.ImGui_SliderInt,
            id = "##height",
            value = CONFIG.SIZES.HEIGHT,
            min = 20,
            max = 60,
            config_key = "HEIGHT"
        },
        {
            label = "Button Rounding",
            control = reaper.ImGui_SliderInt,
            id = "##rounding",
            value = CONFIG.SIZES.ROUNDING,
            min = 0,
            max = 30,
            config_key = "ROUNDING"
        },
        {
            label = "Min Button Width",
            control = reaper.ImGui_SliderInt,
            id = "##minwidth",
            value = CONFIG.SIZES.MIN_WIDTH,
            min = 20,
            max = 200,
            config_key = "MIN_WIDTH"
        },
        {
            label = "3D Depth",
            control = reaper.ImGui_SliderInt,
            id = "##depth",
            value = CONFIG.SIZES.DEPTH,
            min = 0,
            max = 6,
            config_key = "DEPTH"
        },
        {
            label = "Padding",
            control = reaper.ImGui_SliderInt,
            id = "##padding",
            value = CONFIG.SIZES.PADDING,
            min = 0,
            max = 50,
            config_key = "PADDING"
        },
        {
            label = "Button Spacing",
            control = reaper.ImGui_SliderInt,
            id = "##spacing",
            value = CONFIG.SIZES.SPACING,
            min = 0,
            max = 30,
            config_key = "SPACING"
        },
        {
            label = "Separator Size",
            control = reaper.ImGui_SliderInt,
            id = "##separator",
            value = CONFIG.SIZES.SEPARATOR_SIZE,
            min = 4,
            max = 50,
            config_key = "SEPARATOR_SIZE"
        },
        {
            label = "Text Size",
            control = reaper.ImGui_SliderInt,
            id = "##textsize",
            value = CONFIG.SIZES.TEXT,
            min = 8,
            max = 24,
            config_key = "TEXT"
        },
        {
            label = "Image Icon Scale",
            control = reaper.ImGui_SliderDouble,
            id = "##iconscale",
            value = CONFIG.ICON_FONT.SCALE,
            min = 0.1,
            max = 2.0,
            format = "%.2f",
            config_key = "SCALE",
            in_icon_font = true
        },
        {
            label = "Built-in Icon Size",
            control = reaper.ImGui_SliderInt,
            id = "##iconsize",
            value = CONFIG.ICON_FONT.SIZE,
            min = 4,
            max = 30,
            config_key = "SIZE",
            in_icon_font = true
        }
    }

    -- Render all sliders
    for i, setting in ipairs(settings) do
        -- Create two columns
        if i == 6 then -- Start second column after first 5 items (Button Height, Rounding, Min Width, 3D Depth, Padding)
            reaper.ImGui_SameLine(ctx, reaper.ImGui_GetWindowWidth(ctx) / 2 + 10)
            reaper.ImGui_BeginGroup(ctx)
        elseif i == 1 then -- Start first column
            reaper.ImGui_BeginGroup(ctx)
        end

        local changed, new_value =
            self:renderSettingsRow(
            ctx,
            setting.label,
            setting.control,
            setting.id,
            setting.value,
            setting.min,
            setting.max,
            setting.format
        )

        if changed then
            -- Update the appropriate config value
            if setting.in_icon_font then
                CONFIG.ICON_FONT[setting.config_key] = new_value
                -- If icon size changed, invalidate layout cache to re-render button widths
                if setting.config_key == "SIZE" then
                    self:invalidateButtonCache()
                end
            else
                CONFIG.SIZES[setting.config_key] = new_value
                -- If text size changed, invalidate layout cache to re-render button widths
                if setting.config_key == "TEXT" then
                    self:invalidateButtonCache()
                end
            end
            saveCallback()
        end

        -- End column groups
        if i == 5 or i == #settings then
            reaper.ImGui_EndGroup(ctx)
        end
    end

    reaper.ImGui_Separator(ctx)

    -- Menu toggles section
    local toggle_options = {
        {
            label = "Edit Colors",
            action = function()
                toggleColorEditor(true)
            end
        },
        {label = "Button Grouping", config = "USE_GROUPING", parent = "UI"},
        {label = "Group Labels", config = "USE_GROUP_LABELS", parent = "UI"}
    }

    for _, option in ipairs(toggle_options) do
        if option.config then
            -- Toggle option
            if reaper.ImGui_MenuItem(ctx, option.label, nil, CONFIG[option.parent][option.config]) then
                CONFIG[option.parent][option.config] = not CONFIG[option.parent][option.config]
                saveCallback()
            end
        else
            -- Action option
            if reaper.ImGui_MenuItem(ctx, option.label) then
                option.action()
            end
        end
    end

    reaper.ImGui_Separator(ctx)

    if reaper.ImGui_MenuItem(ctx, "Open Reaper Toolbar/Menu Editor") then
        reaper.Main_OnCommand(40905, 0)
    end

    if reaper.ImGui_MenuItem(ctx, "Reload Toolbar") then
        toolbarController.loader:loadToolbars()
    end

    C.GlobalStyle.reset(ctx, colorCount, styleCount)
end

function GlobalSettingsMenu:invalidateButtonCache()
    -- Clear layout and icon caches for all buttons to force recalculation when icon size changes
    for _, toolbar_controller in ipairs(_G.TOOLBAR_CONTROLLERS or {}) do
        if toolbar_controller and toolbar_controller.current_toolbar then
            for _, group in ipairs(toolbar_controller.current_toolbar.groups) do
                for _, button in ipairs(group.buttons) do
                    if button.cache then
                        -- Clear layout cache
                        button.cache.layout = nil
                        -- Clear icon cache to force recalculation
                        button.cache.icon_font = nil
                        button.cache.icon = nil
                    end
                end
            end
        end
    end
end

return GlobalSettingsMenu.new()