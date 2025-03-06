-- dropdown_renderer.lua
local DropdownRenderer = {}
DropdownRenderer.__index = DropdownRenderer

function DropdownRenderer.new(reaper, helpers)
    local self = setmetatable({}, DropdownRenderer)
    self.r = reaper
    self.helpers = helpers
    self.is_open = false
    self.current_button = nil
    self.current_position = {x = 0, y = 0}
    self.popup_open = false
    
    self.focusArrangeCallback = nil
    
    return self
end

function DropdownRenderer:show(button, position)
    self.current_button = button
    self.current_position = position
    self.is_open = true

    -- Initialize dropdown if it doesn't exist
    if not button.dropdown then
        button.dropdown = {}
    end

    -- Make sure all dropdown items have consistent properties
    for i, item in ipairs(button.dropdown) do
        if not item.is_separator then
            item.name = item.name or "Unnamed"
            item.action_id = tostring(item.action_id or "")
        end
    end
end

function DropdownRenderer:renderDropdown(ctx, button_state, saveConfig)
    if not self.is_open or not self.current_button then
        return false
    end

    local button = self.current_button

    -- Set position and styling
    self.r.ImGui_SetNextWindowPos(ctx, self.current_position.x, self.current_position.y + CONFIG.SIZES.HEIGHT)

    -- Use popup flags similar to the context menu
    local window_flags =
        self.r.ImGui_WindowFlags_NoMove() | self.r.ImGui_WindowFlags_NoResize() | self.r.ImGui_WindowFlags_NoScrollbar() |
        self.r.ImGui_WindowFlags_NoTitleBar() |
        self.r.ImGui_WindowFlags_AlwaysAutoResize() |
        self.r.ImGui_WindowFlags_NoFocusOnAppearing()

    -- Open the popup if it's not already open
    if not self.popup_open then
        self.r.ImGui_OpenPopup(ctx, "##dropdown_popup_" .. button.id)
        self.popup_open = true
    end

    self.r.ImGui_PushStyleVar(ctx, self.r.ImGui_StyleVar_WindowPadding(), 4, 4)
    self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_WindowBg(), 0x333333FF)

    -- Style the buttons to look more like menu items
    self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_Button(), 0x00000000)
    self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_ButtonHovered(), 0x3D3D3DFF)
    self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_ButtonActive(), 0x4D4D4DFF)
    self.r.ImGui_PushStyleVar(ctx, self.r.ImGui_StyleVar_FramePadding(), 4, 4)
    self.r.ImGui_PushStyleVar(ctx, self.r.ImGui_StyleVar_ButtonTextAlign(), 0, 0.5)

    -- Begin the popup (this will auto-close when clicking outside)
    local visible = self.r.ImGui_BeginPopup(ctx, "##dropdown_popup_" .. button.id)

    if visible then
        -- Check for Escape key to close the dropdown
        if self.r.ImGui_IsKeyPressed(ctx, self.r.ImGui_Key_Escape()) then
            self.r.ImGui_CloseCurrentPopup(ctx)
            self.is_open = false
        end

        -- Render dropdown items
        if button.dropdown and #button.dropdown > 0 then
            for idx, item in ipairs(button.dropdown) do
                if item.is_separator then
                    self.r.ImGui_Separator(ctx)
                else
                    -- Get the name with proper fallback
                    local item_name = item.name or "Unnamed"

                    -- Make sure the button takes full width of the window
                    local avail_width = self.r.ImGui_GetContentRegionAvail(ctx)

                    -- Use Button with the name text
                    if self.r.ImGui_Button(ctx, item_name, avail_width, 0) then
                        -- Execute the action
                        if item.action_id and item.action_id ~= "" then
                            local cmdID
                            if item.action_id:match("^_") then
                                cmdID = self.r.NamedCommandLookup(item.action_id)
                            else
                                cmdID = tonumber(item.action_id)
                            end

                            if cmdID and cmdID ~= 0 then
                                self.r.Main_OnCommand(cmdID, 0)
                            end
                        end

                        self.r.ImGui_CloseCurrentPopup(ctx)
                        self.is_open = false
                    end

                    -- Show tooltip
                    if item.action_id and self.r.ImGui_IsItemHovered(ctx) then
                        self.r.ImGui_BeginTooltip(ctx)
                        self.r.ImGui_Text(ctx, "Action: " .. item.action_id)
                        self.r.ImGui_EndTooltip(ctx)
                    end
                end
            end
        else
            self.r.ImGui_Text(ctx, "No dropdown items defined")
        end

        self.r.ImGui_EndPopup(ctx)
    else
        -- Popup was closed from outside
        self.is_open = false
        self.popup_open = false
    end

    -- Pop all style modifications
    self.r.ImGui_PopStyleVar(ctx, 3)
    self.r.ImGui_PopStyleColor(ctx, 4)

    return self.is_open
end

-- Create a new dropdown editor window
function DropdownRenderer:renderDropdownEditor(ctx, button, saveConfig)
    if not button then
        return false
    end

    local window_flags =
        self.r.ImGui_WindowFlags_NoCollapse() | self.r.ImGui_WindowFlags_AlwaysAutoResize() |
        self.r.ImGui_WindowFlags_NoDocking()
    
    local visible, open = self.r.ImGui_Begin(ctx, "Dropdown Editor - " .. self.helpers.stripNewLines(button.display_text), true, window_flags)
    if visible then
        -- Initialize dropdown array if it doesn't exist
        if not button.dropdown then
            button.dropdown = {}
        end

        -- Add item button
        if self.r.ImGui_Button(ctx, "Add Item") then
            table.insert(
                button.dropdown,
                {
                    name = "New Item",
                    action_id = ""
                }
            )

            -- Safely save
            self:safeConfigSave(saveConfig)
        end

        self.r.ImGui_SameLine(ctx)

        -- Add separator button
        if self.r.ImGui_Button(ctx, "Add Separator") then
            table.insert(
                button.dropdown,
                {
                    is_separator = true
                }
            )

            -- Safely save
            self:safeConfigSave(saveConfig)
        end

        self.r.ImGui_Separator(ctx)

        -- Items list with up/down arrows for reordering
        if #button.dropdown == 0 then
            self.r.ImGui_TextDisabled(ctx, "No items in dropdown")
        else
            local to_delete = nil
            local move_up = nil
            local move_down = nil

            -- Make a local copy of the dropdown to avoid modification during iteration
            local dropdown_copy = {}
            for i, item in ipairs(button.dropdown) do
                dropdown_copy[i] = item
            end

            for i, item in ipairs(dropdown_copy) do
                self.r.ImGui_PushID(ctx, i)

                -- Up button (disabled for first item)
                if i > 1 then
                    if self.r.ImGui_Button(ctx, "^##up" .. i) then
                        move_up = i
                    end
                    if self.r.ImGui_IsItemHovered(ctx) then
                        self.r.ImGui_BeginTooltip(ctx)
                        self.r.ImGui_Text(ctx, "Move Up")
                        self.r.ImGui_EndTooltip(ctx)
                    end
                else
                    -- Disabled button for first item
                    self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_Button(), 0x44444444)
                    self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_ButtonHovered(), 0x44444444)
                    self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_ButtonActive(), 0x44444444)
                    self.r.ImGui_Button(ctx, "^##up" .. i)
                    self.r.ImGui_PopStyleColor(ctx, 3)
                end

                self.r.ImGui_SameLine(ctx)

                -- Down button (disabled for last item)
                if i < #button.dropdown then
                    if self.r.ImGui_Button(ctx, "v##down" .. i) then
                        move_down = i
                    end
                    if self.r.ImGui_IsItemHovered(ctx) then
                        self.r.ImGui_BeginTooltip(ctx)
                        self.r.ImGui_Text(ctx, "Move Down")
                        self.r.ImGui_EndTooltip(ctx)
                    end
                else
                    -- Disabled button for last item
                    self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_Button(), 0x44444444)
                    self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_ButtonHovered(), 0x44444444)
                    self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_ButtonActive(), 0x44444444)
                    self.r.ImGui_Button(ctx, "v##down" .. i)
                    self.r.ImGui_PopStyleColor(ctx, 3)
                end

                self.r.ImGui_SameLine(ctx)

                if item.is_separator then
                    self.r.ImGui_Text(ctx, "--- Separator ---")
                else
                    -- Name field
                    self.r.ImGui_SetNextItemWidth(ctx, 150)
                    local name_changed, new_name = self.r.ImGui_InputText(ctx, "##name" .. i, item.name or "")
                    if name_changed then
                        item.name = new_name
                        button.dropdown[i].name = new_name
                    end

                    self.r.ImGui_SameLine(ctx)

                    -- Action ID field
                    self.r.ImGui_SetNextItemWidth(ctx, 100)
                    local action_changed, new_action =
                        self.r.ImGui_InputText(ctx, "##action" .. i, item.action_id or "")
                    if action_changed then
                        -- Always store as string
                        item.action_id = tostring(new_action)
                        button.dropdown[i].action_id = tostring(new_action)
                    end
                end

                self.r.ImGui_SameLine(ctx)

                -- Delete button
                if self.r.ImGui_Button(ctx, "X##" .. i) then
                    to_delete = i
                end

                if self.r.ImGui_IsItemHovered(ctx) then
                    self.r.ImGui_BeginTooltip(ctx)
                    self.r.ImGui_Text(ctx, "Delete item")
                    self.r.ImGui_EndTooltip(ctx)
                end

                self.r.ImGui_PopID(ctx)
            end

            -- Handle operations at the end to avoid messing up the loop
            local changes_made = false

            -- Handle deletion
            if to_delete then
                table.remove(button.dropdown, to_delete)
                changes_made = true
            end

            -- Handle move up
            if move_up and move_up > 1 then
                local temp = button.dropdown[move_up]
                button.dropdown[move_up] = button.dropdown[move_up - 1]
                button.dropdown[move_up - 1] = temp
                changes_made = true
            end

            -- Handle move down
            if move_down and move_down < #button.dropdown then
                local temp = button.dropdown[move_down]
                button.dropdown[move_down] = button.dropdown[move_down + 1]
                button.dropdown[move_down + 1] = temp
                changes_made = true
            end

            -- Save changes if needed
            if changes_made then
                self:safeConfigSave(saveConfig)
            end
        end

        -- Add a save button at the bottom
        self.r.ImGui_Separator(ctx)
        if self.r.ImGui_Button(ctx, "Save Changes") then
            self:safeConfigSave(saveConfig)
        end
    end

    self.r.ImGui_End(ctx)

    return open
end

-- Safe save method
function DropdownRenderer:safeConfigSave(saveConfig)
    -- Wrap with pcall to avoid errors
    local success, error_message =
        pcall(
        function()
            saveConfig()
        end
    )

    if not success then
        self.r.ShowConsoleMsg("Save error: " .. tostring(error_message) .. "\n")
    end
end

return {
    new = function(reaper, helpers)
        return DropdownRenderer.new(reaper, helpers)
    end
}
