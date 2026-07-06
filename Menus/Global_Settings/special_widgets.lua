function GlobalSettingsMenu:renderSpecialWidgetsSettings(ctx, saveCallback)
    if not CONFIG.UI then
        return
    end
    reaper.ImGui_TextDisabled(ctx, "Special widgets run globally while Advanced Toolbars is open.")
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

