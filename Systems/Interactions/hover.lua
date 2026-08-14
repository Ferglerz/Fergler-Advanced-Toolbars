-- Systems/Interactions/hover.lua
-- Hover timers, tooltips, interaction area setup

local EDIT_MODE_DRAG_HINT_DELAY = 0.5

return function(Interactions, perCtx)
    function Interactions:setupInteractionArea(ctx, rel_x, rel_y, width, height, button_id, coords)
        if not button_id then
            button_id = "unknown_" .. tostring(rel_x) .. "_" .. tostring(rel_y)
        end

        local unique_id = button_id .. "_" .. tostring(math.floor(rel_x)) .. "_" .. tostring(math.floor(rel_y))

        reaper.ImGui_PushID(ctx, unique_id)
        reaper.ImGui_SetCursorPos(ctx, rel_x, rel_y)

        local clicked = reaper.ImGui_InvisibleButton(ctx, "##hit", width, height)
        local item_hovered = reaper.ImGui_IsItemHovered(ctx)
        local is_clicked = reaper.ImGui_IsItemActive(ctx)

        reaper.ImGui_PopID(ctx)

        local is_hovered = item_hovered
        if coords and not is_hovered and coords:mouseOverRelative(rel_x, rel_y, width, height) then
            local any_item = reaper.ImGui_IsAnyItemHovered and reaper.ImGui_IsAnyItemHovered(ctx)
            if not any_item then
                is_hovered = true
                if not clicked and reaper.ImGui_IsMouseClicked(ctx, 0) then
                    clicked = true
                end
                if not is_clicked and reaper.ImGui_IsMouseDown(ctx, 0) then
                    is_clicked = true
                end
            end
        end

        return clicked, is_hovered, is_clicked
    end

    function Interactions:determineStateKey(button)
        if button:isSeparator() then
            return "SEPARATOR"
        end

        if button.is_toggled then
            return "TOGGLED"
        elseif button.is_armed then
            return button.is_flashing and "ARMED_FLASH" or "ARMED"
        else
            return "NORMAL"
        end
    end

    function Interactions:determineMouseKey(is_hovered, is_clicked)
        if is_clicked then
            return "CLICKED"
        elseif is_hovered then
            return "HOVER"
        else
            return "NORMAL"
        end
    end

    function Interactions:showEditModeDragHintTooltip(ctx, hover_time)
        local fade_progress = math.min((hover_time - EDIT_MODE_DRAG_HINT_DELAY) / 0.25, 1)
        reaper.ImGui_BeginTooltip(ctx)
        reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_Alpha(), fade_progress)
        reaper.ImGui_Text(ctx, "Drag to move")
        reaper.ImGui_PopStyleVar(ctx)
        reaper.ImGui_EndTooltip(ctx)
    end

    function Interactions:handleHover(ctx, button, is_hovered, is_editing_mode)
        local ctx_state = perCtx(self, ctx)
        if not ctx_state then
            return 0
        end

        if button:isSeparator() and not is_editing_mode then
            button.is_hovered = false
        else
            button.is_hovered = is_hovered
        end
        button.is_right_clicked = is_hovered and reaper.ImGui_IsMouseClicked(ctx, 1)

        local hover_time = 0
        if is_hovered then
            if not ctx_state.hover_start_times[button.instance_id] then
                ctx_state.hover_start_times[button.instance_id] = reaper.ImGui_GetTime(ctx)
            end
            hover_time = reaper.ImGui_GetTime(ctx) - ctx_state.hover_start_times[button.instance_id]

            if is_editing_mode then
                if not button.is_empty_toolbar_placeholder and
                    not (C.DragDropManager and C.DragDropManager:isDragging()) and
                    hover_time > EDIT_MODE_DRAG_HINT_DELAY then
                    self:showEditModeDragHintTooltip(ctx, hover_time)
                end
            elseif hover_time > CONFIG.UI.HOVER_DELAY then
                self:showTooltip(ctx, button, hover_time)
            end
        else
            ctx_state.hover_start_times[button.instance_id] = nil
        end

        return hover_time
    end

    function Interactions:updateEditModeGroupLabelDragHint(ctx, hover_key, is_hovered)
        local ctx_state = perCtx(self, ctx)
        if not ctx_state then
            return
        end

        if not is_hovered then
            ctx_state.edit_mode_group_label_hover_times[hover_key] = nil
            return
        end
        if C.DragDropManager and C.DragDropManager:isDragging() then
            return
        end
        if not ctx_state.edit_mode_group_label_hover_times[hover_key] then
            ctx_state.edit_mode_group_label_hover_times[hover_key] = reaper.ImGui_GetTime(ctx)
        end
        local hover_time = reaper.ImGui_GetTime(ctx) - ctx_state.edit_mode_group_label_hover_times[hover_key]
        if hover_time > EDIT_MODE_DRAG_HINT_DELAY then
            self:showEditModeDragHintTooltip(ctx, hover_time)
        end
    end

    function Interactions:showTooltip(ctx, button, hover_time)
        if BUTTON_UTILS.shouldSuppressWidgetTooltip(button) then
            return
        end
        if button and button.widget then
            return
        end
        local fade_progress = math.min((hover_time - CONFIG.UI.HOVER_DELAY) / 0.5, 1)

        if button:isSeparator() then
            return
        end

        if BUTTON_UTILS.hasWidgetDescription(button) then
            reaper.ImGui_BeginTooltip(ctx)
            reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_Alpha(), fade_progress)
            reaper.ImGui_Text(ctx, button.widget.description)
            reaper.ImGui_PopStyleVar(ctx)
            reaper.ImGui_EndTooltip(ctx)
        else
            local command_id = C.ButtonManager:getCommandID(button.id)
            if command_id then
                if button._cached_tooltip_cmd ~= command_id then
                    button._cached_tooltip_action = reaper.CF_GetCommandText(0, command_id)
                    button._cached_tooltip_cmd = command_id
                end
            end
            local action_name = button._cached_tooltip_action

            if action_name and action_name ~= "" then
                reaper.ImGui_BeginTooltip(ctx)
                reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_Alpha(), fade_progress)
                reaper.ImGui_Text(ctx, action_name)
                reaper.ImGui_PopStyleVar(ctx)
                reaper.ImGui_EndTooltip(ctx)
            end
        end
    end
end
