-- Renderers/03_Button/edit_mode.lua
-- Edit mode chrome and insertion helpers

local KNOB_LAYOUT = require("Utils.Widget.knob_layout")

local EDIT_CHIP_INSET_H = 5
local EDIT_CHIP_INSET_V = 3
local EDIT_CHIP_ROUND = 3

function ButtonRenderer:copyColorProperties(source_button, target_button)
    C.ButtonDefinition.copyCustomColorProperties(source_button, target_button)
end

function ButtonRenderer:getInsertionColorSource(target_button, exclude_instance_id)
    if not target_button then
        return nil
    end

    local function allow(group_button)
        return group_button
            and group_button.instance_id ~= target_button.instance_id
            and (not exclude_instance_id or group_button.instance_id ~= exclude_instance_id)
            and not group_button:isSeparator()
    end

    local parent_group = target_button.parent_group
    if parent_group and parent_group.buttons then
        for _, group_button in ipairs(parent_group.buttons) do
            if allow(group_button) and BUTTON_UTILS.hasInheritedStyleSource(group_button) then
                return group_button
            end
        end

        for _, group_button in ipairs(parent_group.buttons) do
            if allow(group_button) then
                return group_button
            end
        end
    end

    return target_button
end

function ButtonRenderer:handleAddButton(target_button, position)
    position = position or "before"
    local new_button = C.ButtonDefinition.createNoopButton()
    new_button.parent_toolbar = target_button.parent_toolbar

    local source_button = self:getInsertionColorSource(target_button)

    if source_button then
        self:copyColorProperties(source_button, new_button)
    end

    if target_button.is_empty_toolbar_placeholder then
        C.IniManager:insertFirstButtonInSection(target_button.parent_toolbar.section, new_button)
        return
    end

    C.IniManager:insertButton(target_button, new_button, position)
end

function ButtonRenderer:handleAddSeparator(target_button, position)
    position = position or "before"
    local separator = C.ButtonDefinition.createButton("-1", "SEPARATOR")
    separator.parent_toolbar = target_button.parent_toolbar

    if target_button.is_empty_toolbar_placeholder then
        C.IniManager:insertFirstButtonInSection(target_button.parent_toolbar.section, separator)
        return
    end

    C.IniManager:insertButton(target_button, separator, position)
end

function ButtonRenderer:handleDeleteSeparator(separator_button)
    C.IniManager:deleteButton(separator_button)
end

function ButtonRenderer:renderEditMode(ctx, rel_x, rel_y, width, height, coords, draw_list, button_bg_color, button_text_color, button)
    local alt_down = reaper.ImGui_Mod_Alt and (reaper.ImGui_GetKeyMods(ctx) & reaper.ImGui_Mod_Alt()) ~= 0
    local label = alt_down and "Delete" or "Edit"
    local chip_bg_color, chip_text_color = COLOR_UTILS.widgetPillColors(
        button_text_color or 0xFFFFFFFF,
        button_bg_color or 0x000000FF,
        { filled = true }
    )
    if alt_down then
        chip_text_color = 0xD94B4BFF
    end

    local button_h = height or CONFIG.SIZES.HEIGHT
    local _, _, chip_w, chip_h = DRAWING.getTextChipMetrics(ctx, label, EDIT_CHIP_INSET_H, EDIT_CHIP_INSET_V)
    local chip_x = rel_x + (width - chip_w) / 2
    if button and BUTTON_UTILS.isKnobWidget(button.widget) then
        local widget = button.widget
        local area_x, area_w = KNOB_LAYOUT.text_area(
            rel_x,
            width,
            widget.slider_style,
            widget.knob_bg_direction,
            button_h,
            ctx
        )
        if area_w >= chip_w then
            chip_x = area_x + (area_w - chip_w) / 2
        end
    end
    local chip_y = rel_y + (button_h - chip_h) / 2

    DRAWING.drawTextChip(
        ctx,
        coords,
        draw_list,
        chip_x,
        chip_y,
        chip_w,
        chip_h,
        label,
        {
            bg_color = chip_bg_color,
            text_color = chip_text_color,
            rounding = EDIT_CHIP_ROUND
        }
    )
end

function ButtonRenderer:handleButtonInteractions(ctx, button, clicked, is_hovered, is_clicked, editing_mode, rel_x, rel_y, layout, coords)
    if editing_mode and self.active_insertion_control then
        C.Interactions:handleHover(ctx, button, false, editing_mode)
        return
    end

    C.Interactions:handleHover(ctx, button, is_hovered, editing_mode)

    if button.is_empty_toolbar_placeholder then
        if clicked and not C.DragDropManager:isDragging() then
            local new_button = C.ButtonDefinition.createNoopButton()
            new_button.parent_toolbar = button.parent_toolbar
            C.IniManager:insertFirstButtonInSection(button.parent_toolbar.section, new_button)
        end
        return
    end

    if button:isSeparator() then
        if is_hovered and reaper.ImGui_IsMouseClicked(ctx, 1) then
            reaper.ImGui_OpenPopup(ctx, "toolbar_settings_menu")
            if C.Interactions then
                C.Interactions:clearButtonSettings(ctx)
            end
        elseif clicked then
            reaper.SetCursorContext(1)
        end
        return
    end

    local key_mods = reaper.ImGui_GetKeyMods(ctx)
    local is_cmd_down = (key_mods & reaper.ImGui_Mod_Ctrl()) ~= 0
    if not is_cmd_down then
        if reaper.ImGui_Mod_Shortcut then
            is_cmd_down = (key_mods & reaper.ImGui_Mod_Shortcut()) ~= 0
        end
        if not is_cmd_down and reaper.ImGui_Mod_Super then
            is_cmd_down = (key_mods & reaper.ImGui_Mod_Super()) ~= 0
        end
    end

    local open_settings_menu = false
    if is_cmd_down and is_hovered then
        if reaper.ImGui_IsMouseClicked(ctx, 1) then
            open_settings_menu = true
        elseif reaper.ImGui_IsMouseReleased(ctx, 0) then
            local drag_delta_x, drag_delta_y = reaper.ImGui_GetMouseDragDelta(ctx, 0)
            local total_movement = math.sqrt(drag_delta_x * drag_delta_x + drag_delta_y * drag_delta_y)
            if total_movement < 5 then
                open_settings_menu = true
            end
        end
    end

    if open_settings_menu then
        C.Interactions:showButtonSettings(ctx, button, button.parent_group)
        return
    end

    if editing_mode then
        if is_hovered and reaper.ImGui_IsMouseReleased(ctx, 0) then
            local drag_delta_x, drag_delta_y = reaper.ImGui_GetMouseDragDelta(ctx, 0)
            local total_movement = math.sqrt(drag_delta_x * drag_delta_x + drag_delta_y * drag_delta_y)

            if total_movement < 5 then
                local alt_down = reaper.ImGui_Mod_Alt and (reaper.ImGui_GetKeyMods(ctx) & reaper.ImGui_Mod_Alt()) ~= 0
                if alt_down then
                    C.IniManager:deleteButton(button)
                    return
                end
                C.Interactions:showButtonSettings(ctx, button, button.parent_group)
            end
        end
    else
        if clicked and not BUTTON_UTILS.isWidgetSlider(button) and not BUTTON_UTILS.isWidgetDropdown(button)
            and not BUTTON_UTILS.isWidgetColourSwatch(button) then
            local executed = C.ButtonManager:executeButtonCommand(button)
            local cmdID = C.ButtonManager:getCommandID(button.id)
            if not executed or cmdID == 65535 or cmdID == 0 then
                reaper.SetCursorContext(1)
            end
        end
    end

    if BUTTON_UTILS.hasWidget(button) then
        if is_hovered and reaper.ImGui_IsMouseClicked(ctx, 1) then
            local sub_handled = false
            if not editing_mode and button.widget and button.widget.hitTestSubcontrols and rel_x and rel_y and coords then
                local render_width = layout and layout.width or button.widget.width
                local sub_hit = button.widget.hitTestSubcontrols(button.widget, ctx, coords, rel_x, rel_y, render_width, layout)
                if sub_hit and button.widget.onSubcontrolRightClick then
                    local ok, handled = pcall(button.widget.onSubcontrolRightClick, button.widget, sub_hit, button)
                    if ok and handled ~= false then
                        sub_handled = true
                    end
                end
            end

            if not sub_handled and not editing_mode and button.widget and button.widget.onRightClick then
                local ok, handled = pcall(button.widget.onRightClick, button.widget)
                if ok and handled ~= false then
                    sub_handled = true
                end
            end

            if not sub_handled then
                C.Interactions:showButtonSettings(ctx, button, button.parent_group)
            end
        end
    else
        C.Interactions:handleRightClick(ctx, button, is_hovered, editing_mode)
    end

    if button.is_right_clicked and reaper.ImGui_IsMouseReleased(ctx, 1) then
        button.is_right_clicked = false
    end
end
