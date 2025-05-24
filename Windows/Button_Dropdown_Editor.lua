-- Windows/Button_Dropdown_Editor.lua

local ButtonDropdownEditor = {}
ButtonDropdownEditor.__index = ButtonDropdownEditor

function ButtonDropdownEditor.new()
    local self = setmetatable({}, ButtonDropdownEditor)
    
    self.is_open = false
    self.current_button = nil
    
    return self
end

function ButtonDropdownEditor:renderDropdownEditor(ctx, button)
    if not self.is_open then
        _G.POPUP_OPEN = false
        return false
    end
    
    _G.POPUP_OPEN = true
    
    button = button or self.current_button
    if not button then return false end

    local window_flags =
        reaper.ImGui_WindowFlags_NoCollapse() | reaper.ImGui_WindowFlags_AlwaysAutoResize() |
        reaper.ImGui_WindowFlags_NoDocking()
    local colorCount, styleCount = C.GlobalStyle.apply(ctx)
    
    -- Use instance_id for unique window identification
    local window_title = "Dropdown Editor - " .. UTILS.stripNewLines(button.display_text) .. "##" .. button.instance_id
    local visible, open = reaper.ImGui_Begin(ctx, window_title, true, window_flags)
    
    self.is_open = open

    if visible then
        if not button.dropdown_menu then
            button.dropdown_menu = {}
        end

        if reaper.ImGui_Button(ctx, "Add Item") then
            table.insert(button.dropdown_menu, {name = "New Item", action_id = ""})
            CONFIG_MANAGER:saveToolbarConfig(button.parent_toolbar)
        end

        reaper.ImGui_SameLine(ctx)

        if reaper.ImGui_Button(ctx, "Add Separator") then
            table.insert(button.dropdown_menu, {is_separator = true})
            CONFIG_MANAGER:saveToolbarConfig(button.parent_toolbar)
        end

        reaper.ImGui_Separator(ctx)

        if #button.dropdown_menu == 0 then
            reaper.ImGui_TextDisabled(ctx, "No items in dropdown")
        else
            local to_delete, move_up, move_down
            local dropdown_copy = {table.unpack(button.dropdown_menu)}
            
            local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
            local triangle_height = 10
            local triangle_width = 8
            local button_size = 20

            local function drawTriangle(i, is_up, enabled)
                local triangle_color = enabled and (reaper.ImGui_IsItemHovered(ctx) or reaper.ImGui_IsItemActive(ctx)) 
                    and 0xFFFFFFFF or 0xAAAAAAFF
                
                if not enabled then triangle_color = 0x44444477 end
                
                reaper.ImGui_SetCursorPos(ctx, reaper.ImGui_GetCursorPosX(ctx), reaper.ImGui_GetCursorPosY(ctx))
                
                -- Use instance_id for unique button identification
                local button_id = "##" .. (is_up and "up" or "down") .. i .. "_" .. button.instance_id
                local button_pressed = enabled and reaper.ImGui_InvisibleButton(ctx, button_id, button_size, button_size)
                if not enabled then
                    local disabled_id = "##" .. (is_up and "up" or "down") .. "_disabled" .. i .. "_" .. button.instance_id
                    reaper.ImGui_InvisibleButton(ctx, disabled_id, button_size, button_size)
                end
                
                local pos_x, pos_y = reaper.ImGui_GetItemRectMin(ctx)
                local center_x = pos_x + button_size / 2
                local center_y = pos_y + button_size / 2
                
                center_y = center_y + (is_up and triangle_height/4 or -triangle_height/4)
                
                DRAWING.triangle(
                    draw_list,
                    center_x,
                    center_y,
                    triangle_width,
                    triangle_height,
                    triangle_color,
                    is_up and DRAWING.ANGLE_UP or DRAWING.ANGLE_DOWN
                )
                
                if enabled and reaper.ImGui_IsItemHovered(ctx) then
                    reaper.ImGui_BeginTooltip(ctx)
                    reaper.ImGui_Text(ctx, is_up and "Move Up" or "Move Down")
                    reaper.ImGui_EndTooltip(ctx)
                end
                
                return button_pressed
            end

            for i, item in ipairs(dropdown_copy) do
                -- Use instance_id for unique item identification
                reaper.ImGui_PushID(ctx, i .. "_" .. button.instance_id)

                if drawTriangle(i, true, i > 1) then move_up = i end
                reaper.ImGui_SameLine(ctx)
                if drawTriangle(i, false, i < #button.dropdown_menu) then move_down = i end
                reaper.ImGui_SameLine(ctx)

                if item.is_separator then
                    reaper.ImGui_Text(ctx, "--- Separator ---")
                else
                    reaper.ImGui_SetNextItemWidth(ctx, 150)
                    local name_changed, new_name =
                        reaper.ImGui_InputTextWithHint(ctx, "##name" .. i, "Action Name", item.name or "")
                    if name_changed then
                        item.name = new_name
                        button.dropdown_menu[i].name = new_name
                    end

                    reaper.ImGui_SameLine(ctx)
                    reaper.ImGui_SetNextItemWidth(ctx, 100)
                    local action_changed, new_action =
                        reaper.ImGui_InputTextWithHint(ctx, "##action" .. i, "Command ID", item.action_id or "")
                    if action_changed then
                        item.action_id = tostring(new_action)
                        button.dropdown_menu[i].action_id = tostring(new_action)
                    end
                end

                reaper.ImGui_SameLine(ctx)

                if reaper.ImGui_Button(ctx, "X##" .. i) then
                    to_delete = i
                end
                if reaper.ImGui_IsItemHovered(ctx) then
                    reaper.ImGui_BeginTooltip(ctx)
                    reaper.ImGui_Text(ctx, "Delete item")
                    reaper.ImGui_EndTooltip(ctx)
                end

                reaper.ImGui_PopID(ctx)
            end

            local changes_made = false
            if to_delete then
                table.remove(button.dropdown_menu, to_delete)
                changes_made = true
            end
            if move_up and move_up > 1 then
                button.dropdown_menu[move_up], button.dropdown_menu[move_up - 1] =
                    button.dropdown_menu[move_up - 1],
                    button.dropdown_menu[move_up]
                changes_made = true
            end
            if move_down and move_down < #button.dropdown_menu then
                button.dropdown_menu[move_down], button.dropdown_menu[move_down + 1] =
                    button.dropdown_menu[move_down + 1],
                    button.dropdown_menu[move_down]
                changes_made = true
            end
            if changes_made then
                CONFIG_MANAGER:saveToolbarConfig(button.parent_toolbar)
            end
        end

        reaper.ImGui_Separator(ctx)
        if reaper.ImGui_Button(ctx, "Save Changes") then
            CONFIG_MANAGER:saveToolbarConfig(button.parent_toolbar)
        end
    end

    reaper.ImGui_End(ctx)
    C.GlobalStyle.reset(ctx, colorCount, styleCount)
    if not open then
        _G.POPUP_OPEN = false
    end
    self.is_open = open
    
    return self.is_open
end

return ButtonDropdownEditor.new()