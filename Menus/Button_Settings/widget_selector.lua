local PREVIEW = require("Menus.Button_Settings.widget_selector_preview")

function ButtonSettingsMenu:showWidgetSelector(button, owner_ctx_or_opts)
    local widget_list
    local list_ok, list_err = pcall(function()
        widget_list = C.WidgetsManager:getWidgetList()
    end)
    if not list_ok then
        reaper.ShowConsoleMsg("Advanced Toolbars: widget list failed: " .. tostring(list_err) .. "\n")
        reaper.ShowMessageBox(tostring(list_err), "Widget list error", 0)
        return
    end

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
        selected_index = (#widget_list > 0) and 1 or nil,
        is_open = true,
        preview_cache = {},
        preview_style_custom = button.custom_color and CONFIG_MANAGER:deepCopy(button.custom_color) or nil,
        preview_style_user = button.user_colors and CONFIG_MANAGER:deepCopy(button.user_colors) or nil,
        preview_style_border = button.border_offset
            and {
                saturation = tonumber(button.border_offset.saturation) or 0.0,
                value = tonumber(button.border_offset.value) or 0.0,
            }
            or nil,
        preview_button_shell = self._widget_preview_shell,
        insert_new_button = opts and opts.insert_new_button == true,
        target_button = opts and opts.target_button or button,
        insert_position = (opts and opts.position) or "before",
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

    self.show_widget_selector = true
end

function ButtonSettingsMenu:renderWidgetSelector(ctx)
    if C.PopupContext then
        if not C.PopupContext.shouldRender(self.widget_selection, ctx) then
            return false
        end
    elseif not self.widget_selection or not self.widget_selection.is_open then
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

    local sel = self.widget_selection
    local window_open = true
    local esc_pressed = false

    local function render_popup_body()
        local window_title = "Select Widget##" .. sel.button.instance_id
        local visible, open = reaper.ImGui_Begin(ctx, window_title, true, window_flags)
        UTILS.snapWindowToMinimum(ctx, 0, 0, true)
        esc_pressed = reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape())
        window_open = open

        if not visible then
            reaper.ImGui_End(ctx)
            return
        end

        local function persistToolbarAndReload(toolbar)
            if not toolbar then
                return false
            end
            CONFIG_MANAGER:saveToolbarConfig(toolbar)
            C.IniManager:reloadToolbarsNow()
            return true
        end

        local function closeSelector()
            if C.PopupContext then
                C.PopupContext.close(sel)
            else
                sel.is_open = false
            end
        end

        local function applySelectedWidget()
            local idx = sel.selected_index
            if type(idx) ~= "number" or idx < 1 or idx > #sel.widget_list then
                return
            end
            local w = sel.widget_list[idx]
            if not w then
                return
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

                if C.WidgetsManager:assignWidgetToButton(inserted, w.name, { skip_save = true }) then
                    inserted:clearCache()
                    persistToolbarAndReload(inserted.parent_toolbar)
                    closeSelector()
                else
                    reaper.ShowMessageBox("Failed to assign widget to new button", "Error", 0)
                end
                return
            end

            if C.WidgetsManager:assignWidgetToButton(sel.button, w.name, { skip_save = true }) then
                sel.button:clearCache()
                persistToolbarAndReload(sel.button.parent_toolbar)
                closeSelector()
            else
                reaper.ShowMessageBox("Failed to assign widget to button", "Error", 0)
            end
        end

        local intro = sel.insert_new_button
            and "Select a widget for the new button. Preview uses the target button's colors."
            or "Preview uses this button's colors. Double-click a tile or select one and click OK to assign."
        reaper.ImGui_TextWrapped(ctx, intro)
        reaper.ImGui_Separator(ctx)

        local avail_w, avail_h = reaper.ImGui_GetContentRegionAvail(ctx)
        local grid_layout = PREVIEW.compute_grid_layout(ctx, avail_w)
        local footer_reserved_h = 164
        local list_start_y = reaper.ImGui_GetCursorPosY(ctx)
        local scroll_h = math.max(120, (avail_h or 0) - footer_reserved_h)
        local shell = sel.preview_button_shell or self._widget_preview_shell

        local hovered_widget, selected_widget = PREVIEW.render_grid(ctx, sel, shell, grid_layout, scroll_h, applySelectedWidget)

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

        local sp_y = select(2, reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing())) or 0
        local fp_y = select(2, reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding())) or 0
        local button_h = reaper.ImGui_GetTextLineHeight(ctx) + (fp_y * 2)
        local buttons_y = footer_start_y + footer_reserved_h - button_h - (button_h + sp_y)
        reaper.ImGui_SetCursorPosY(ctx, buttons_y)

        local launch_w = reaper.ImGui_GetWindowWidth(ctx) - 20
        if reaper.ImGui_Button(ctx, "Launch Test Toolbar (all widgets)...", launch_w, 0) then
            if _G.CreateTempWidgetGalleryToolbar then
                _G.CreateTempWidgetGalleryToolbar()
            end
        end

        reaper.ImGui_SetCursorPosY(ctx, buttons_y + button_h + sp_y)

        local btn_width = (reaper.ImGui_GetWindowWidth(ctx) - 20) / 2
        if reaper.ImGui_Button(ctx, "OK", btn_width, 0) then
            applySelectedWidget()
        end

        reaper.ImGui_SameLine(ctx, 0, grid_layout.sp_x)
        if reaper.ImGui_Button(ctx, "Cancel", btn_width, 0) then
            closeSelector()
        end

        reaper.ImGui_End(ctx)
    end

    C.GlobalStyle.withGlobalStyle(ctx, render_popup_body)

    if not window_open or esc_pressed then
        if C.PopupContext then
            C.PopupContext.close(sel)
        else
            sel.is_open = false
        end
    end

    return sel.is_open
end

return ButtonSettingsMenu
