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
    self.toggle_support_cache = {}  -- Cache for toggle support detection
    self.armed_command = nil
    self.flash_state = false
    self.last_update_time = 0

    return self
end

function ButtonManager:registerButton(button)
    if not button or not button.instance_id then
        return
    end
    
    -- Ensure button has a cache table
    if not button.cache then
        button.cache = {}
    end
    
    -- Use instance_id instead of id for unique button tracking
    self.buttons[button.instance_id] = button
    return button
end

function ButtonManager:getCommandID(action_id)
    if type(action_id) == "string" and action_id:match("^_") then
        return reaper.NamedCommandLookup(action_id)
    end
    return tonumber(action_id)
end

-- Check if a command supports toggling
function ButtonManager:isToggleCommand(command_id)
    if not command_id then
        return false
    end
    
    -- Check cache first
    if self.toggle_support_cache[command_id] ~= nil then
        return self.toggle_support_cache[command_id]
    end
    
    -- Check toggle state - returns -1 for non-toggle commands, 0 or 1 for toggle commands
    local toggle_state = reaper.GetToggleCommandState(command_id)
    local is_toggle = (toggle_state >= 0)
    
    -- Cache the result
    self.toggle_support_cache[command_id] = is_toggle
    
    return is_toggle
end

-- Get current toggle state (only call if isToggleCommand returns true)
function ButtonManager:getToggleState(command_id)
    if not command_id then
        return false
    end
    
    if self.command_state_cache[command_id] == nil then
        self.command_state_cache[command_id] = reaper.GetToggleCommandState(command_id)
    end
    
    return (self.command_state_cache[command_id] == 1)
end

function ButtonManager:updateAllButtonStates()
    -- Get the currently armed command in REAPER
    self.armed_command = reaper.GetArmedCommand()

    -- Calculate flashing state for armed buttons
    local flash_interval = CONFIG.UI.FLASH_INTERVAL or 0.5
    local current_time = reaper.time_precise()
    self.flash_state = math.floor(current_time / (flash_interval / 2)) % 2 == 0

    -- Update each button's state using instance_id for tracking
    for instance_id, button in pairs(self.buttons) do
        -- Ensure button has cache
        if not button.cache then
            button.cache = {}
        end
        
        local command_id = self:getCommandID(button.id)  -- Still use button.id for the actual command
        local old_armed = button.is_armed
        local old_toggled = button.is_toggled
        local old_flashing = button.is_flashing

        -- Check if button is armed
        button.is_armed = (self.armed_command == command_id)

        -- Check toggle state using new method
        if command_id and self:isToggleCommand(command_id) then
            button.is_toggled = self:getToggleState(command_id)
        else
            button.is_toggled = false
        end

        -- Set flashing state for armed buttons
        button.is_flashing = (button.is_armed and self.flash_state)

        -- Mark button as dirty if state changed
        button.is_dirty =
            old_armed ~= button.is_armed or old_toggled ~= button.is_toggled or old_flashing ~= button.is_flashing
    end
end

-- Execute button command
function ButtonManager:executeButtonCommand(button)
    local cmdID = self:getCommandID(button.id)  -- Use button.id for the actual command
    if cmdID then
        reaper.Main_OnCommand(cmdID, 0)
        self.command_state_cache[cmdID] = nil
        return true
    end
    return false
end

-- Toggle arming of a command
function ButtonManager:toggleArmCommand(button)
    local cmdID = self:getCommandID(button.id)  -- Use button.id for the actual command
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
    for instance_id, button in pairs(self.buttons) do
        button.icon_texture = nil
        button.icon_dimensions = nil
    end

    C.IconManager:clearCache()
end

function ButtonManager:cleanup()
    self.buttons = {}
    self.command_state_cache = {}
    self.toggle_support_cache = {}

    -- Delegate to IconManager
    if C.IconManager then
        C.IconManager:cleanup()
    end
end

return ButtonManager.new()