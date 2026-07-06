-- Renderers/01_Toolbar/placeholders.lua

function ToolbarWindow:buildPlaceholderShadowToolbar(currentToolbar, ph_group, ph_button)
    return {
        section = currentToolbar.section,
        name = currentToolbar.name,
        custom_name = currentToolbar.custom_name,
        groups = { ph_group },
        buttons = { ph_button },
        updateName = currentToolbar.updateName,
        addButton = currentToolbar.addButton
    }
end

function ToolbarWindow:renderEmptyDropHighlight(ctx, draw_list, coords, rect)
    local x1, y1 = coords:relativeToDrawList(rect.rel_x, rect.rel_y)
    local x2, y2 = coords:relativeToDrawList(rect.rel_x + rect.width, rect.rel_y + rect.height)
    reaper.ImGui_DrawList_AddRect(draw_list, x1, y1, x2, y2, 0x00FF00FF, 0, 0, 3)
end

function ToolbarWindow:calculateVerticalCenter(ctx, layout, editing_mode)
    if layout and layout.is_vertical then
        return (layout.padding_y or 0)
    end

    local window_height = reaper.ImGui_GetWindowHeight(ctx)
    local content_height = layout.height
    local center_y = (window_height - content_height) / 2
    local min_padding = self:toolbarEdgePad()
    return math.max(center_y, min_padding)
end
