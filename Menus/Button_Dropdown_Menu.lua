-- Menus/Button_Dropdown_Menu.lua
local PopupContext = require("Systems.Popup_Context")
local ButtonDropdown = {}
ButtonDropdown.__index = ButtonDropdown

function ButtonDropdown.new()
    local self = setmetatable({}, ButtonDropdown)

    self.is_open = false
    self.current_button = nil
    self.current_position = {x = 0, y = 0}
    self.popup_open = false
    -- ImGui popup stack is per-context; only render on the ctx that called OpenPopup (see Interactions:showDropdownMenu).
    self.owner_ctx = nil
    -- Frames to wait before treating BeginPopup failure as "popup closed" (ReaImGui / ImGui timing)
    self.beginpopup_grace = 0

    return self
end

function ButtonDropdown:renderDropdown(ctx)
    if not PopupContext.guardRender(self, ctx) then
        if not self.is_open then self.popup_open = false end
        return false
    end

    -- Keep popup state alive until the owning toolbar context renders it.
    if self.owner_ctx and ctx ~= self.owner_ctx then
        return self.is_open
    end
    
    _G.POPUP_OPEN = true

    local button = self.current_button
    local is_widget_dropdown = button.instance_id and button.instance_id:match("^widget_dropdown_") and button.widget_ref

    -- Pin to the cursor (same anchor as insert menu / context menus), not below the button height.
    reaper.ImGui_SetNextWindowPos(ctx, self.current_position.x, self.current_position.y, reaper.ImGui_Cond_Always())

    -- Use instance_id for unique popup identification
    local popup_id = "##dropdown_popup_" .. button.instance_id

    -- Open the popup if it's not already open
    if not self.popup_open then
        reaper.ImGui_OpenPopup(ctx, popup_id)
        self.popup_open = true
    end

    C.GlobalStyle.withGlobalStyle(ctx, function()
        local visible = reaper.ImGui_BeginPopup(ctx, popup_id)

        if visible then
        self.beginpopup_grace = 0
        -- Check for dynamic items first, then fall back to button.dropdown_menu
        local items = button.dynamic_items or button.dropdown_menu or {}

        local function renderItems(rows, path)
            if #rows == 0 then
                reaper.ImGui_TextDisabled(ctx, "No items in this submenu")
                return
            end
            for i, item in ipairs(rows) do
                local row_id = path .. "/" .. i
                if item.is_separator then
                    reaper.ImGui_Separator(ctx)
                elseif item.is_heading then
                    reaper.ImGui_TextDisabled(ctx, item.name or "")
                else
                    local item_name = item.name or "Unnamed"
                    local label = item_name .. "##dropdown_row_" .. row_id
                    if type(item.children) == "table" then
                        if reaper.ImGui_BeginMenu(ctx, label, not item.disabled) then
                            renderItems(item.children, row_id)
                            reaper.ImGui_EndMenu(ctx)
                        end
                        goto continue
                    end

                    local cmdID
                    if not is_widget_dropdown and item.action_id and item.action_id ~= "" then
                        cmdID = BUTTON_UTILS.resolveActionCommandId(item.action_id)
                    end
                    local checked = cmdID and cmdID > 0 and reaper.GetToggleCommandState(cmdID) == 1 or false
                    local clicked = reaper.ImGui_MenuItem(ctx, label, nil, checked, not item.disabled)

                    if clicked then
                        -- Check if this is a widget dropdown
                        if is_widget_dropdown then
                            -- Call widget's onSelect if it exists
                            if button.widget_ref.onSelect then
                                button.widget_ref.onSelect(button.widget_ref, item)
                            else
                                button.widget_ref.selected_text = item_name
                            end
                        else
                            -- Regular button dropdown - execute the action
                            if cmdID and cmdID > 0 then
                                reaper.Main_OnCommand(cmdID, 0)
                            else
                                local id_text = item.action_id and item.action_id ~= "" and item.action_id or "no command ID"
                                reaper.ShowConsoleMsg("Advanced Toolbars: Dropdown action unavailable for '" ..
                                    tostring(item_name) .. "' (" .. tostring(id_text) .. ")\n")
                            end
                        end

                        reaper.ImGui_CloseCurrentPopup(ctx)
                        PopupContext.closeOrFallback(self)
                        self.popup_open = false
                    end

                    -- Show tooltip
                    if not is_widget_dropdown and reaper.ImGui_IsItemHovered(ctx) then
                        reaper.ImGui_BeginTooltip(ctx)
                        if cmdID and cmdID > 0 then
                            reaper.ImGui_Text(ctx, "Action: " .. tostring(item.action_id))
                        else
                            local id_text = item.action_id and item.action_id ~= "" and item.action_id or "no command ID"
                            reaper.ImGui_Text(ctx, "Action unavailable: " .. tostring(id_text))
                        end
                        reaper.ImGui_EndTooltip(ctx)
                    end
                end
                ::continue::
            end
        end
        -- Render dropdown items
        if items and #items > 0 then
            renderItems(items, "root")
        else
            reaper.ImGui_Text(ctx, "No dropdown items defined")
        end

        reaper.ImGui_EndPopup(ctx)
    else
        -- BeginPopup can return false on the same frame as OpenPopup; don't clear is_open until
        -- the popup id is gone from the stack and grace frames have passed.
        if reaper.ImGui_IsPopupOpen(ctx, popup_id) then
            self.beginpopup_grace = 0
        elseif (self.beginpopup_grace or 0) > 0 then
            self.beginpopup_grace = self.beginpopup_grace - 1
        else
            PopupContext.closeOrFallback(self)
            self.popup_open = false
        end
        end
    end)

    if not self.is_open then
        _G.POPUP_OPEN = false
    end
    
    return self.is_open
        
end

return ButtonDropdown
