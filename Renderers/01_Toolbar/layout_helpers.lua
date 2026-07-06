-- Renderers/01_Toolbar/layout_helpers.lua

function ToolbarWindow:toolbarIsEmpty(toolbar)
    return not toolbar or not toolbar.buttons or #toolbar.buttons == 0
end

-- L/R or U/D split: last anchor is flush to window edge; with 2+ anchors, groups between first and last anchors shift as one centered block.
function ToolbarWindow:layoutGroupOriginForSplit(layout, window_width, window_height, group_index, gx, gy)
    if not layout.split_active or not layout.split_point or not layout.groups[layout.split_point] then
        return gx, gy
    end

    local S = layout.split_indices
    local sp = layout.split_point
    if not layout.is_vertical then
        if group_index >= sp then
            gx = window_width - layout.right_width + (gx - layout.groups[sp].x)
        elseif S and #S >= 2 and group_index >= S[1] and group_index < sp then
            gx = gx + (layout.split_center_offset_x or 0)
        end
    else
        local bottom_h = layout.bottom_height or 0
        if group_index >= sp then
            gy = window_height - bottom_h + (gy - layout.groups[sp].y)
        elseif S and #S >= 2 and group_index >= S[1] and group_index < sp then
            gy = gy + (layout.split_center_offset_y or 0)
        end
    end
    return gx, gy
end

function ToolbarWindow:resolveGroupScreenPos(layout, group_index, edit_mode_left_gutter, window_width, window_height, base_y, content_offset_x, content_offset_y)
    local group_layout = layout.groups[group_index]
    local group_x = group_layout.x + (edit_mode_left_gutter or 0) + (content_offset_x or 0)
    local group_y = (layout.is_vertical and (group_layout.y or 0) or (base_y or 0)) + (content_offset_y or 0)
    return self:layoutGroupOriginForSplit(layout, window_width, window_height or 0, group_index, group_x, group_y)
end

-- Relative rect for one button from layout (same math as GroupRenderer:renderGroup).
function ToolbarWindow:getGroupButtonRect(layout, group_index, button_index, centered_y, edit_mode_left_gutter, window_width, window_height, offset_x, offset_y)
    local group_layout = layout.groups[group_index]
    local button_layout = group_layout.buttons[button_index]
    edit_mode_left_gutter = edit_mode_left_gutter or 0
    offset_x = offset_x or 0
    offset_y = offset_y or 0
    local group_x, group_y = self:resolveGroupScreenPos(layout, group_index, edit_mode_left_gutter, window_width, window_height, centered_y, 0, 0)
    return {
        rel_x = group_x + button_layout.x + offset_x,
        rel_y = group_y + (button_layout.y or 0) + offset_y,
        width = button_layout.width,
        height = button_layout.height
    }
end

function ToolbarWindow:tagToolbarButtons(toolbar, controller_id, row_index)
    if not toolbar or not toolbar.groups then
        return
    end
    row_index = row_index or 0
    for _, group in ipairs(toolbar.groups) do
        for _, button in ipairs(group.buttons) do
            button.atb_controller_id = controller_id
            button.atb_row_index = row_index
            -- Layout runs before WidgetRenderer:renderWidget; tag the same fields draw will set so
            -- getLayoutWidth / saved state (e.g. toolbars_list, ftc_adaptive_grid) use the real button id.
            if button.widget then
                button.widget._atb_controller_id = controller_id
                button.widget._atb_row_index = row_index
                button.widget._button_instance_id = button.instance_id
            end
        end
    end
end
