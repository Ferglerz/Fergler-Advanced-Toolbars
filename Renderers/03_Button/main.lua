-- Renderers/03_Button/main.lua
-- Button render orchestration; loaded into ButtonRenderer by 03_Button.lua

function ButtonRenderer:renderButton(ctx, button, rel_x, rel_y, coords, draw_list, editing_mode, layout, render_options)
    render_options = render_options or {}
    local ghost_mode = render_options.ghost_mode
    local is_vertical = layout and layout.is_vertical

    if ghost_mode then
        if button:isSeparator() then
            return self:renderSeparator(ctx, button, rel_x, rel_y, layout.width, coords, draw_list, editing_mode, "SEPARATOR", "NORMAL", is_vertical, render_options)
        end
        return self:renderButtonContent(
            ctx,
            button,
            rel_x,
            rel_y,
            coords,
            draw_list,
            editing_mode,
            layout,
            is_vertical,
            "NORMAL",
            "NORMAL",
            false,
            false,
            false,
            true
        )
    end

    local hit_x, hit_y, hit_w, hit_h = BUTTON_UTILS.computeHitRect(button, layout, ctx, rel_x, rel_y, is_vertical)
    local clicked, is_hovered, is_clicked = false, false, false
    if not (editing_mode and self.active_insertion_control) then
        clicked, is_hovered, is_clicked =
            C.Interactions:setupInteractionArea(ctx, hit_x, hit_y, hit_w, hit_h, button.instance_id, coords)
    end

    if editing_mode then
        self:handleEditingMode(ctx, button, rel_x, rel_y, layout.width, coords, draw_list, is_hovered, is_clicked, is_vertical, layout.height, render_options)
    end

    self:handleButtonInteractions(ctx, button, clicked, is_hovered, is_clicked, editing_mode, rel_x, rel_y, layout, coords)

    if C.DragDropManager:shouldOmitDragSourceVisual(button) then
        return layout.width
    end

    if button:isSeparator() then
        local state_key = C.Interactions:determineStateKey(button)
        local mouse_key = "NORMAL"
        return self:renderSeparator(ctx, button, rel_x, rel_y, layout.width, coords, draw_list, editing_mode, state_key, mouse_key, is_vertical)
    end

    local state_key = C.Interactions:determineStateKey(button)
    local mouse_key = C.Interactions:determineMouseKey(is_hovered, is_clicked)

    local width = self:renderButtonContent(ctx, button, rel_x, rel_y, coords, draw_list, editing_mode, layout, is_vertical, state_key, mouse_key, clicked, is_hovered, is_clicked, false)

    button:markLayoutClean()
    return width
end
