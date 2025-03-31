-- Systems/Interactions.lua
-- Handles user interactions with toolbar and buttons

local Interactions = {}
Interactions.__index = Interactions

function Interactions.new()
    local self = setmetatable({}, Interactions)

    -- State tracking for interactions
    self.hover_start_times = {}
    self.active_buttons = {}

    -- UI state
    self.is_mouse_down = false
    self.was_mouse_down = false

    -- Dropdown/context menu state
    self.dropdown_button = nil
    self.dropdown_position = nil
    self.button_settings_button = nil
    self.button_settings_group = nil

    return self
end

-- Set up the interaction area for a button
function Interactions:setupInteractionArea(ctx, pos_x, pos_y, width, height, button_id)
    reaper.ImGui_SetCursorPos(ctx, pos_x, pos_y)

    -- Batch all style colors at once for transparent button container
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x00000000)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x00000000)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), 0x00000000)

    local clicked = reaper.ImGui_Button(ctx, "##" .. button_id, width, height)
    local is_hovered = reaper.ImGui_IsItemHovered(ctx)
    local is_clicked = reaper.ImGui_IsItemActive(ctx)

    -- Pop all style colors at once
    reaper.ImGui_PopStyleColor(ctx, 3)

    self.ctx = ctx

    return clicked, is_hovered, is_clicked
end

-- Determine the state key based on button state
function Interactions:determineStateKey(button)
    if button.is_toggled then
        return "TOGGLED"
    elseif button.is_armed then
        return button.is_flashing and "ARMED_FLASH" or "ARMED"
    else
        return "NORMAL"
    end
end

-- Determine the mouse interaction key
function Interactions:determineMouseKey(is_hovered, is_clicked)
    if is_clicked then
        return "CLICKED"
    elseif is_hovered then
        return "HOVER"
    else
        return "NORMAL"
    end
end

-- Track button hover state and handle hover transitions
function Interactions:handleHover(ctx, button, is_hovered, is_editing_mode)
    -- Track hover transitions
    local hover_changed = button.is_hovered ~= is_hovered

    -- Handle hover tracking for tooltips etc.
    local hover_time = 0
    if is_hovered then
        if not self.hover_start_times[button.id] then
            self.hover_start_times[button.id] = reaper.ImGui_GetTime(ctx)
        end
        hover_time = reaper.ImGui_GetTime(ctx) - self.hover_start_times[button.id]

        -- Show tooltip if not in editing mode and hover time exceeds delay
        if not is_editing_mode and hover_time > CONFIG.UI.HOVER_DELAY then
            self:showTooltip(ctx, button, hover_time)
        end
    else
        self.hover_start_times[button.id] = nil
    end

    -- Update button state
    button.is_hovered = is_hovered
    button.is_right_clicked = is_hovered and reaper.ImGui_IsMouseClicked(ctx, 1)

    return hover_changed, hover_time
end

function Interactions:showTooltip(ctx, button, hover_time)
    local fade_progress = math.min((hover_time - CONFIG.UI.HOVER_DELAY) / 0.5, 1)
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

function Interactions:showDropdownMenu(ctx, button, position)
    if not button then
        return false
    end
    
    -- If there's no dropdown menu or it's empty, show the editor directly
    if not button.dropdown_menu or #button.dropdown_menu == 0 then
        -- Show the dropdown editor instead
        if C.ButtonDropdownEditor then
            C.ButtonDropdownEditor.is_open = true
            C.ButtonDropdownEditor.current_button = button
            return true
        end
        return false
    end

    -- Make sure the dropdown data is correctly assigned
    self.dropdown_button = button
    self.dropdown_position = position

    -- Set the button and position in the ButtonDropdownMenu component
    C.ButtonDropdownMenu.is_open = true
    C.ButtonDropdownMenu.current_button = button
    C.ButtonDropdownMenu.current_position = position
    C.ButtonDropdownMenu.popup_open = false -- Reset popup state

    reaper.ImGui_OpenPopup(ctx, "##dropdown_popup_" .. button.id)

    return true
end

function Interactions:showButtonSettings(button, group)
    self.button_settings_button = button
    self.button_settings_group = group
    return true
end

function Interactions:showGlobalColorEditor(show)
    if not C.GlobalColorEditor then
        return false
    end

    C.GlobalColorEditor.is_open = show or false
    return true
end

function Interactions:showIconSelector(button)
    if not C.IconSelector then
        return false
    end

    C.IconSelector.current_button = button
    C.IconSelector.is_open = true

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

-- Track mouse state for auto-focusing arrange window
function Interactions:trackMouseState(ctx, popup_open)
    local is_mouse_down = reaper.ImGui_IsMouseDown(ctx, 0) or reaper.ImGui_IsMouseDown(ctx, 1)
    local dropdown_active = C.ButtonDropdownMenu and C.ButtonDropdownMenu.is_open

    if self.was_mouse_down and not is_mouse_down and not popup_open and not dropdown_active then
        UTILS.focusArrangeWindow(true)
    end

    -- Store for next frame
    self.was_mouse_down = is_mouse_down
    self.is_mouse_down = is_mouse_down
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
