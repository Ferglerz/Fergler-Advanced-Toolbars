-- Systems/Interactions.lua

local Interactions = {}
Interactions.__index = Interactions

function Interactions.new()
    local self = setmetatable({}, Interactions)

    self.hover_start_times = {}
    self.active_buttons = {}

    self.is_mouse_down = false
    self.was_mouse_down = false

    self.dropdown_button = nil
    self.dropdown_position = nil
    self.button_settings_button = nil
    self.button_settings_group = nil


    return self
end

function Interactions:setupInteractionArea(ctx, rel_x, rel_y, width, height, button_id)
    if not button_id then
        button_id = "unknown_" .. tostring(rel_x) .. "_" .. tostring(rel_y)
    end
    
    -- Set cursor position for ImGui button (needed for IsAnyItemHovered to work)
    reaper.ImGui_SetCursorPos(ctx, rel_x, rel_y)

    -- Create minimal transparent button for ImGui detection
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x00000000)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x00000000)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), 0x00000000)

    local clicked = reaper.ImGui_Button(ctx, "##" .. button_id, width, height)
    local is_hovered = reaper.ImGui_IsItemHovered(ctx)
    local is_clicked = reaper.ImGui_IsItemActive(ctx)

    reaper.ImGui_PopStyleColor(ctx, 3)

    return clicked, is_hovered, is_clicked
end

function Interactions:determineStateKey(button)
    -- Separators use their own color scheme
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

function Interactions:handleHover(ctx, button, is_hovered, is_editing_mode)
    -- Disable hover highlighting for separators in normal mode
    if button:isSeparator() and not is_editing_mode then
        button.is_hovered = false
    else
        button.is_hovered = is_hovered
    end
    button.is_right_clicked = is_hovered and reaper.ImGui_IsMouseClicked(ctx, 1)

    local hover_time = 0
    if is_hovered then
        if not self.hover_start_times[button.instance_id] then
            self.hover_start_times[button.instance_id] = reaper.ImGui_GetTime(ctx)
        end
        hover_time = reaper.ImGui_GetTime(ctx) - self.hover_start_times[button.instance_id]

        if not is_editing_mode and hover_time > CONFIG.UI.HOVER_DELAY then
            self:showTooltip(ctx, button, hover_time)
        end
    else
        self.hover_start_times[button.instance_id] = nil
    end

    return hover_time
end

function Interactions:showTooltip(ctx, button, hover_time)
    local fade_progress = math.min((hover_time - CONFIG.UI.HOVER_DELAY) / 0.5, 1)
    
    -- Separators get simple tooltips
    if button:isSeparator() then
        reaper.ImGui_BeginTooltip(ctx)
        reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_Alpha(), fade_progress)
        reaper.ImGui_Text(ctx, "Separator")
        reaper.ImGui_PopStyleVar(ctx)
        reaper.ImGui_EndTooltip(ctx)
        return
    end
    
    if button.widget and button.widget.description and button.widget.description ~= "" then
        reaper.ImGui_BeginTooltip(ctx)
        reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_Alpha(), fade_progress)
        reaper.ImGui_Text(ctx, button.widget.description)
        reaper.ImGui_PopStyleVar(ctx)
        reaper.ImGui_EndTooltip(ctx)
    else
        local command_id = C.ButtonManager:getCommandID(button.id)
        local action_name = command_id and reaper.CF_GetCommandText(0, command_id)

        if action_name and action_name ~= "" then
            reaper.ImGui_BeginTooltip(ctx)
            reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_Alpha(), fade_progress)
            reaper.ImGui_Text(ctx, action_name)
            reaper.ImGui_PopStyleVar(ctx)
            reaper.ImGui_EndTooltip(ctx)
        end
    end
end

function Interactions:showDropdownMenu(ctx, button, position)
    if not button then
        return false
    end
    
    if not button.dropdown_menu or #button.dropdown_menu == 0 then
        if C.ButtonDropdownEditor then
            C.ButtonDropdownEditor.is_open = true
            C.ButtonDropdownEditor.current_button = button
            _G.POPUP_OPEN = true
            return true
        end
        return false
    end

    self.dropdown_button = button
    self.dropdown_position = position

    C.ButtonDropdownMenu.is_open = true
    C.ButtonDropdownMenu.current_button = button
    C.ButtonDropdownMenu.current_position = position
    _G.POPUP_OPEN = true

    reaper.ImGui_OpenPopup(ctx, "##dropdown_popup_" .. button.instance_id)

    return true
end

function Interactions:showButtonSettings(button, group)
    self.button_settings_button = button
    self.button_settings_group = group
    _G.POPUP_OPEN = true
    return true
end

function Interactions:showGlobalColorEditor(show)
    if not C.GlobalColorEditor then
        return false
    end

    C.GlobalColorEditor.is_open = show or false
    if show then
        _G.POPUP_OPEN = true
    end
    return true
end

function Interactions:showIconSelector(button)
    if not C.IconSelector then
        return false
    end

    C.IconSelector.current_button = button
    C.IconSelector.is_open = true
    _G.POPUP_OPEN = true

    C.IconSelector.previous_icon = {
        icon_char = button.icon_char,
        icon_path = button.icon_path,
        icon_font = button.icon_font
    }

    if button.icon_font then
        local saved_base_name = UTILS.getBaseFontName(button.icon_font)
        for i, font_map in ipairs(C.IconSelector.font_maps) do
            if UTILS.getBaseFontName(font_map.path) == saved_base_name then
                C.IconSelector.selected_font_index = i
                break
            end
        end
    end
    C.IconSelector.close_requested = false

    return true
end

function Interactions:handleRightClick(ctx, button, is_hovered, editing_mode)
    if not is_hovered or not reaper.ImGui_IsMouseClicked(ctx, 1) then
        return false
    end

    local key_mods = reaper.ImGui_GetKeyMods(ctx)
    local is_cmd_down = (key_mods & reaper.ImGui_Mod_Ctrl()) ~= 0
    
    -- Separators only support settings menu in edit mode or with Ctrl
    if button:isSeparator() then
        if is_cmd_down or editing_mode then
            self:showButtonSettings(button, button.parent_group)
            reaper.ImGui_OpenPopup(ctx, "button_settings_menu_" .. button.instance_id)
        end
        return true
    end
    
    -- Normal button right-click behavior
    if is_cmd_down or editing_mode then
        self:showButtonSettings(button, button.parent_group)
        reaper.ImGui_OpenPopup(ctx, "button_settings_menu_" .. button.instance_id)
    elseif button.right_click == "dropdown" then
        local x, y = reaper.ImGui_GetMousePos(ctx)
        self:showDropdownMenu(ctx, button, {x = x, y = y})
    elseif button.right_click == "launch" and button.right_click_action then
        self:executeRightClickAction(button)
    elseif button.right_click == "arm" and not (button.widget and button.widget.type == "slider") then
        C.ButtonManager:toggleArmCommand(button)
    end

    return true
end

function Interactions:executeRightClickAction(button)
    if not button or not button.right_click_action or button.right_click_action == "" then
        return false
    end

    local cmdID
    if button.right_click_action:match("^_") then
        cmdID = reaper.NamedCommandLookup(button.right_click_action)
    else
        cmdID = tonumber(button.right_click_action)
    end

    if cmdID and cmdID ~= 0 then
        reaper.Main_OnCommand(cmdID, 0)
        return true
    end

    return false
end

function Interactions:cleanup()
    self.hover_start_times = {}
    self.dropdown_button = nil
    self.dropdown_position = nil
    self.button_settings_button = nil
    self.button_settings_group = nil
    self.was_mouse_down = false
    self.is_mouse_down = false
end

return Interactions.new()