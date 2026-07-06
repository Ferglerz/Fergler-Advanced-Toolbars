function GroupRenderer:createGroupParams(ctx, group, pos_x, pos_y, coords, draw_list, editing_mode, layout, toolbar_layout, group_index, toolbar_owner)
    local is_vertical = toolbar_layout and toolbar_layout.is_vertical
    return {
        ctx = ctx,
        group = group,
        position = {x = pos_x, y = pos_y},
        coords = coords,
        draw_list = draw_list,
        editing_mode = editing_mode,
        layout = layout,
        toolbar_layout = toolbar_layout,
        is_vertical = is_vertical,
        has_visible_label = is_vertical and BUTTON_UTILS.shouldShowGroupLabelRow(editing_mode, group),
        group_index = group_index,
        toolbar_owner = toolbar_owner
    }
end

function GroupRenderer:renderGroup(ctx, group, pos_x, pos_y, coords, draw_list, editing_mode, layout, toolbar_layout, group_index, toolbar_owner)
    local params = self:createGroupParams(
        ctx,
        group,
        pos_x,
        pos_y,
        coords,
        draw_list,
        editing_mode,
        layout,
        toolbar_layout,
        group_index,
        toolbar_owner
    )
    return self:renderGroupWithParams(params)
end
