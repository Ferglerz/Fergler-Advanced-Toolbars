function GroupRenderer:ensureGroupLabelDragState(group)
    CACHE_UTILS.ensureGroupCacheSubtable(group, "label_drag_state")
    local s = group.cache.label_drag_state
    if s.was_dragging_last_frame == nil then
        s.was_dragging_last_frame = false
    end
    if s.mouse_down_on_button == nil then
        s.mouse_down_on_button = false
    end
    return s
end

function GroupRenderer:handleGroupLabelDragDrop(ctx, group, toolbar_owner, is_hovered, display_label)
    local ds = self:ensureGroupLabelDragState(group)
    local mouse_dragging = reaper.ImGui_IsMouseDragging(ctx, 0)
    local mouse_down = reaper.ImGui_IsMouseDown(ctx, 0)
    if is_hovered and reaper.ImGui_IsMouseClicked(ctx, 0) then
        ds.mouse_down_on_button = true
    end
    if not mouse_down then
        ds.mouse_down_on_button = false
    end
    if BUTTON_UTILS.canStartDrag(ds, mouse_dragging) and toolbar_owner then
        C.DragDropManager:startGroupDrag(ctx, group, toolbar_owner, display_label)
    end
    ds.was_dragging_last_frame = mouse_dragging
end

function GroupRenderer:promptGroupRename(group, toolbar_owner)
    if not group or not toolbar_owner then
        return
    end
    local current_name = (group.group_label and group.group_label.text) or ""
    local ok, new_name = reaper.GetUserInputs("Group Name", 1, "Group Name:,extrawidth=100", current_name)
    if not ok then
        return
    end
    group.group_label = group.group_label or {}
    group.group_label.text = new_name or ""
    if CONFIG_MANAGER and CONFIG_MANAGER.requestSaveToolbarConfig then
        CONFIG_MANAGER:requestSaveToolbarConfig(toolbar_owner)
    end
end
