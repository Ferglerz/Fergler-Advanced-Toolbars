-- Menus/Global_Settings_Menu.lua

-- FontIcons first glyph is U+00C0 (À). Resolve by name, else first icon font; lazy-create if needed (attach is done in CreateToolbar).
local function ensureReloadIconFont()
    if not ICON_FONTS or #ICON_FONTS == 0 then
        return nil
    end
    local _, font_map = UTILS.matchFontByBaseName("FontIcons", ICON_FONTS)
    if not font_map then
        font_map = ICON_FONTS[1]
    end
    if not font_map or not font_map.path then
        return nil
    end
    local base = SCRIPT_PATH or _G.SCRIPT_PATH
    if not font_map.font and base then
        font_map.font = reaper.ImGui_CreateFontFromFile(base .. font_map.path)
    end
    return font_map
end

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
    toggleEditingMode,
    toggleColorEditor)
    if not toolbars or #toolbars == 0 then
        reaper.ImGui_Text(ctx, "No toolbars found in toolbar configs")
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

    -- Get active toolbar indices (toolbars currently shown in other windows)
    local active_indices = {}
    if _G.getActiveToolbarIndices then
        active_indices = _G.getActiveToolbarIndices()
    end

    -- Reload | toolbar combo | Rename — same overall width as former full-width combo row
    local rename_label = "Rename Toolbar"
    local fp_x = select(1, reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding()))
    local item_spacing_x = select(1, reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing()))
    local rename_btn_w = reaper.ImGui_CalcTextSize(ctx, rename_label) + fp_x * 2
    local reload_icon = (utf8 and utf8.char(0xC0)) or "\195\128"
    local font_map = ensureReloadIconFont()
    local icon_size = CONFIG and CONFIG.ICON_FONT and CONFIG.ICON_FONT.SIZE
    local use_fonticons = font_map and font_map.font and icon_size
    if use_fonticons then
        reaper.ImGui_PushFont(ctx, font_map.font, icon_size)
    end
    if reaper.ImGui_Button(ctx, use_fonticons and reload_icon or "Reload Toolbar") then
        toolbarController.loader:loadToolbars()
    end
    if use_fonticons then
        reaper.ImGui_PopFont(ctx)
    end
    local hover_ft = reaper.ImGui_HoveredFlags_None()
    local ok_h, ft_val = pcall(function()
        return reaper.ImGui_HoveredFlags_ForTooltip()
    end)
    if ok_h and ft_val then
        hover_ft = ft_val
    end
    if reaper.ImGui_IsItemHovered(ctx, hover_ft) then
        reaper.ImGui_SetTooltip(ctx, "Reload Toolbar")
    end
    reaper.ImGui_SameLine(ctx)
    local avail_after_reload = reaper.ImGui_GetContentRegionAvail(ctx)
    local combo_w = math.max(80, avail_after_reload - rename_btn_w - item_spacing_x)
    reaper.ImGui_SetNextItemWidth(ctx, combo_w)
    if reaper.ImGui_BeginCombo(ctx, "##ToolbarSelector", current_name) then
        for i, toolbar in ipairs(toolbars) do
            local displayName = toolbar.custom_name or toolbar.name
            local is_selected = (currentToolbarIndex == i)
            local is_active = active_indices[i] and not is_selected -- Active in another window, but not this one

            -- Grey out toolbars that are active in other windows
            if is_active then
                reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_Alpha(), 0.5)
            end

            -- Only allow selection if not active in another window
            if reaper.ImGui_Selectable(ctx, displayName, is_selected) and not is_active then
                setCurrentToolbar(i)

                toolbarController.loader:loadToolbars()
            end

            if is_active then
                reaper.ImGui_PopStyleVar(ctx)
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

    reaper.ImGui_SameLine(ctx)
    if current_toolbar and reaper.ImGui_Button(ctx, rename_label) then
        local name_for_input = current_toolbar.custom_name or current_toolbar.name
        local retval, new_name = reaper.GetUserInputs("Rename Toolbar", 1, "New Name:,extrawidth=100", name_for_input)

        if retval then
            current_toolbar:updateName(new_name)
            CONFIG_MANAGER:saveToolbarConfig(current_toolbar)
        end
    elseif not current_toolbar then
        reaper.ImGui_BeginDisabled(ctx)
        reaper.ImGui_Button(ctx, rename_label)
        reaper.ImGui_EndDisabled(ctx)
    end

    -- Toolbar management buttons
    if current_toolbar then
        reaper.ImGui_Spacing(ctx)

        local is_editing_mode = toggleEditingMode(nil, true)
        if reaper.ImGui_Button(ctx, "Edit Mode") then
            toggleEditingMode(not is_editing_mode)
            reaper.ImGui_CloseCurrentPopup(ctx)
        end

        reaper.ImGui_SameLine(ctx)

        if reaper.ImGui_Button(ctx, "Edit Colors") then
            toggleColorEditor(true)
        end

        reaper.ImGui_SameLine(ctx)

        if reaper.ImGui_Button(ctx, "Launch new toolbar window") then
            _G.CreateNewToolbar()
        end

        reaper.ImGui_SameLine(ctx)

        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0xFF4444FF) -- Red color
        if reaper.ImGui_Button(ctx, "Close toolbar window") then
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
                    reaper.ShowMessageBox("Cannot close the last toolbar window", "Error", 0)
                end
            end
        end
        reaper.ImGui_PopStyleColor(ctx) -- Pop the red color
    end
end

function GlobalSettingsMenu:reloadToolbarSwitchWidgets()
    for _, cd in ipairs(_G.TOOLBAR_CONTROLLERS or {}) do
        if cd.controller and cd.controller.ensureToolbarSwitchWidget then
            cd.controller:ensureToolbarSwitchWidget()
        end
    end
    if C.LayoutManager then
        C.LayoutManager:requestLayoutRecalcAfterToolbarReady()
    end
end

function GlobalSettingsMenu:renderToolbarSwitchWidgetSetting(ctx, saveCallback)
    if not CONFIG.UI then
        return
    end
    reaper.ImGui_Separator(ctx)
    local en_changed, en =
        reaper.ImGui_Checkbox(
        ctx,
        "Enable toolbar switch widget on all toolbars##toolbar_switch_widget",
        CONFIG.UI.ENABLE_TOOLBAR_SWITCH_WIDGET
    )
    if en_changed then
        CONFIG.UI.ENABLE_TOOLBAR_SWITCH_WIDGET = en
        saveCallback()
        self:reloadToolbarSwitchWidgets()
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
    self:renderToolbarSelector(ctx, toolbars, currentToolbarIndex, setCurrentToolbarIndex, toolbarController, toggleEditingMode, toggleColorEditor)

    self:renderToolbarSwitchWidgetSetting(ctx, saveCallback)

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