-- Menus/Button_Dropdown_Menu.lua
local ButtonDropdown = {}
ButtonDropdown.__index = ButtonDropdown

function ButtonDropdown.new()
    local self = setmetatable({}, ButtonDropdown)

    self.is_open = false
    self.current_button = nil
    self.current_position = {x = 0, y = 0}
    self.popup_open = false

    return self
end

function ButtonDropdown:renderDropdown(ctx)
    if not self.is_open or not self.current_button then
        return false
    end

    local button = self.current_button

    -- Set position and styling
    reaper.ImGui_SetNextWindowPos(ctx, self.current_position.x, self.current_position.y + CONFIG.SIZES.HEIGHT)

    -- Open the popup if it's not already open
    if not self.popup_open then
        reaper.ImGui_OpenPopup(ctx, "##dropdown_popup_" .. button.id)
        self.popup_open = true
    end

    -- Apply global style
    local colorCount, styleCount = C.GlobalStyle.apply(ctx)

    local visible = reaper.ImGui_BeginPopup(ctx, "##dropdown_popup_" .. button.id)

    if visible then
        -- Check for Escape key to close the dropdown
        if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) then
            reaper.ImGui_CloseCurrentPopup(ctx)
            self.is_open = false
            self.popup_open = false
        end

        -- Render dropdown items
        if button.dropdown_menu and #button.dropdown_menu > 0 then
            for _, item in ipairs(button.dropdown_menu) do
                if item.is_separator then
                    reaper.ImGui_Separator(ctx)
                else
                    -- Get the name with proper fallback
                    local item_name = item.name or "Unnamed"

                    -- Make sure the button takes full width of the window
                    local avail_width = reaper.ImGui_GetContentRegionAvail(ctx)

                    -- Use Button with the name text
                    if reaper.ImGui_Button(ctx, item_name, avail_width, 0) then
                        -- Execute the action
                        if item.action_id and item.action_id ~= "" then
                            local cmdID
                            if item.action_id:match("^_") then
                                cmdID = reaper.NamedCommandLookup(item.action_id)
                            else
                                cmdID = tonumber(item.action_id)
                            end

                            if cmdID and cmdID ~= 0 then
                                reaper.Main_OnCommand(cmdID, 0)
                            end
                        end

                        reaper.ImGui_CloseCurrentPopup(ctx)
                        self.is_open = false
                        self.popup_open = false
                    end

                    -- Show tooltip
                    if item.action_id and reaper.ImGui_IsItemHovered(ctx) then
                        reaper.ImGui_BeginTooltip(ctx)
                        reaper.ImGui_Text(ctx, "Action: " .. item.action_id)
                        reaper.ImGui_EndTooltip(ctx)
                    end
                end
            end
        else
            reaper.ImGui_Text(ctx, "No dropdown items defined")
        end

        reaper.ImGui_EndPopup(ctx)
    else
        -- Popup was closed from outside
        self.is_open = false
        self.popup_open = false
    end

    -- Reset global style
    C.GlobalStyle.reset(ctx, colorCount, styleCount)

    return self.is_open
end

return ButtonDropdown.new()
