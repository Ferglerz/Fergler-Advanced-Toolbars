-- Renderers/03_Button/drag_drop.lua
-- Button drag-drop in edit mode

function ButtonRenderer:ensureDragState(button, include_drag_start_time)
    CACHE_UTILS.ensureButtonCache(button)
    if not button.cache.drag_state then
        button.cache.drag_state = {
            was_dragging_last_frame = false,
            mouse_down_on_button = false
        }
        if include_drag_start_time then
            button.cache.drag_state.drag_start_time = nil
        end
    end
    return button.cache.drag_state
end

function ButtonRenderer:handleSeparatorDragDrop(ctx, button, is_hovered)
    local drag_cache = self:ensureDragState(button, true)
    local mouse_dragging = reaper.ImGui_IsMouseDragging(ctx, 0)
    local mouse_down = reaper.ImGui_IsMouseDown(ctx, 0)
    local current_time = reaper.ImGui_GetTime(ctx)

    if is_hovered and reaper.ImGui_IsMouseClicked(ctx, 0) then
        drag_cache.mouse_down_on_button = true
        drag_cache.drag_start_time = current_time
    end

    if not mouse_down then
        drag_cache.mouse_down_on_button = false
        drag_cache.drag_start_time = nil
    end

    if drag_cache.mouse_down_on_button and not drag_cache.was_dragging_last_frame and not C.DragDropManager:isDragging() then
        if BUTTON_UTILS.canStartSeparatorDrag(drag_cache, mouse_dragging, current_time) then
            C.DragDropManager:startDrag(ctx, button)
            drag_cache.drag_start_time = nil
        end
    end

    drag_cache.was_dragging_last_frame = mouse_dragging
end

function ButtonRenderer:handleButtonDragDrop(ctx, button, is_hovered)
    if button.is_empty_toolbar_placeholder then
        return
    end
    local drag_cache = self:ensureDragState(button, false)
    local mouse_dragging = reaper.ImGui_IsMouseDragging(ctx, 0)
    local mouse_down = reaper.ImGui_IsMouseDown(ctx, 0)

    if is_hovered and reaper.ImGui_IsMouseClicked(ctx, 0) then
        drag_cache.mouse_down_on_button = true
    end

    if not mouse_down then
        drag_cache.mouse_down_on_button = false
    end

    if BUTTON_UTILS.canStartDrag(drag_cache, mouse_dragging) then
        C.DragDropManager:startDrag(ctx, button)
    end

    drag_cache.was_dragging_last_frame = mouse_dragging
end

function ButtonRenderer:handleEditingMode(ctx, button, rel_x, rel_y, width, coords, draw_list, is_hovered, is_clicked, is_vertical, button_height, render_options)
    if button.is_empty_toolbar_placeholder then
        return
    end

    if self.active_insertion_control then
        return
    end

    if button:isSeparator() then
        self:handleSeparatorDragDrop(ctx, button, is_hovered)
    else
        self:handleButtonDragDrop(ctx, button, is_hovered)
    end
end
