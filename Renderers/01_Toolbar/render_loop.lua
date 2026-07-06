-- Renderers/01_Toolbar/render_loop.lua

function ToolbarWindow:render(ctx, font)
    if not self.toolbar_controller then
        return
    end

    self.toolbar_controller.ctx = ctx
    self.toolbar_controller:applyDockState(ctx)

    reaper.ImGui_PushFont(ctx, font, CONFIG.SIZES.TEXT)

    local pin_chrome = self.toolbar_controller:shouldUsePinnedChrome()
    local follow = self.toolbar_controller:shouldFollowUiAnchor()
    local ax, ay, aw, ah
    local R = _G.REAPER_UI_ANCHOR
    if follow and R then
        ax, ay, aw, ah = R.get_anchor_rect(self.toolbar_controller.ui_anchor, ctx)
    end
    local pin_layout_ok = follow and ax ~= nil and ay ~= nil and aw and ah and aw > 8 and ah > 8
    local pin_transport_fill = pin_layout_ok and self.toolbar_controller.ui_anchor == "transport"
    -- Transport bar fill needs exact size; tcp/arrange pins only lock position.
    local pin_size_locked = pin_transport_fill

    local off_x = tonumber(self.toolbar_controller.ui_pin_offset_x) or 0
    local off_y = tonumber(self.toolbar_controller.ui_pin_offset_y) or 0
    local pin_x = pin_layout_ok and (ax + off_x) or ax
    local pin_y = pin_layout_ok and (ay + off_y) or ay

    local pin_w, pin_h
    if pin_layout_ok then
        local fallback_min = (CONFIG.SIZES.HEIGHT or 38) + ((CONFIG.UI and CONFIG.UI.USE_GROUP_LABELS) and 24 or 0) + self:pinHeightPad()
        local min_pin_h = math.max(8, self._pin_content_min_h or fallback_min)
        pin_w = math.max(8, aw)
        pin_h = math.max(8, min_pin_h)
        reaper.ImGui_SetNextWindowPos(ctx, pin_x, pin_y, reaper.ImGui_Cond_Always())
        if pin_size_locked then
            reaper.ImGui_SetNextWindowSize(ctx, pin_w, pin_h, reaper.ImGui_Cond_Always())
            reaper.ImGui_SetNextWindowSizeConstraints(ctx, pin_w, pin_h, pin_w, pin_h)
        else
            reaper.ImGui_SetNextWindowSize(ctx, 800, pin_h, reaper.ImGui_Cond_FirstUseEver())
            reaper.ImGui_SetNextWindowSizeConstraints(ctx, 50, pin_h, 2000, 1000)
        end
        if reaper.ImGui_SetNextWindowBgAlpha and not pin_transport_fill then
            pcall(function()
                reaper.ImGui_SetNextWindowBgAlpha(ctx, 0)
            end)
        end
    end

    -- Opaque colors on the shared stack so other ImGui windows (dropdowns, editors) stay solid.
    -- Pinned toolbars use NoBackground + SetNextWindowBgAlpha(0), except transport anchor (theme bar).
    local opaque_bg = CONFIG_MANAGER:color("WINDOW_BG")
    local window_bg_push = (pin_transport_fill and self:themeTransportBackgroundImgui()) or opaque_bg

    local styles = {
        {reaper.ImGui_Col_WindowBg(), window_bg_push},
        {reaper.ImGui_Col_PopupBg(), opaque_bg},
        {reaper.ImGui_Col_SliderGrab(), 0x888888FF},
        {reaper.ImGui_Col_SliderGrabActive(), 0xAAAAAAFF},
        {reaper.ImGui_Col_FrameBg(), 0x555555FF}
    }

    for _, style in ipairs(styles) do
        reaper.ImGui_PushStyleColor(ctx, style[1], style[2])
    end

    -- Vertical toolbar column mode from cached window shape; UI-anchor pin always uses horizontal rows
    local is_vertical = not self.toolbar_controller:shouldFollowUiAnchor()
        and self.last_window_width > 0
        and self.last_window_height > 0
        and self.last_window_width < self.last_window_height

    if not pin_layout_ok then
        self._pin_content_min_h = nil
        reaper.ImGui_SetNextWindowSize(ctx, 800, 60, reaper.ImGui_Cond_FirstUseEver())
        -- Reduce max size constraints to prevent windows from being too large and creating invisible clickable areas
        -- Use reasonable maximums: 2000px width, 1000px height (instead of 10000x10000)
        local min_height = 60
        local min_width = 50
        if self.toolbar_controller then
            local rc = self.toolbar_controller:getRowCount()
            if not is_vertical then
                min_height = math.max(60, rc * ((CONFIG.SIZES and CONFIG.SIZES.HEIGHT or 38) + self:pinHeightPad()))
            else
                min_width = math.max(50, rc * (CONFIG.SIZES and CONFIG.SIZES.MIN_WIDTH or 30))
            end
        end
        reaper.ImGui_SetNextWindowSizeConstraints(ctx, min_width, min_height, 2000, 1000)
    end

    local window_flags =
        reaper.ImGui_WindowFlags_NoTitleBar() |
        reaper.ImGui_WindowFlags_NoCollapse() |
        reaper.ImGui_WindowFlags_NoFocusOnAppearing()
    if pin_chrome and reaper.ImGui_WindowFlags_NoDocking then
        window_flags = window_flags | reaper.ImGui_WindowFlags_NoDocking()
    end
    if pin_chrome and reaper.ImGui_WindowFlags_NoSavedSettings then
        window_flags = window_flags | reaper.ImGui_WindowFlags_NoSavedSettings()
    end
    if pin_layout_ok and pin_size_locked and reaper.ImGui_WindowFlags_NoResize then
        window_flags = window_flags | reaper.ImGui_WindowFlags_NoResize()
    end
    -- Locked to anchor when rect exists; still disallow dragging whenever pin mode is on (incl. rect lookup lag)
    if pin_chrome and reaper.ImGui_WindowFlags_NoMove then
        window_flags = window_flags | reaper.ImGui_WindowFlags_NoMove()
    end
    if pin_chrome and reaper.ImGui_WindowFlags_NoBackground and not pin_transport_fill then
        window_flags = window_flags | reaper.ImGui_WindowFlags_NoBackground()
    end

    window_flags = window_flags | reaper.ImGui_WindowFlags_NoScrollbar()
    if not is_vertical and reaper.ImGui_WindowFlags_NoScrollWithMouse then
        -- Horizontal: block wheel vertical scroll (row children forward wheel to parent)
        window_flags = window_flags | reaper.ImGui_WindowFlags_NoScrollWithMouse()
    end

    -- Use unique window name for each toolbar to prevent conflicts
    local window_name = "Dynamic Toolbar##" .. (self.toolbar_controller.toolbar_id or "default")
    local visible, open = reaper.ImGui_Begin(ctx, window_name, true, window_flags)
    self.toolbar_controller.is_open = open
    if not pin_layout_ok then
        UTILS.snapWindowToMinimum(ctx, 0, 0, true)
    end

    if visible then
        if not is_vertical then
            UTILS.clampVerticalScroll(ctx)
        end
        if pin_layout_ok then
            reaper.ImGui_SetWindowPos(ctx, pin_x, pin_y, reaper.ImGui_Cond_Always())
            if pin_size_locked and pin_w and pin_h then
                reaper.ImGui_SetWindowSize(ctx, pin_w, pin_h, reaper.ImGui_Cond_Always())
            end
        end
        -- Cache window dimensions for next frame
        self.last_window_width = reaper.ImGui_GetWindowWidth(ctx)
        self.last_window_height = reaper.ImGui_GetWindowHeight(ctx)
        if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) then
            if C.DragDropManager and C.DragDropManager:isDragging() then
                C.DragDropManager:endDrag()
            elseif _G.POPUP_OPEN then
                if C.PopupContext then
                    C.PopupContext.closeAllAuxiliaryWindows({
                        include_insert_menu = true,
                        include_action_search = true,
                        focus_arrange = true,
                        clear_popup_flag = true,
                    })
                end
            elseif self.toolbar_controller.button_editing_mode then
                self.toolbar_controller:toggleEditingMode(false)
                UTILS.focusArrangeWindow(true)
            end
        end

        local hover_flags = reaper.ImGui_HoveredFlags_ChildWindows and reaper.ImGui_HoveredFlags_ChildWindows() or 0
        if reaper.ImGui_IsWindowHovered(ctx, hover_flags) and not reaper.ImGui_IsAnyItemHovered(ctx) then
            if reaper.ImGui_IsMouseClicked(ctx, 0) then
                -- fc84a7c refocus stole focus from open popups (settings drag on empty area).
                local popup_blocks_focus = _G.POPUP_OPEN
                if reaper.ImGui_IsPopupOpen and reaper.ImGui_PopupFlags_AnyPopupId then
                    popup_blocks_focus = popup_blocks_focus
                        or reaper.ImGui_IsPopupOpen(ctx, "", reaper.ImGui_PopupFlags_AnyPopupId())
                end
                if not popup_blocks_focus then
                    reaper.SetCursorContext(1)
                end
            elseif reaper.ImGui_IsMouseClicked(ctx, 1) then
                reaper.ImGui_OpenPopup(ctx, "toolbar_settings_menu")
            end
        end

        local popup_open = false
        local toolbars = self.toolbar_controller.toolbars

        -- Pinned chrome (zero padding / flat border) applies only while drawing the main toolbar
        -- body, not during BeginPopup/Begin for settings, dropdowns, or other sub-windows.
        local function pushPinChromeStyleVars()
            local n = 0
            if pin_chrome and reaper.ImGui_StyleVar_WindowBorderSize and reaper.ImGui_StyleVar_WindowRounding then
                reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowBorderSize(), 0)
                reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowRounding(), 0)
                n = 2
                -- Match REAPER region width: default window padding shrinks the content region vs outer size
                if pin_layout_ok and reaper.ImGui_StyleVar_WindowPadding then
                    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding(), 0, 0)
                    n = n + 1
                end
            end
            return n
        end



        if toolbars and #toolbars > 0 then
            local pin_inner_style_vars = pushPinChromeStyleVars()
            popup_open = self:renderToolbarContent(ctx) or popup_open
            if pin_inner_style_vars > 0 then
                reaper.ImGui_PopStyleVar(ctx, pin_inner_style_vars)
            end
            if C.Interactions and C.Interactions:takeOpenToolbarSettingsDeferred(ctx) then
                reaper.ImGui_OpenPopup(ctx, "toolbar_settings_menu")
            end
            popup_open = reaper.ImGui_IsPopupOpen(ctx, "toolbar_settings_menu") or popup_open
            self:renderToolbarSettings(ctx)
            popup_open = reaper.ImGui_IsPopupOpen(ctx, "toolbar_settings_menu") or popup_open
        else
            local pin_inner_style_vars = pushPinChromeStyleVars()
            reaper.ImGui_Text(ctx, "No toolbars found in reaper-menu.ini")
            if pin_inner_style_vars > 0 then
                reaper.ImGui_PopStyleVar(ctx, pin_inner_style_vars)
            end
        end

        popup_open = self:renderUIElements(ctx, popup_open)

        local is_mouse_down = reaper.ImGui_IsMouseDown(ctx, 0) or reaper.ImGui_IsMouseDown(ctx, 1)
        self.was_mouse_down = is_mouse_down
        self.is_mouse_down = is_mouse_down

        if not is_vertical then
            UTILS.clampVerticalScroll(ctx)
        end
    end

    pcall(reaper.ImGui_End, ctx)
    reaper.ImGui_PopStyleColor(ctx, #styles)
    reaper.ImGui_PopFont(ctx)
end
