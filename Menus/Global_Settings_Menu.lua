-- Menus/Global_Settings_Menu.lua

local GlobalSettingsMenu = {}
GlobalSettingsMenu.__index = GlobalSettingsMenu

function GlobalSettingsMenu.new()
    local self = setmetatable({}, GlobalSettingsMenu)
    -- [toolbar_id] = { x = string, y = string } for pin offset text fields
    self._pin_offset_text = {}
    -- [popup_id] = { x, y } screen position when opening menu-style popups at the cursor
    self._menu_popup_anchors = {}
    return self
end

local POPUP_TOOLBAR_LIST = "##atb_menu_toolbar_list"
local POPUP_UI_ANCHOR = "##atb_menu_ui_anchor"
local POPUP_UI_ALIGN = "##atb_menu_ui_align"

function GlobalSettingsMenu:menuPopupOpenAtMouse(ctx, popup_id)
    self._menu_popup_anchors = self._menu_popup_anchors or {}
    local mx, my = reaper.ImGui_GetMousePos(ctx)
    self._menu_popup_anchors[popup_id] = { x = mx, y = my }
    reaper.ImGui_OpenPopup(ctx, popup_id)
end

function GlobalSettingsMenu:menuPopupPrepareFrame(ctx, popup_id)
    local a = self._menu_popup_anchors and self._menu_popup_anchors[popup_id]
    if a then
        reaper.ImGui_SetNextWindowPos(ctx, a.x, a.y, reaper.ImGui_Cond_Always())
    end
end

function GlobalSettingsMenu:menuPopupEndFrame(ctx, popup_id)
    if not reaper.ImGui_IsPopupOpen(ctx, popup_id) then
        if self._menu_popup_anchors then
            self._menu_popup_anchors[popup_id] = nil
        end
    end
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

    -- Reload | toolbar combo | Rename — outer buttons align row 2 cols 1 & 4; combo width = cols 2+3
    local rename_label = "Rename Toolbar"
    local item_spacing_x = select(1, reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing()))
    local row_avail = reaper.ImGui_GetContentRegionAvail(ctx)
    local row2_cell = math.max(48, math.floor((row_avail - 3 * item_spacing_x) / 4))
    local combo_w = 2 * row2_cell + item_spacing_x
    if reaper.ImGui_Button(ctx, "Reload", row2_cell, 0) then
        toolbarController.loader:loadToolbars()
    end
    local hover_ft = reaper.ImGui_HoveredFlags_None()
    local ok_h, ft_val = pcall(function()
        return reaper.ImGui_HoveredFlags_ForTooltip()
    end)
    if ok_h and ft_val then
        hover_ft = ft_val
    end
    if reaper.ImGui_IsItemHovered(ctx, hover_ft) then
        reaper.ImGui_SetTooltip(ctx, "Reload toolbar")
    end
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, current_name .. "##ToolbarSelectorBtn", combo_w, 0) then
        self:menuPopupOpenAtMouse(ctx, POPUP_TOOLBAR_LIST)
    end
    if reaper.ImGui_IsItemHovered(ctx, hover_ft) then
        reaper.ImGui_SetTooltip(ctx, "Choose toolbar")
    end

    self:menuPopupPrepareFrame(ctx, POPUP_TOOLBAR_LIST)
    if reaper.ImGui_BeginPopup(ctx, POPUP_TOOLBAR_LIST) then
        for i, toolbar in ipairs(toolbars) do
            local displayName = toolbar.custom_name or toolbar.name
            local is_selected = (currentToolbarIndex == i)
            local is_active = active_indices[i] and not is_selected

            if reaper.ImGui_MenuItem(ctx, displayName, nil, is_selected, not is_active) then
                setCurrentToolbar(i)
                toolbarController.loader:loadToolbars()
            end

            if toolbar.custom_name and reaper.ImGui_IsItemHovered(ctx) then
                reaper.ImGui_BeginTooltip(ctx)
                reaper.ImGui_Text(ctx, toolbar.section)
                reaper.ImGui_EndTooltip(ctx)
            end
        end
        reaper.ImGui_EndPopup(ctx)
    end
    self:menuPopupEndFrame(ctx, POPUP_TOOLBAR_LIST)

    reaper.ImGui_SameLine(ctx)
    if current_toolbar and reaper.ImGui_Button(ctx, rename_label, row2_cell, 0) then
        local name_for_input = current_toolbar.custom_name or current_toolbar.name
        local retval, new_name = reaper.GetUserInputs("Rename Toolbar", 1, "New Name:,extrawidth=100", name_for_input)

        if retval then
            current_toolbar:updateName(new_name)
            CONFIG_MANAGER:saveToolbarConfig(current_toolbar)
        end
    elseif not current_toolbar then
        reaper.ImGui_BeginDisabled(ctx)
        reaper.ImGui_Button(ctx, rename_label, row2_cell, 0)
        reaper.ImGui_EndDisabled(ctx)
    end

    -- Toolbar management buttons
    if current_toolbar then
        reaper.ImGui_Spacing(ctx)

        local is_editing_mode = toggleEditingMode(nil, true)
        if reaper.ImGui_Button(ctx, "Edit Toolbars", row2_cell, 0) then
            toggleEditingMode(not is_editing_mode)
            reaper.ImGui_CloseCurrentPopup(ctx)
        end

        reaper.ImGui_SameLine(ctx)

        if reaper.ImGui_Button(ctx, "Edit Colors", row2_cell, 0) then
            toggleColorEditor(true)
        end

        reaper.ImGui_SameLine(ctx)

        if reaper.ImGui_Button(ctx, "Launch New Window", row2_cell, 0) then
            _G.CreateNewToolbar()
        end

        reaper.ImGui_SameLine(ctx)

        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0xFF4444FF) -- Red color
        if reaper.ImGui_Button(ctx, "Close Toolbar", row2_cell, 0) then
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

local UI_ANCHOR_OPTIONS = {
    { id = "tcp_corner", label = "TCP strip (left of ruler)" },
    { id = "arrange", label = "Arrange (below ruler)" },
    { id = "transport", label = "Transport bar" }
}

local UI_ALIGN_OPTIONS = {
    { id = "left", label = "Left" },
    { id = "center", label = "Center" },
    { id = "right", label = "Right" }
}

function GlobalSettingsMenu:renderUiPinSettings(ctx, toolbarController, saveCallback)
    reaper.ImGui_TextDisabled(ctx, "Pin to REAPER UI")
    reaper.ImGui_Spacing(ctx)

    local R = _G.REAPER_UI_ANCHOR
    local js_ok = R and R.is_available()
    if not js_ok then
        reaper.ImGui_TextWrapped(ctx, "Requires js_ReaScriptAPI (ReaPack) and an undocked toolbar. Regions use REAPER main-window child windows (track view / timeline / transport).")
    end

    local pin = toolbarController.ui_pin == true
    local pin_changed, pin_new = reaper.ImGui_Checkbox(ctx, "Pin to region##atb_ui_pin", pin)
    if pin_changed then
        toolbarController:setUiPinSettings(pin_new, toolbarController.ui_anchor, toolbarController.ui_anchor_align)
        saveCallback()
    end

    reaper.ImGui_Spacing(ctx)
    reaper.ImGui_AlignTextToFramePadding(ctx)
    reaper.ImGui_Text(ctx, "Region")
    reaper.ImGui_SameLine(ctx, 120)

    local cur_anchor = toolbarController.ui_anchor or "off"
    local anchor_label = cur_anchor == "off" and "(choose region)" or "TCP strip (left of ruler)"
    for _, opt in ipairs(UI_ANCHOR_OPTIONS) do
        if opt.id == cur_anchor then
            anchor_label = opt.label
            break
        end
    end
    if reaper.ImGui_Button(ctx, anchor_label .. "##atb_ui_anchor_btn", 280, 0) then
        self:menuPopupOpenAtMouse(ctx, POPUP_UI_ANCHOR)
    end

    self:menuPopupPrepareFrame(ctx, POPUP_UI_ANCHOR)
    if reaper.ImGui_BeginPopup(ctx, POPUP_UI_ANCHOR) then
        for _, opt in ipairs(UI_ANCHOR_OPTIONS) do
            if reaper.ImGui_MenuItem(ctx, opt.label, nil, cur_anchor == opt.id) then
                toolbarController:setUiPinSettings(toolbarController.ui_pin, opt.id, toolbarController.ui_anchor_align)
                saveCallback()
            end
        end
        reaper.ImGui_EndPopup(ctx)
    end
    self:menuPopupEndFrame(ctx, POPUP_UI_ANCHOR)

    reaper.ImGui_Spacing(ctx)
    reaper.ImGui_AlignTextToFramePadding(ctx)
    reaper.ImGui_Text(ctx, "If wider than buttons")
    reaper.ImGui_SameLine(ctx, 120)

    local cur_align = toolbarController.ui_anchor_align or "center"
    local align_label = cur_align
    for _, opt in ipairs(UI_ALIGN_OPTIONS) do
        if opt.id == cur_align then
            align_label = opt.label
            break
        end
    end
    if reaper.ImGui_Button(ctx, align_label .. "##atb_ui_align_btn", 160, 0) then
        self:menuPopupOpenAtMouse(ctx, POPUP_UI_ALIGN)
    end

    self:menuPopupPrepareFrame(ctx, POPUP_UI_ALIGN)
    if reaper.ImGui_BeginPopup(ctx, POPUP_UI_ALIGN) then
        for _, opt in ipairs(UI_ALIGN_OPTIONS) do
            if reaper.ImGui_MenuItem(ctx, opt.label, nil, cur_align == opt.id) then
                toolbarController:setUiPinSettings(toolbarController.ui_pin, toolbarController.ui_anchor, opt.id)
                saveCallback()
            end
        end
        reaper.ImGui_EndPopup(ctx)
    end
    self:menuPopupEndFrame(ctx, POPUP_UI_ALIGN)

    reaper.ImGui_Spacing(ctx)
    local tid = tostring(toolbarController.toolbar_id)
    self._pin_offset_text[tid] = self._pin_offset_text[tid]
        or {
            x = string.format("%g", toolbarController.ui_pin_offset_x or 0),
            y = string.format("%g", toolbarController.ui_pin_offset_y or 0)
        }
    local off_buf = self._pin_offset_text[tid]

    reaper.ImGui_AlignTextToFramePadding(ctx)
    reaper.ImGui_Text(ctx, "Horizontal offset")
    reaper.ImGui_SameLine(ctx, 120)
    reaper.ImGui_SetNextItemWidth(ctx, 120)
    do
        local hx, tx = reaper.ImGui_InputTextWithHint(ctx, "##atb_pin_off_x", "px, e.g. -2 or 8", off_buf.x)
        if hx then
            off_buf.x = tx or ""
            local trimmed = (off_buf.x:gsub("%s", ""))
            local v = tonumber(off_buf.x)
            if v ~= nil or trimmed == "" then
                toolbarController:setUiPinOffsets(v or 0, nil)
                saveCallback()
            end
        end
    end

    reaper.ImGui_Spacing(ctx)
    reaper.ImGui_AlignTextToFramePadding(ctx)
    reaper.ImGui_Text(ctx, "Vertical offset")
    reaper.ImGui_SameLine(ctx, 120)
    reaper.ImGui_SetNextItemWidth(ctx, 120)
    do
        local hy, ty = reaper.ImGui_InputTextWithHint(ctx, "##atb_pin_off_y", "px, e.g. -4 or 12", off_buf.y)
        if hy then
            off_buf.y = ty or ""
            local trimmed = (off_buf.y:gsub("%s", ""))
            local v = tonumber(off_buf.y)
            if v ~= nil or trimmed == "" then
                toolbarController:setUiPinOffsets(nil, v or 0)
                saveCallback()
            end
        end
    end

    reaper.ImGui_Spacing(ctx)
    reaper.ImGui_TextDisabled(ctx, "Offsets are screen pixels added to the anchor position (negative = left / up).")
    reaper.ImGui_Spacing(ctx)
    reaper.ImGui_TextDisabled(ctx, "Pinned: no ImGui docking, transparent chrome, width/position follow the region when HWND lookup succeeds. Must not be in a REAPER docker (negative dock). Changing pin options reloads this toolbar window.")
end

function GlobalSettingsMenu:renderSpecialWidgetsSettings(ctx, saveCallback)
    if not CONFIG.UI then
        return
    end
    reaper.ImGui_TextDisabled(ctx, "Special widgets run globally while Advanced Toolbars is open.")
    reaper.ImGui_Spacing(ctx)

    self:renderToolbarSwitchWidgetSetting(ctx, saveCallback)

    reaper.ImGui_Spacing(ctx)
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Spacing(ctx)

    local grid_on = CONFIG.UI.ENABLE_GRID_RULER_CHIP == true
    local g_changed, g_new =
        reaper.ImGui_Checkbox(ctx, "Grid chip on ruler (toggle grid lines)##atb_grid_ruler_chip", grid_on)
    if g_changed then
        CONFIG.UI.ENABLE_GRID_RULER_CHIP = g_new
        saveCallback()
    end
    local R = _G.REAPER_UI_ANCHOR
    if not (R and R.is_available()) then
        reaper.ImGui_TextWrapped(
            ctx,
            "Positioning the chip on the ruler needs js_ReaScriptAPI. Settings still save; the chip shows when window rects are available."
        )
    end
end

function GlobalSettingsMenu:renderToolbarVisualSettings(ctx, saveCallback)
    reaper.ImGui_Spacing(ctx)
    reaper.ImGui_Spacing(ctx)

    reaper.ImGui_TextDisabled(ctx, "Settings:")
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Spacing(ctx)

    local settings = {
        {
            label = "Button Height",
            control = reaper.ImGui_SliderInt,
            id = "##height",
            value = CONFIG.SIZES.HEIGHT,
            min = CONFIG.SIZES.MIN_HEIGHT,
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

    for i, setting in ipairs(settings) do
        if i == 6 then
            reaper.ImGui_SameLine(ctx, reaper.ImGui_GetWindowWidth(ctx) / 2 + 10)
            reaper.ImGui_BeginGroup(ctx)
        elseif i == 1 then
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
            if setting.in_icon_font then
                CONFIG.ICON_FONT[setting.config_key] = new_value
                if setting.config_key == "SIZE" then
                    self:invalidateButtonCache()
                end
            else
                CONFIG.SIZES[setting.config_key] = new_value
                if setting.config_key == "TEXT" then
                    self:invalidateButtonCache()
                end
            end
            saveCallback()
            if not setting.in_icon_font and setting.config_key == "HEIGHT" and C.IniManager and C.IniManager.reloadToolbarsNow then
                C.IniManager:reloadToolbarsNow()
            end
        end

        if i == 5 or i == #settings then
            reaper.ImGui_EndGroup(ctx)
        end
    end

    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Spacing(ctx)
    reaper.ImGui_Spacing(ctx)

    local toggle_options = {
        {label = "Visually Merge Grouped Buttons", config = "USE_GROUPING", parent = "UI"},
        {label = "Group Labels", config = "USE_GROUP_LABELS", parent = "UI"}
    }

    for _, option in ipairs(toggle_options) do
        if option.config then
            if reaper.ImGui_MenuItem(ctx, option.label, nil, CONFIG[option.parent][option.config]) then
                CONFIG[option.parent][option.config] = not CONFIG[option.parent][option.config]
                saveCallback()
            end
        else
            if reaper.ImGui_MenuItem(ctx, option.label) then
                option.action()
            end
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
    setCurrentToolbarIndex,
    toolbarController,
    skip_style_wrap)
    skip_style_wrap = skip_style_wrap or false
    local colorCount, styleCount = 0, 0
    if not skip_style_wrap then
        colorCount, styleCount = C.GlobalStyle.apply(ctx)
    end

    -- Render toolbar selector at the top
    self:renderToolbarSelector(ctx, toolbars, currentToolbarIndex, setCurrentToolbarIndex, toolbarController, toggleEditingMode, toggleColorEditor)

    reaper.ImGui_Spacing(ctx)
    reaper.ImGui_Spacing(ctx)

    if reaper.ImGui_BeginTabBar(ctx, "##atb_global_settings_tabs", 0) then
        if reaper.ImGui_BeginTabItem(ctx, "Visual##atb_gs_tab_visual") then
            self:renderToolbarVisualSettings(ctx, saveCallback)
            reaper.ImGui_EndTabItem(ctx)
        end
        if reaper.ImGui_BeginTabItem(ctx, "Pinning##atb_gs_tab_pin") then
            self:renderUiPinSettings(ctx, toolbarController, saveCallback)
            reaper.ImGui_EndTabItem(ctx)
        end
        if reaper.ImGui_BeginTabItem(ctx, "Special Widgets##atb_gs_tab_special") then
            self:renderSpecialWidgetsSettings(ctx, saveCallback)
            reaper.ImGui_EndTabItem(ctx)
        end
        reaper.ImGui_EndTabBar(ctx)
    end

    if not skip_style_wrap then
        C.GlobalStyle.reset(ctx, colorCount, styleCount)
    end
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

return GlobalSettingsMenu