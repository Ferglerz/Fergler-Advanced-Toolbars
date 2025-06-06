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
    if not self.is_open then
        _G.POPUP_OPEN = false
        return false
    end
    
    _G.POPUP_OPEN = true

    local button = self.current_button

    -- Set position and styling
    reaper.ImGui_SetNextWindowPos(ctx, self.current_position.x, self.current_position.y + CONFIG.SIZES.HEIGHT)

    -- Use instance_id for unique popup identification
    local popup_id = "##dropdown_popup_" .. button.instance_id

    -- Open the popup if it's not already open
    if not self.popup_open then
        reaper.ImGui_OpenPopup(ctx, popup_id)
        self.popup_open = true
    end

    -- Apply global style
    local colorCount, styleCount = C.GlobalStyle.apply(ctx)

    local visible = reaper.ImGui_BeginPopup(ctx, popup_id)

    if visible then
        -- Check for dynamic items first, then fall back to button.dropdown_menu
        local items = button.dynamic_items or button.dropdown_menu or {}

        -- Render dropdown items
        if items and #items > 0 then
            for _, item in ipairs(items) do
                if item.is_separator then
                    reaper.ImGui_Separator(ctx)
                else
                    -- Get the name with proper fallback
                    local item_name = item.name or "Unnamed"

                    -- Make sure the button takes full width of the window
                    local avail_width = reaper.ImGui_GetContentRegionAvail(ctx)

                    -- Use Button with the name text
                    if reaper.ImGui_Button(ctx, item_name, avail_width, 0) then
                        -- Check if this is a widget dropdown
                        if button.instance_id and button.instance_id:match("^widget_dropdown_") and button.widget_ref then
                            -- Call widget's onSelect if it exists
                            if button.widget_ref.onSelect then
                                button.widget_ref.onSelect(button.widget_ref, item)
                                button.widget_ref.selected_text = item_name
                            end
                        else
                            -- Regular button dropdown - execute the action
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

    if not visible then
        self.is_open = false
        _G.POPUP_OPEN = false
    end
    
    return self.is_open
        
end

return ButtonDropdown.new()