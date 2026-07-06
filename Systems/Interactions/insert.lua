-- Systems/Interactions/insert.lua
-- Insert menu and under-mouse auto-arm notice

local function shouldShowUnderMouseAutoArmNotice()
    if not CONFIG or type(CONFIG.UI) ~= "table" then
        return true
    end
    if CONFIG.UI.SHOW_UNDER_MOUSE_CURSOR_AUTO_ARM_NOTICE == nil then
        return true
    end
    return CONFIG.UI.SHOW_UNDER_MOUSE_CURSOR_AUTO_ARM_NOTICE == true
end

return function(Interactions)
    function Interactions:openInsertMenu(ctx, button, opts)
        opts = opts or {}
        local position = opts.position == "after" and "after" or "before"
        if not button then
            return false
        end
        if button:isSeparator() and position ~= "after" then
            return false
        end
        self.insert_menu_button = button
        self.insert_menu_position = position
        self.insert_menu_owner_ctx = ctx
        self.insert_menu_popup_open = false
        self.insert_menu_beginpopup_grace = 3
        if self.resetPresetBrowserState then
            self:resetPresetBrowserState()
        end
        _G.POPUP_OPEN = true
        return true
    end

    function Interactions:queueUnderMouseAutoArmNotice()
        if not shouldShowUnderMouseAutoArmNotice() then
            return false
        end
        self.under_mouse_auto_arm_notice_pending = true
        return true
    end

    function Interactions:renderUnderMouseAutoArmNotice(ctx)
        if not shouldShowUnderMouseAutoArmNotice() then
            self.under_mouse_auto_arm_notice_pending = false
            return false
        end

        if self.under_mouse_auto_arm_notice_pending then
            reaper.ImGui_OpenPopup(ctx, "under_mouse_auto_arm_notice")
            self.under_mouse_auto_arm_notice_pending = false
        end

        local visible = reaper.ImGui_BeginPopupModal(ctx, "under_mouse_auto_arm_notice", nil)
        if not visible then
            return false
        end

        _G.POPUP_OPEN = true
        reaper.ImGui_TextWrapped(
            ctx,
            "Actions with \"under mouse cursor\" in the name automatically arm when left-clicked."
        )
        reaper.ImGui_Separator(ctx)

        if reaper.ImGui_Button(ctx, "Ok", 140, 0) then
            reaper.ImGui_CloseCurrentPopup(ctx)
        end
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_Button(ctx, "Ok, don't show again", 220, 0) then
            CONFIG.UI = CONFIG.UI or {}
            CONFIG.UI.SHOW_UNDER_MOUSE_CURSOR_AUTO_ARM_NOTICE = false
            CONFIG_MANAGER:requestSaveMainConfig()
            reaper.ImGui_CloseCurrentPopup(ctx)
        end

        reaper.ImGui_EndPopup(ctx)
        return true
    end

    function Interactions:renderInsertMenu(ctx)
        if not self.insert_menu_button then
            return false
        end
        if self.insert_menu_owner_ctx and ctx ~= self.insert_menu_owner_ctx then
            return true
        end

        _G.POPUP_OPEN = true
        local target = self.insert_menu_button
        local pos = self.insert_menu_position or "before"
        local popup_id = "insert_toolbar_item_" .. tostring(target.instance_id) .. (pos == "after" and "_after" or "")

        if not self.insert_menu_popup_open then
            reaper.ImGui_OpenPopup(ctx, popup_id)
            self.insert_menu_popup_open = true
        end

        C.GlobalStyle.withGlobalStyle(ctx, function()
            local visible = reaper.ImGui_BeginPopup(ctx, popup_id)

            if visible then
                local function closeInsertPopup()
                    reaper.ImGui_CloseCurrentPopup(ctx)
                    self.insert_menu_button = nil
                    self.insert_menu_owner_ctx = nil
                    self.insert_menu_popup_open = false
                    self.insert_menu_position = "before"
                end

                self.insert_menu_beginpopup_grace = 0
                local tb = target.parent_toolbar
                local flat = tb and tb.buttons
                local is_last_flat = flat and #flat > 0 and flat[#flat].instance_id == target.instance_id
                local separator_enabled = not (pos == "after" and is_last_flat)

                local search_mode = pos == "after" and "insert_after" or "insert_before"
                if C.ActionSearch and reaper.ImGui_MenuItem(ctx, "Button (choose action)…") then
                    C.ActionSearch:open({ mode = search_mode, insert_anchor = target, ctx = ctx })
                    closeInsertPopup()
                elseif reaper.ImGui_MenuItem(ctx, "Button") then
                    C.ButtonRenderer:handleAddButton(target, pos)
                    closeInsertPopup()
                elseif reaper.ImGui_MenuItem(ctx, "Separator", nil, false, separator_enabled) then
                    C.ButtonRenderer:handleAddSeparator(target, pos)
                    closeInsertPopup()
                elseif WIDGETS and reaper.ImGui_MenuItem(ctx, "Widget") then
                    require("Systems.Modules_Factory").ensureUiModules()
                    C.ButtonSettingsMenu:showWidgetSelector(
                        target,
                        {
                            insert_new_button = true,
                            target_button = target,
                            position = pos
                        }
                    )
                    closeInsertPopup()
                end

                reaper.ImGui_Separator(ctx)
                if reaper.ImGui_Button(ctx, "Open Preset Browser (WIP)...") then
                    self:ensurePresetBrowserLoaded()
                    self:openPresetBrowser(ctx, target)
                    closeInsertPopup()
                end
                reaper.ImGui_EndPopup(ctx)
            else
                if reaper.ImGui_IsPopupOpen(ctx, popup_id) then
                    self.insert_menu_beginpopup_grace = 0
                elseif (self.insert_menu_beginpopup_grace or 0) > 0 then
                    self.insert_menu_beginpopup_grace = self.insert_menu_beginpopup_grace - 1
                else
                    self.insert_menu_button = nil
                    self.insert_menu_owner_ctx = nil
                    self.insert_menu_popup_open = false
                    self.insert_menu_position = "before"
                end
            end
        end)
        return self.insert_menu_button ~= nil
    end
end
