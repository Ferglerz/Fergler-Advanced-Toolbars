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
    reaper.ImGui_SameLine(ctx, 200)
    reaper.ImGui_SetNextItemWidth(ctx, 120)

    -- Call the control function with appropriate parameters
    return fn(ctx, control_id, value, min, max, format)
end

function GlobalSettingsMenu:renderToolbarSelector(ctx, toolbars, currentToolbarIndex, setCurrentToolbar)
    if not toolbars or #toolbars == 0 then
        reaper.ImGui_Text(ctx, "No toolbars found in reaper-menu.ini")
        return
    end

    reaper.ImGui_Separator(ctx)
    reaper.ImGui_TextDisabled(ctx, "Toolbar Selection:")

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
                C.ToolbarLoader:loadToolbars()
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

    -- Toolbar name management
    if current_toolbar then
        reaper.ImGui_Spacing(ctx)

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
    end
end

function GlobalSettingsMenu:render(
    ctx,
    saveCallback,
    toggleColorEditor,
    toggleEditingMode,
    toolbars,
    currentToolbarIndex,
    setCurrentToolbarIndex)
    -- Apply global style
    local colorCount, styleCount = C.GlobalStyle.apply(ctx)

    -- Render toolbar selector at the top
    self:renderToolbarSelector(ctx, toolbars, currentToolbarIndex, setCurrentToolbarIndex)

    reaper.ImGui_TextDisabled(ctx, "Settings:")
    reaper.ImGui_Separator(ctx)

    -- Editing mode toggle - ensure we're getting and setting a boolean value
    local is_editing_mode = toggleEditingMode(nil, true)
    if reaper.ImGui_MenuItem(ctx, "Button Editing Mode", nil, is_editing_mode) then
        toggleEditingMode(not is_editing_mode)
    end

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
            label = "Button Spacing",
            control = reaper.ImGui_SliderInt,
            id = "##spacing",
            value = CONFIG.SIZES.SPACING,
            min = 0,
            max = 30,
            config_key = "SPACING"
        },
        {
            label = "Separator Width",
            control = reaper.ImGui_SliderInt,
            id = "##separator",
            value = CONFIG.SIZES.SEPARATOR_WIDTH,
            min = 4,
            max = 50,
            config_key = "SEPARATOR_WIDTH"
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
            label = "Built-in Icon Size (must restart)",
            control = reaper.ImGui_SliderInt,
            id = "##iconsize",
            value = CONFIG.ICON_FONT.SIZE,
            min = 4,
            max = 18,
            config_key = "SIZE",
            in_icon_font = true
        }
    }

    -- Render all sliders
    for i, setting in ipairs(settings) do
        -- Create two columns
        if i == 5 then -- Start second column after first 4 items
            reaper.ImGui_SameLine(ctx, reaper.ImGui_GetWindowWidth(ctx) / 2 + 20)
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
            else
                CONFIG.SIZES[setting.config_key] = new_value
            end
            saveCallback()
        end

        -- End column groups
        if i == 4 or i == #settings then
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
        {label = "Hide All Button Labels", config = "HIDE_ALL_LABELS", parent = "UI"},
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

    if reaper.ImGui_MenuItem(ctx, "Toolbar Editor") then
        reaper.Main_OnCommand(40905, 0)
    end

    if reaper.ImGui_MenuItem(ctx, "Reload Toolbar") then
        C.ToolbarLoader:loadToolbars(self.toolbar_controller)
    end

    C.GlobalStyle.reset(ctx, colorCount, styleCount)
end

return GlobalSettingsMenu.new()
