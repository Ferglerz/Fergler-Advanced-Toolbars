-- Renderers/01_Toolbar/settings.lua

function ToolbarWindow:renderToolbarSettings(ctx)
    if not reaper.ImGui_IsPopupOpen(ctx, "toolbar_settings_menu") then
        return
    end
    require("Systems.Modules_Factory").ensureUiModules()
    C.GlobalStyle.withGlobalStyle(ctx, function()
        reaper.ImGui_SetNextWindowSizeConstraints(ctx, 575, 0, 575, 1150)
        reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding(), 14, 12)
        local visible = reaper.ImGui_BeginPopup(ctx, "toolbar_settings_menu")
        reaper.ImGui_PopStyleVar(ctx)
        if not visible then
            return
        end

        C.GlobalSettingsMenu:render(
            ctx,
            function()
                CONFIG_MANAGER:requestSaveMainConfig()
                self.toolbar_controller:clearAllRowToolbarCaches()
                if C.LayoutManager then
                    C.LayoutManager:invalidateCache()
                end
            end,
            function(value, get_only)
                return self.toolbar_controller:toggleEditingMode(value, get_only)
            end,
            self.toolbar_controller.toolbars,
            self.toolbar_controller.currentToolbarIndex,
            function(index)
                self.toolbar_controller:setCurrentToolbarIndex(index)
            end,
            self.toolbar_controller,
            true
        )

        reaper.ImGui_EndPopup(ctx)
    end)
end
