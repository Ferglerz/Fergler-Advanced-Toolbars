-- Windows/icon_selector_header.lua
local IconSelectorHeader = {}

function IconSelectorHeader.render(ctx, selector, opts)
    local button = selector.current_button
    if not button then
        return
    end

    local fixed_w = opts.fixed_w or 720
    local applyDisplayText = opts.applyDisplayText
    local clearButtonIcons = opts.clearButtonIcons
    local refreshButtonIconLayout = opts.refreshButtonIconLayout

    local action_identifier = button.original_text or button.id or ""
    local kind = button:isSeparator() and "Separator" or "Action"
    local rename_hint = "Rename " .. kind .. ": " .. (action_identifier ~= "" and action_identifier or "—")

    local function content_w()
        return math.max(120, select(1, reaper.ImGui_GetContentRegionAvail(ctx)) or 0)
    end

    local sp = select(1, reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing())) or 8
    local avail = select(1, reaper.ImGui_GetContentRegionAvail(ctx)) or fixed_w
    local col_w = math.max(80, (avail - sp) / 2)

    reaper.ImGui_SetNextItemWidth(ctx, col_w)
    do
        local ch, nv =
            reaper.ImGui_InputTextWithHint(ctx, "##name_top", rename_hint, selector.name_top_buf or "")
        if ch then
            selector.name_top_buf = nv or ""
        end
    end
    reaper.ImGui_SameLine(ctx, 0, sp)
    reaper.ImGui_SetNextItemWidth(ctx, col_w)
    do
        local ch, nv =
            reaper.ImGui_InputTextWithHint(
                ctx,
                "##name_bottom",
                "Bottom line (optional)",
                selector.name_bottom_buf or ""
            )
        if ch then
            selector.name_bottom_buf = nv or ""
        end
    end

    reaper.ImGui_Spacing(ctx)
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Spacing(ctx)

    if reaper.ImGui_Button(ctx, "Choose Image Icon...") then
        local retval, icon_path = reaper.GetUserFileNameForRead("", "Select Icon File", "")
        if retval then
            icon_path = UTILS.normalizeSlashes(icon_path)
            local test_texture = reaper.ImGui_CreateImage(icon_path)
            if not test_texture then
                reaper.ShowMessageBox("Failed to load icon: " .. icon_path, "Error", 0)
            else
                applyDisplayText(selector)
                clearButtonIcons(button)
                button.icon_path = icon_path
                refreshButtonIconLayout(button)
                button:saveChanges()
            end
        end
    end
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, "Remove Icon") then
        applyDisplayText(selector)
        clearButtonIcons(button)
        refreshButtonIconLayout(button)
        button:saveChanges()
    end
    reaper.ImGui_SameLine(ctx)
    do
        local hide_changed, hide_new = reaper.ImGui_Checkbox(ctx, "Hide Name", button.hide_label)
        if hide_changed then
            button.hide_label = hide_new
            if button.clearLayoutCache then
                button:clearLayoutCache()
            else
                button:clearCache()
            end
            button:saveChanges()
        end
    end
    reaper.ImGui_Spacing(ctx)

    return content_w
end

return IconSelectorHeader
