-- button_state_manager.lua
local ButtonStateManager = {}
ButtonStateManager.__index = ButtonStateManager

function ButtonStateManager.new(reaper)
    local self = setmetatable({}, ButtonStateManager)
    self.r = reaper
    
    -- Core state storage
    self.buttons = {}
    self.texture_cache = {}
    self.hover_start_times = {}
    self.command_state_cache = {}
    
    -- Global states
    self.armed_command = nil
    self.flash_state = false
    self.last_update_time = 0
    
    return self
end

-- Register a button for state tracking
function ButtonStateManager:registerButton(button)
    if not button or not button.id then return end
    self.buttons[button.id] = button
    return button
end

-- Unregister a button
function ButtonStateManager:unregisterButton(button_id)
    if self.buttons[button_id] then
        self.buttons[button_id] = nil
    end
end

-- Get REAPER command ID from action ID string
function ButtonStateManager:getCommandID(action_id)
    if type(action_id) == "string" and action_id:match("^_") then
        return self.r.NamedCommandLookup(action_id)
    else
        return tonumber(action_id)
    end
end

-- Update the armed command state
function ButtonStateManager:updateArmedCommand()
    self.armed_command = self.r.GetArmedCommand()
    return self.armed_command
end

-- Update flashing state for armed buttons
function ButtonStateManager:updateFlashState()
    local flash_interval = CONFIG.UI.FLASH_INTERVAL or 0.5
    local current_time = self.r.time_precise()
    self.flash_state = math.floor(current_time / (flash_interval / 2)) % 2 == 0
    return self.flash_state
end

-- Get toggle state for a button with caching
function ButtonStateManager:getToggleState(button)
    local cmdID = self:getCommandID(button.id)
    if not cmdID then return -1 end
    
    -- Use cached state if available
    if self.command_state_cache[cmdID] == nil then
        self.command_state_cache[cmdID] = self.r.GetToggleCommandState(cmdID)
    end
    
    return self.command_state_cache[cmdID]
end

-- Update a single button's state
function ButtonStateManager:updateButtonState(button)
    if not button then return end
    
    local command_id = self:getCommandID(button.id)
    
    -- Store old states to detect changes
    local old_armed = button.is_armed
    local old_toggled = button.is_toggled
    local old_flashing = button.is_flashing
    
    -- Update armed state
    button.is_armed = (self.armed_command == command_id)
    
    -- Update toggle state
    button.is_toggled = (self:getToggleState(button) == 1)
    
    -- Update flash state
    button.is_flashing = (button.is_armed and self.flash_state)
    
    -- Mark as dirty if state changed
    if old_armed ~= button.is_armed or 
       old_toggled ~= button.is_toggled or
       old_flashing ~= button.is_flashing then
        button.is_dirty = true
    end
end

-- Update all registered buttons' states at once
function ButtonStateManager:updateAllButtonStates()
    -- Update global states once
    self:updateArmedCommand()
    self:updateFlashState()
    
    -- Update each button efficiently
    for _, button in pairs(self.buttons) do
        self:updateButtonState(button)
    end
end

-- Track hover state for tooltips
function ButtonStateManager:trackHoverState(ctx, button_id, is_hovered)
    if is_hovered then
        if not self.hover_start_times[button_id] then
            self.hover_start_times[button_id] = self.r.ImGui_GetTime(ctx)
        end
        return self.r.ImGui_GetTime(ctx) - self.hover_start_times[button_id]
    else
        self.hover_start_times[button_id] = nil
        return 0
    end
end

-- Handle button click events
function ButtonStateManager:handleButtonClick(button, is_right_click)
    if not button then return false end
    
    if is_right_click then
        -- Handle right-click based on button configuration
        if button.right_click == "arm" then
            local pre_armed = self.r.GetArmedCommand()
            local cmdID = self:getCommandID(button.id)
            
            if not cmdID then return false end
            
            if pre_armed == cmdID then
                self.r.Main_OnCommand(2020, 0) -- Disarm current action
            else
                self.r.ArmCommand(cmdID, "Main") -- Arm this button's command
            end
            
            -- Update armed state immediately
            self:updateArmedCommand()
            return true
        elseif button.right_click == "dropdown" then
            -- Signal that dropdown should be shown (handled by UI)
            return true
        elseif button.right_click == "none" then
            return false
        end
    else
        -- Handle left-click (normal command execution)
        local cmdID = self:getCommandID(button.id)
        if cmdID then
            self.r.Main_OnCommand(cmdID, 0)
            -- Clear command state cache for this command
            self.command_state_cache[cmdID] = nil
            return true
        end
    end
    
    return false
end

-- Icon texture management
function ButtonStateManager:loadIconTexture(button)
    if not button or not button.icon_path or button.skip_icon then
        return nil
    end
    
    -- Normalize path and handle different OS formats
    local normalized_path = button.icon_path:gsub("\\", "/")
    
    -- Check cache first
    if self.texture_cache[normalized_path] then
        return self.texture_cache[normalized_path]
    end
    
    -- Load new texture
    local texture = self.r.ImGui_CreateImage(normalized_path)
    if texture then
        self.texture_cache[normalized_path] = texture
        return texture
    end
    
    return nil
end

-- Get dimensions for an icon
function ButtonStateManager:getIconDimensions(texture)
    if not texture then return nil end
    
    local success, w, h = pcall(function()
        return self.r.ImGui_Image_GetSize(texture)
    end)
    
    if not success or not w or not h then
        return nil
    end
    
    local max_height = CONFIG.SIZES.HEIGHT - (CONFIG.ICON_FONT.PADDING * 2)
    local scale = math.min(1, max_height / h)
    
    return {
        width = math.floor(w * scale * CONFIG.ICON_FONT.SCALE),
        height = math.floor(h * scale * CONFIG.ICON_FONT.SCALE)
    }
end

-- Clear all caches
function ButtonStateManager:clearCaches()
    self.command_state_cache = {}
    self.hover_start_times = {}
    -- We don't clear texture_cache here as textures should be managed separately
end

-- Clean up all resources
function ButtonStateManager:cleanup()
    self.buttons = {}
    self.command_state_cache = {}
    self.hover_start_times = {}
    self.texture_cache = {}
end

return {
    new = function(reaper)
        return ButtonStateManager.new(reaper)
    end
}