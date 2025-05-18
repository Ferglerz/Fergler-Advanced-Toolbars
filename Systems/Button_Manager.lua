-- Systems/Button_Manager.lua
-- Manages button state and command execution

local ButtonManager = {}
ButtonManager.__index = ButtonManager

function ButtonManager.new()
    local self = setmetatable({}, ButtonManager)

    -- Button registry
    self.buttons = {}

    -- State tracking
    self.command_state_cache = {}
    self.armed_command = nil
    self.flash_state = false
    self.last_update_time = 0

    return self
end

function ButtonManager:registerButton(button)
    if not button or not button.id then
        return
    end
    self.buttons[button.id] = button
    return button
end

function ButtonManager:getCommandID(action_id)
    if type(action_id) == "string" and action_id:match("^_") then
        return reaper.NamedCommandLookup(action_id)
    end
    return tonumber(action_id)
end

function ButtonManager:updateAllButtonStates()
    -- Get the currently armed command in REAPER
    self.armed_command = reaper.GetArmedCommand()

    -- Calculate flashing state for armed buttons
    local flash_interval = CONFIG.UI.FLASH_INTERVAL or 0.5
    local current_time = reaper.time_precise()
    local new_flash_state = math.floor(current_time / (flash_interval / 2)) % 2 == 0
    self.flash_state = new_flash_state

    -- Update each button's state
    for _, button in pairs(self.buttons) do
        local command_id = self:getCommandID(button.id)
        local old_armed = button.is_armed
        local old_toggled = button.is_toggled
        local old_flashing = button.is_flashing

        -- Check if button is armed
        button.is_armed = (self.armed_command == command_id)

        -- Check toggle state
        if command_id then
            if self.command_state_cache[command_id] == nil then
                self.command_state_cache[command_id] = reaper.GetToggleCommandState(command_id)
            end
            button.is_toggled = (self.command_state_cache[command_id] == 1)
        else
            button.is_toggled = false
        end

        -- Set flashing state for armed buttons
        button.is_flashing = (button.is_armed and self.flash_state)

        -- Mark button as dirty if state changed
        button.is_dirty =
            old_armed ~= button.is_armed or old_toggled ~= button.is_toggled or old_flashing ~= button.is_flashing
            
        -- We also need to clear the color cache if the state changes
        if button.is_dirty and button.cache and button.cache.colors then
            button.cache.colors.state_key = nil
            button.cache.colors.mouse_key = nil
        end
        
        -- Initialize cache object if needed
        if not button.cache then
            button.cache = {
                colors = {},
                icon = {}
            }
        elseif not button.cache.icon then
            button.cache.icon = {}
        end

        -- Load icon resources
        if button.icon_char and button.icon_font and not button.cache.icon.font then
            button.cache.icon.font = C.ButtonContent:loadIconFont(button.icon_font)
        elseif button.icon_path and not button.cache.icon.texture then
            C.IconManager:loadButtonIcon(button)
        end
    end
end

-- Execute button command
function ButtonManager:executeButtonCommand(button)
    local cmdID = self:getCommandID(button.id)
    if cmdID then
        reaper.Main_OnCommand(cmdID, 0)
        self.command_state_cache[cmdID] = nil
        return true
    end
    return false
end

-- Toggle arming of a command
function ButtonManager:toggleArmCommand(button)
    local cmdID = self:getCommandID(button.id)
    if not cmdID then
        return false
    end

    if self.armed_command == cmdID then
        reaper.Main_OnCommand(2020, 0) -- Disarm command
    else
        reaper.ArmCommand(cmdID, "")
    end
    self.armed_command = reaper.GetArmedCommand()

    button.is_armed = (self.armed_command == cmdID)
    button.is_dirty = true -- Mark for redraw

    return true
end

function ButtonManager:clearIconCache()
    -- Clear cached icon textures from all buttons
    for _, button in pairs(self.buttons) do
        button.icon_texture = nil
        button.icon_dimensions = nil
    end

    C.IconManager:clearCache()
end

function ButtonManager:cleanup()
    self.buttons = {}
    self.command_state_cache = {}

    if C.IconManager then
        C.IconManager:cleanup()
    end
end

return ButtonManager.new()
