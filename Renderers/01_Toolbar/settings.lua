-- Renderers/01_Toolbar/settings.lua

function ToolbarWindow:renderToolbarSettings(ctx)
    require("Systems.Modules_Factory").ensureUiModules()
    C.GlobalStyle.withGlobalStyle(ctx, function()
        if reaper.ImGui_IsPopupOpen(ctx, "toolbar_settings_menu") then
            reaper.ImGui_SetNextWindowSizeConstraints(ctx, 575, 0, 575, 1150)
        end
        if not reaper.ImGui_BeginPopup(ctx, "toolbar_settings_menu") then
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
