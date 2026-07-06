function GlobalSettingsMenu:renderUiPinSettings(ctx, toolbarController, saveCallback)
    reaper.ImGui_TextDisabled(ctx, "Pin to REAPER UI")
    reaper.ImGui_Spacing(ctx)

    local R = _G.REAPER_UI_ANCHOR
    local js_ok = R and R.is_available()
    if not js_ok then
        reaper.ImGui_TextWrapped(ctx, "Requires js_ReaScriptAPI (ReaPack) and an undocked toolbar. Regions use REAPER main-window child windows (track view / timeline / transport).")
    end

    local pin = toolbarController.ui_pin == true
    local pin_changed, pin_new = reaper.ImGui_Checkbox(ctx, "Pin to region##atb_ui_pin", pin)
    if pin_changed then
        toolbarController:setUiPinSettings(pin_new, toolbarController.ui_anchor, toolbarController.ui_anchor_align)
        saveCallback()
    end

    reaper.ImGui_SameLine(ctx)
    local cur_anchor = toolbarController.ui_anchor or "off"
    local anchor_label = cur_anchor == "off" and "(choose region)" or "TCP Menu Area (left of ruler)"
    for _, opt in ipairs(UI_ANCHOR_OPTIONS) do
        if opt.id == cur_anchor then
            anchor_label = opt.label
            break
        end
    end
    local anchor_btn_w = reaper.ImGui_GetContentRegionAvail(ctx)
    if reaper.ImGui_Button(ctx, anchor_label .. "##atb_ui_anchor_btn", anchor_btn_w, 0) then
        self:menuPopupOpenAtMouse(ctx, POPUP_UI_ANCHOR)
    end

    self:menuPopupPrepareFrame(ctx, POPUP_UI_ANCHOR)
    local anchor_popup_visible = reaper.ImGui_BeginPopup(ctx, POPUP_UI_ANCHOR)
    if anchor_popup_visible then
        for _, opt in ipairs(UI_ANCHOR_OPTIONS) do
            if reaper.ImGui_MenuItem(ctx, opt.label, nil, cur_anchor == opt.id) then
                toolbarController:setUiPinSettings(toolbarController.ui_pin, opt.id, toolbarController.ui_anchor_align)
                saveCallback()
            end
        end
        reaper.ImGui_EndPopup(ctx)
    end
    self:menuPopupEndFrame(ctx, POPUP_UI_ANCHOR, anchor_popup_visible)

    reaper.ImGui_Spacing(ctx)
    reaper.ImGui_AlignTextToFramePadding(ctx)
    reaper.ImGui_Text(ctx, "Justification")
    reaper.ImGui_SameLine(ctx, 120)

    local cur_align = toolbarController.ui_anchor_align or "center"
    local align_label = cur_align
    for _, opt in ipairs(UI_ALIGN_OPTIONS) do
        if opt.id == cur_align then
            align_label = opt.label
            break
        end
    end
    if reaper.ImGui_Button(ctx, align_label .. "##atb_ui_align_btn", 160, 0) then
        self:menuPopupOpenAtMouse(ctx, POPUP_UI_ALIGN)
    end

    self:menuPopupPrepareFrame(ctx, POPUP_UI_ALIGN)
    local align_popup_visible = reaper.ImGui_BeginPopup(ctx, POPUP_UI_ALIGN)
    if align_popup_visible then
        for _, opt in ipairs(UI_ALIGN_OPTIONS) do
            if reaper.ImGui_MenuItem(ctx, opt.label, nil, cur_align == opt.id) then
                toolbarController:setUiPinSettings(toolbarController.ui_pin, toolbarController.ui_anchor, opt.id)
                saveCallback()
            end
        end
        reaper.ImGui_EndPopup(ctx)
    end
    self:menuPopupEndFrame(ctx, POPUP_UI_ALIGN, align_popup_visible)

    reaper.ImGui_Spacing(ctx)
    local tid = tostring(toolbarController.toolbar_id)
    self._pin_offset_text[tid] = self._pin_offset_text[tid]
        or {
            x = string.format("%g", toolbarController.ui_pin_offset_x or 0),
            y = string.format("%g", toolbarController.ui_pin_offset_y or 0)
        }
    local off_buf = self._pin_offset_text[tid]

    local off_spacing_x = select(1, reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing()))
    local off_row_avail = reaper.ImGui_GetContentRegionAvail(ctx)
    local off_half_w = math.max(48, math.floor((off_row_avail - off_spacing_x) / 2))

    reaper.ImGui_SetNextItemWidth(ctx, off_half_w)
    do
        local hx, tx = reaper.ImGui_InputTextWithHint(ctx, "##atb_pin_off_x", "Horizontal offset (px)", off_buf.x)
        if hx then
            off_buf.x = tx or ""
            local trimmed = (off_buf.x:gsub("%s", ""))
            local v = tonumber(off_buf.x)
            if v ~= nil or trimmed == "" then
                toolbarController:setUiPinOffsets(v or 0, nil)
                saveCallback()
            end
        end
    end

    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_SetNextItemWidth(ctx, off_half_w)
    do
        local hy, ty = reaper.ImGui_InputTextWithHint(ctx, "##atb_pin_off_y", "Vertical offset (px)", off_buf.y)
        if hy then
            off_buf.y = ty or ""
            local trimmed = (off_buf.y:gsub("%s", ""))
            local v = tonumber(off_buf.y)
            if v ~= nil or trimmed == "" then
                toolbarController:setUiPinOffsets(nil, v or 0)
                saveCallback()
            end
        end
    end

    reaper.ImGui_Spacing(ctx)
    reaper.ImGui_TextDisabled(ctx, "Offsets are screen pixels added to the anchor position (negative = left / up).")
    reaper.ImGui_Spacing(ctx)
    reaper.ImGui_TextDisabled(ctx, "Pinned: no ImGui docking, transparent chrome, width/position follow the region when HWND lookup succeeds. Must not be in a REAPER docker (negative dock). Changing pin options reloads this toolbar window.")
end

