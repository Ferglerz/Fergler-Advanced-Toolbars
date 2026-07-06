-- Renderers/01_Toolbar/drag_drop.lua

-- True when the pointer is past all groups on the main axis (horizontal: right of last group; vertical: below last).
function ToolbarWindow:isToolbarTrailingDropZone(
    layout,
    base_y,
    edit_mode_left_gutter,
    content_offset_x,
    content_offset_y,
    window_width,
    window_height,
    mouse_rel_x,
    mouse_rel_y
)
    if not layout or not layout.groups or #layout.groups < 1 then
        return false
    end
    edit_mode_left_gutter = edit_mode_left_gutter or 0
    content_offset_x = content_offset_x or 0
    content_offset_y = content_offset_y or 0
    base_y = base_y or 0
    local min_l, min_t, max_r, max_b = math.huge, math.huge, 0, 0
    for i, group_layout in ipairs(layout.groups) do
        local gx, gy = self:resolveGroupScreenPos(layout, i, edit_mode_left_gutter, window_width, window_height, base_y, content_offset_x, content_offset_y)
        min_l = math.min(min_l, gx)
        min_t = math.min(min_t, gy)
        max_r = math.max(max_r, gx + group_layout.width)
        max_b = math.max(max_b, gy + group_layout.height)
    end
    if layout.is_vertical then
        return mouse_rel_x >= min_l and mouse_rel_x <= max_r and mouse_rel_y > max_b
    end
    return mouse_rel_y >= min_t and mouse_rel_y <= max_b and mouse_rel_x > max_r
end

function ToolbarWindow:handleToolbarDragDrop(ctx, toolbar, editing_mode, coords, draw_list, layout, base_y, edit_mode_left_gutter, layout_source_toolbar, content_offset_x, content_offset_y)
    if not editing_mode or not C.DragDropManager:isDragging() then
        return
    end

    if toolbar and toolbar.is_toolbar_switch_widget then
        return
    end

    -- Screen-rect hit test (see Coordinates:isMouseOverWindow). Per-context ImGui_IsWindowHovered is
    -- unreliable when the drag started in another context, which broke cross-toolbar indicators and drops.
    if not coords:isMouseOverWindow() then
        return
    end
    
    edit_mode_left_gutter = edit_mode_left_gutter or 0
    layout_source_toolbar = layout_source_toolbar or toolbar
    content_offset_x = content_offset_x or 0
    content_offset_y = content_offset_y or 0

    if C.DragDropManager:isGroupDrag() then
        local payload = C.DragDropManager.drag_payload
        local src_section = payload and payload.source_toolbar
        local src_gi = payload and payload.source_group_index
        local mouse_screen_x, mouse_screen_y = COORDINATES.getMouseScreenForDrag(ctx)
        local mouse_rel_x, mouse_rel_y = coords:screenToRelative(mouse_screen_x, mouse_screen_y)
        local window_width = reaper.ImGui_GetWindowWidth(ctx)
        local window_height = reaper.ImGui_GetWindowHeight(ctx)
        -- Empty toolbar: use same placeholder landing zone as button drag (group branch would miss it)
        if (not toolbar.buttons or #toolbar.buttons == 0) and layout.groups[1] and layout.groups[1].buttons[1] and layout_source_toolbar.groups[1] and
            layout_source_toolbar.groups[1].buttons[1] and layout_source_toolbar.groups[1].buttons[1].is_empty_toolbar_placeholder then
            local g1 = layout.groups[1]
            local b1 = g1.buttons[1]
            local group_x, group_y = self:resolveGroupScreenPos(layout, 1, edit_mode_left_gutter, window_width, window_height, base_y, content_offset_x, content_offset_y)
            local rx = group_x + b1.x
            local ry = group_y + (b1.y or 0)
            if mouse_rel_x >= rx and mouse_rel_x <= rx + b1.width and mouse_rel_y >= ry and mouse_rel_y <= ry + b1.height then
                C.DragDropManager.empty_drop_toolbar = toolbar
                C.DragDropManager:markPotentialDropTarget()
                return
            end
        end
        for i, group_layout in ipairs(layout.groups) do
            if layout_source_toolbar.section == src_section and i == src_gi then
                -- skip dragged source group
            else
                local group_x = group_layout.x + edit_mode_left_gutter + content_offset_x
                local group_y = (layout.is_vertical and (group_layout.y or 0) or base_y) + content_offset_y
                group_x, group_y = self:layoutGroupOriginForSplit(layout, window_width, window_height, i, group_x, group_y)
                local gw = group_layout.width
                local gh = group_layout.height
                if mouse_rel_x >= group_x and mouse_rel_x <= group_x + gw and mouse_rel_y >= group_y and mouse_rel_y <= group_y + gh then
                    C.DragDropManager.drop_target_toolbar = toolbar
                    C.DragDropManager.drop_target_group_index = i
                    if layout.is_vertical then
                        local cy = group_y + gh / 2
                        C.DragDropManager.drop_position = mouse_rel_y > cy and "after" or "before"
                    else
                        local cx = group_x + gw / 2
                        C.DragDropManager.drop_position = mouse_rel_x > cx and "after" or "before"
                    end
                    C.DragDropManager:markPotentialDropTarget()
                    break
                end
            end
        end
        if not C.DragDropManager.drop_target_group_index and #layout.groups > 0 then
            if self:isToolbarTrailingDropZone(
                layout,
                base_y,
                edit_mode_left_gutter,
                content_offset_x,
                content_offset_y,
                window_width,
                window_height,
                mouse_rel_x,
                mouse_rel_y
            ) then
                C.DragDropManager.drop_target_toolbar = toolbar
                C.DragDropManager.drop_target_group_index = #layout.groups
                C.DragDropManager.drop_position = "after"
                C.DragDropManager:markPotentialDropTarget()
            end
        end
        return
    end
    
    local button_rects = {}
    
    C.LayoutManager:setContext(ctx)
    local window_width = reaper.ImGui_GetWindowWidth(ctx)
    local window_height = reaper.ImGui_GetWindowHeight(ctx)

    for i, group_layout in ipairs(layout.groups) do
        local group = layout_source_toolbar.groups[i]
        local group_x = group_layout.x + edit_mode_left_gutter + content_offset_x
        local group_y = (layout.is_vertical and (group_layout.y or 0) or base_y) + content_offset_y
        group_x, group_y = self:layoutGroupOriginForSplit(layout, window_width, window_height, i, group_x, group_y)
        for j, button_layout in ipairs(group_layout.buttons) do
            local button = group.buttons[j]
            if not button.is_separator then
                local button_rel_x = group_x + button_layout.x
                local button_rel_y = group_y + (button_layout.y or 0)
                
                button_rects[button.instance_id] = {
                    rel_x = button_rel_x,
                    rel_y = button_rel_y,
                    width = button_layout.width,
                    height = button_layout.height,
                    button = button
                }
            end
        end
    end
    
    -- Screen mouse must come from the drag source context (or main) so cross-toolbar drags hit-test correctly.
    local mouse_screen_x, mouse_screen_y = COORDINATES.getMouseScreenForDrag(ctx)
    local mouse_rel_x, mouse_rel_y = coords:screenToRelative(mouse_screen_x, mouse_screen_y)
    
    for instance_id, rect in pairs(button_rects) do
        if C.DragDropManager:getDragSource() and C.DragDropManager:getDragSource().instance_id == instance_id then
            -- Skip source button
        else
            if mouse_rel_x >= rect.rel_x and mouse_rel_x <= rect.rel_x + rect.width and
               mouse_rel_y >= rect.rel_y and mouse_rel_y <= rect.rel_y + rect.height then
                if rect.button.is_empty_toolbar_placeholder then
                    C.DragDropManager.empty_drop_toolbar = toolbar
                else
                    C.DragDropManager.current_drop_target = rect.button
                    if layout.is_vertical then
                        local button_center_y = rect.rel_y + rect.height / 2
                        C.DragDropManager.drop_position = mouse_rel_y > button_center_y and "after" or "before"
                    else
                        local button_center_x = rect.rel_x + rect.width / 2
                        C.DragDropManager.drop_position = mouse_rel_x > button_center_x and "after" or "before"
                    end
                end
                C.DragDropManager:markPotentialDropTarget()
                break
            end
        end
    end

    local src_btn = C.DragDropManager:getDragSource()
    if not C.DragDropManager.current_drop_target and not C.DragDropManager.empty_drop_toolbar and src_btn and not src_btn:isSeparator() and
        #layout.groups > 0 and (toolbar.buttons and #toolbar.buttons > 0) then
        if self:isToolbarTrailingDropZone(
            layout,
            base_y,
            edit_mode_left_gutter,
            content_offset_x,
            content_offset_y,
            window_width,
            window_height,
            mouse_rel_x,
            mouse_rel_y
        ) then
            C.DragDropManager.drop_trailing_new_group_toolbar = toolbar
            C.DragDropManager:markPotentialDropTarget()
        end
    end
end

function ToolbarWindow:refineDropPositionForDragGhost(ctx, coords, layout, layout_source_toolbar, toolbar, base_y, edit_mode_left_gutter, content_offset_x, content_offset_y)
    if not C.DragDropManager:isDragging() then
        return
    end
    if C.DragDropManager:isGroupDrag() then
        local tgt_gi = C.DragDropManager.drop_target_group_index
        if not tgt_gi or not layout.groups[tgt_gi] then
            return
        end
        local mouse_screen_x, mouse_screen_y = COORDINATES.getMouseScreenForDrag(ctx)
        local mouse_rel_x, mouse_rel_y = coords:screenToRelative(mouse_screen_x, mouse_screen_y)
        local window_width = reaper.ImGui_GetWindowWidth(ctx)
        local window_height = reaper.ImGui_GetWindowHeight(ctx)
        edit_mode_left_gutter = edit_mode_left_gutter or 0
        content_offset_x = content_offset_x or 0
        content_offset_y = content_offset_y or 0
        local group_layout = layout.groups[tgt_gi]
        local group_x = group_layout.x + edit_mode_left_gutter + content_offset_x
        local group_y = (layout.is_vertical and (group_layout.y or 0) or base_y) + content_offset_y
        group_x, group_y = self:layoutGroupOriginForSplit(layout, window_width, window_height, tgt_gi, group_x, group_y)
        local gw = group_layout.width
        local gh = group_layout.height
        if layout.is_vertical then
            local cy = group_y + gh / 2
            C.DragDropManager.drop_position = mouse_rel_y > cy and "after" or "before"
        else
            local cx = group_x + gw / 2
            C.DragDropManager.drop_position = mouse_rel_x > cx and "after" or "before"
        end
        return
    end
    local tgt = C.DragDropManager:getCurrentDropTarget()
    if not tgt or tgt.is_empty_toolbar_placeholder then
        return
    end
    local mouse_screen_x, mouse_screen_y = COORDINATES.getMouseScreenForDrag(ctx)
    local mouse_rel_x, mouse_rel_y = coords:screenToRelative(mouse_screen_x, mouse_screen_y)
    local window_width = reaper.ImGui_GetWindowWidth(ctx)
    local window_height = reaper.ImGui_GetWindowHeight(ctx)
    edit_mode_left_gutter = edit_mode_left_gutter or 0
    content_offset_x = content_offset_x or 0
    content_offset_y = content_offset_y or 0
    for i, group_layout in ipairs(layout.groups) do
        local group = layout_source_toolbar.groups[i]
        local group_x = group_layout.x + edit_mode_left_gutter + content_offset_x
        local group_y = (layout.is_vertical and (group_layout.y or 0) or base_y) + content_offset_y
        group_x, group_y = self:layoutGroupOriginForSplit(layout, window_width, window_height, i, group_x, group_y)
        for j, button_layout in ipairs(group_layout.buttons) do
            local button = group.buttons[j]
            if button.instance_id == tgt.instance_id then
                local rel_x = group_x + button_layout.x
                local rel_y = group_y + (button_layout.y or 0)
                if layout.is_vertical then
                    local cy = rel_y + button_layout.height / 2
                    C.DragDropManager.drop_position = mouse_rel_y > cy and "after" or "before"
                else
                    local cx = rel_x + button_layout.width / 2
                    C.DragDropManager.drop_position = mouse_rel_x > cx and "after" or "before"
                end
                return
            end
        end
    end
end
