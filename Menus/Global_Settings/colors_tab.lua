function GlobalSettingsMenu:renderColorsTab(ctx, saveCallback)
    require("Systems.Modules_Factory").ensureUiModules()
    if not C.GlobalColorEditor then
        reaper.ImGui_Text(ctx, "Color editor not available")
        return
    end
    C.GlobalColorEditor:renderInline(ctx, saveCallback)
end

