-- Systems/Interactions/menus.lua
-- Right-click flows, dropdowns, button settings, icon selector

return function(Interactions, perCtx)
    function Interactions:showDropdownMenu(ctx, button, position)
        if not button then
            return false
        end

        if not button.dropdown_menu or #button.dropdown_menu == 0 then
            local is_widget_dropdown = (button.instance_id and button.instance_id:match("^widget_dropdown_")) or button.widget_ref ~= nil
            if is_widget_dropdown then
                self.dropdown_button = button
                self.dropdown_position = position
                if C.PopupContext then
                    C.PopupContext.open(C.ButtonDropdownMenu, ctx)
                else
                    C.ButtonDropdownMenu.is_open = true
                    C.ButtonDropdownMenu.owner_ctx = ctx
                end
                C.ButtonDropdownMenu.current_button = button
                C.ButtonDropdownMenu.current_position = position
                C.ButtonDropdownMenu.beginpopup_grace = 3
                _G.POPUP_OPEN = true
                reaper.ImGui_OpenPopup(ctx, "##dropdown_popup_" .. button.instance_id)
                return true
            end
            if C.ButtonDropdownEditor then
                if C.ButtonDropdownEditor.show then
                    C.ButtonDropdownEditor:show(button, ctx)
                else
                    C.ButtonDropdownEditor.is_open = true
                    C.ButtonDropdownEditor.current_button = button
                    C.ButtonDropdownEditor.owner_ctx = ctx
                end
                _G.POPUP_OPEN = true
                return true
            end
            return false
        end

        self.dropdown_button = button
        self.dropdown_position = position

        if C.PopupContext then
            C.PopupContext.open(C.ButtonDropdownMenu, ctx)
        else
            C.ButtonDropdownMenu.is_open = true
            C.ButtonDropdownMenu.owner_ctx = ctx
        end
        C.ButtonDropdownMenu.current_button = button
        C.ButtonDropdownMenu.current_position = position
        C.ButtonDropdownMenu.beginpopup_grace = 3
        _G.POPUP_OPEN = true

        reaper.ImGui_OpenPopup(ctx, "##dropdown_popup_" .. button.instance_id)

        return true
    end

    function Interactions:showButtonSettings(ctx, button, group)
        local ctx_state = perCtx(self, ctx)
        if not ctx_state then
            return false
        end
        ctx_state.button_settings_button = button
        ctx_state.button_settings_group = group
        ctx_state.needs_open_settings = true
        _G.POPUP_OPEN = true
        return true
    end

    function Interactions:consumeNeedsOpenSettings(ctx)
        local ctx_state = perCtx(self, ctx)
        if ctx_state and ctx_state.needs_open_settings then
            ctx_state.needs_open_settings = false
            return true
        end
        return false
    end

    function Interactions:getButtonSettings(ctx)
        local ctx_state = perCtx(self, ctx)
        if not ctx_state then
            return nil, nil
        end
        return ctx_state.button_settings_button, ctx_state.button_settings_group
    end

    function Interactions:clearButtonSettings(ctx)
        local ctx_state = perCtx(self, ctx)
        if not ctx_state then
            return
        end
        ctx_state.button_settings_button = nil
        ctx_state.button_settings_group = nil
    end

    function Interactions:showIconSelector(button, owner_ctx)
        require("Systems.Modules_Factory").ensureUiModules()
        if not C.IconSelector then
            return false
        end

        C.IconSelector:show(button, owner_ctx)
        _G.POPUP_OPEN = true
        return true
    end

    function Interactions:handleRightClick(ctx, button, is_hovered, editing_mode)
        if not is_hovered or not reaper.ImGui_IsMouseClicked(ctx, 1) then
            return false
        end

        local key_mods = reaper.ImGui_GetKeyMods(ctx)
        local is_cmd_down = (key_mods & reaper.ImGui_Mod_Ctrl()) ~= 0
        if not is_cmd_down then
            if reaper.ImGui_Mod_Shortcut then
                is_cmd_down = (key_mods & reaper.ImGui_Mod_Shortcut()) ~= 0
            end
            if not is_cmd_down and reaper.ImGui_Mod_Super then
                is_cmd_down = (key_mods & reaper.ImGui_Mod_Super()) ~= 0
            end
        end

        if button:isSeparator() then
            if is_cmd_down or editing_mode then
                self:showButtonSettings(ctx, button, button.parent_group)
                return true
            end
            return false
        end

        if is_cmd_down or editing_mode then
            self:showButtonSettings(ctx, button, button.parent_group)
            return true
        elseif button.right_click == "dropdown" then
            local x, y = reaper.ImGui_GetMousePos(ctx)
            self:showDropdownMenu(ctx, button, {x = x, y = y})
        elseif button.right_click == "launch" and button.right_click_action then
            self:executeRightClickAction(button)
        elseif button.right_click == "arm" and not BUTTON_UTILS.isWidgetSlider(button) then
            C.ButtonManager:toggleArmCommand(button)
        end

        return true
    end

    function Interactions:executeRightClickAction(button)
        if not button or not button.right_click_action or button.right_click_action == "" then
            return false
        end

        local cmdID = BUTTON_UTILS.resolveActionCommandId(button.right_click_action)

        if cmdID and cmdID ~= 0 then
            reaper.Main_OnCommand(cmdID, 0)
            if C.ButtonManager then
                C.ButtonManager:markCommandStateDirty(cmdID)
            end
            return true
        end

        return false
    end

    function Interactions:queueOpenToolbarSettings(ctx)
        local ctx_state = perCtx(self, ctx)
        if ctx_state then
            ctx_state.open_toolbar_settings_deferred = true
        end
    end

    function Interactions:takeOpenToolbarSettingsDeferred(ctx)
        local ctx_state = perCtx(self, ctx)
        if not ctx_state or not ctx_state.open_toolbar_settings_deferred then
            return false
        end
        ctx_state.open_toolbar_settings_deferred = false
        return true
    end
end
