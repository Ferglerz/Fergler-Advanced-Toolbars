function GlobalSettingsMenu:menuPopupOpenAtMouse(ctx, popup_id)
    self._menu_popup_anchors = self._menu_popup_anchors or {}
    self._menu_popup_pending = self._menu_popup_pending or {}
    self._menu_popup_grace = self._menu_popup_grace or {}
    local mx, my = reaper.ImGui_GetMousePos(ctx)
    self._menu_popup_anchors[popup_id] = { x = mx, y = my }
    self._menu_popup_pending[popup_id] = true
    self._menu_popup_grace[popup_id] = 3
end

function GlobalSettingsMenu:menuPopupPrepareFrame(ctx, popup_id)
    if self._menu_popup_pending and self._menu_popup_pending[popup_id] then
        reaper.ImGui_OpenPopup(ctx, popup_id)
    end
    local a = self._menu_popup_anchors and self._menu_popup_anchors[popup_id]
    if a then
        reaper.ImGui_SetNextWindowPos(ctx, a.x, a.y, reaper.ImGui_Cond_Always())
    end
end

function GlobalSettingsMenu:menuPopupEndFrame(ctx, popup_id, begin_visible)
    if begin_visible then
        if self._menu_popup_pending then
            self._menu_popup_pending[popup_id] = nil
        end
        if self._menu_popup_grace then
            self._menu_popup_grace[popup_id] = 0
        end
        return
    end
    if reaper.ImGui_IsPopupOpen(ctx, popup_id) then
        if self._menu_popup_grace then
            self._menu_popup_grace[popup_id] = 0
        end
        return
    end
    local grace = (self._menu_popup_grace and self._menu_popup_grace[popup_id]) or 0
    if grace > 0 then
        self._menu_popup_grace[popup_id] = grace - 1
        return
    end
    if self._menu_popup_pending then
        self._menu_popup_pending[popup_id] = nil
    end
    if self._menu_popup_anchors then
        self._menu_popup_anchors[popup_id] = nil
    end
end

function GlobalSettingsMenu:renderSettingsRow(ctx, label, fn, control_id, value, min, max, format)
    -- Align text and control on same line with consistent spacing
    reaper.ImGui_AlignTextToFramePadding(ctx)
    reaper.ImGui_Text(ctx, label)

    -- Set control width and position
    reaper.ImGui_SameLine(ctx, reaper.ImGui_GetWindowWidth(ctx) / 4 - 10)
    reaper.ImGui_SetNextItemWidth(ctx, 138)

    -- Call the control function with appropriate parameters
    return fn(ctx, control_id, value, min, max, format)
end

function GlobalSettingsMenu:render(
    ctx,
    saveCallback,
    toggleEditingMode,
    toolbars,
    currentToolbarIndex,
    setCurrentToolbarIndex,
    toolbarController,
    skip_style_wrap)
    skip_style_wrap = skip_style_wrap or false

    local function render_body()
        -- Render toolbar selector at the top
        self:renderToolbarSelector(ctx, toolbars, currentToolbarIndex, setCurrentToolbarIndex, toolbarController, toggleEditingMode)

        reaper.ImGui_Spacing(ctx)
        reaper.ImGui_Spacing(ctx)

        if reaper.ImGui_BeginTabBar(ctx, "##atb_global_settings_tabs", 0) then
            if reaper.ImGui_BeginTabItem(ctx, "This Toolbar##atb_gs_tab_this") then
                self:renderThisToolbarTab(ctx, toolbarController, saveCallback, toolbars, currentToolbarIndex, setCurrentToolbarIndex)
                reaper.ImGui_EndTabItem(ctx)
            end
            if reaper.ImGui_BeginTabItem(ctx, "Visual##atb_gs_tab_visual") then
                self:renderToolbarVisualSettings(ctx, saveCallback)
                reaper.ImGui_EndTabItem(ctx)
            end
            if reaper.ImGui_BeginTabItem(ctx, "Special Widgets##atb_gs_tab_special") then
                self:renderSpecialWidgetsSettings(ctx, saveCallback)
                reaper.ImGui_EndTabItem(ctx)
            end
            if reaper.ImGui_BeginTabItem(ctx, "Colors##atb_gs_tab_colors") then
                self:renderColorsTab(ctx, saveCallback)
                reaper.ImGui_EndTabItem(ctx)
            end
            reaper.ImGui_EndTabBar(ctx)
        end
    end

    if skip_style_wrap then
        render_body()
    else
        C.GlobalStyle.withGlobalStyle(ctx, render_body)
    end
end

function GlobalSettingsMenu:invalidateButtonCache()
    for _, controller_data in ipairs(_G.TOOLBAR_CONTROLLERS or {}) do
        local controller = controller_data and controller_data.controller
        if controller and controller.clearAllRowToolbarCaches then
            controller:clearAllRowToolbarCaches()
        end
    end
    if C.LayoutManager then
        C.LayoutManager:invalidateCache()
    end
end
