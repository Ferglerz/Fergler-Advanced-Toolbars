-- Managers/Button.lua
-- Manages button state and command execution

-- REAPER's built-in "No-op (no action)" — never arm (meaningless / confusing)
local NOOP_COMMAND_ID = 65535
local UNDER_MOUSE_CURSOR_PATTERN = "under mouse cursor"
local TOGGLE_POLL_INTERVAL = 0.1

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
    self.last_toggle_poll_time = 0

    -- Dirty / selective update tracking
    self.state_dirty = {}           -- instance_id -> true (needs full state refresh)
    self.toggle_instances = {}      -- instance_id -> command_id (toggle actions to poll)
    self.armed_flash_instances = {} -- instance_id -> true (armed buttons needing flash ticks)

    return self
end

function ButtonManager:markButtonStateDirty(button)
    if button and button.instance_id then
        self.state_dirty[button.instance_id] = true
    end
end

function ButtonManager:markCommandStateDirty(command_id)
    if not command_id then
        return
    end

    self.command_state_cache[command_id] = nil

    for instance_id, button in pairs(self.buttons) do
        if self:getCommandID(button.id) == command_id then
            self.state_dirty[instance_id] = true
        end
    end
end

function ButtonManager:markAllButtonStatesDirty()
    self.command_state_cache = {}

    for instance_id in pairs(self.buttons) do
        self.state_dirty[instance_id] = true
    end
end

function ButtonManager:syncButtonCommandWatch(button)
    if not button or not button.instance_id then
        return
    end

    local instance_id = button.instance_id
    self.toggle_instances[instance_id] = nil

    local command_id = self:getCommandID(button.id)
    if command_id and self:isToggleCommand(command_id) then
        self.toggle_instances[instance_id] = command_id
    end
end

function ButtonManager:markArmedCommandChange(old_armed, new_armed)
    if old_armed == new_armed then
        return
    end

    for instance_id, button in pairs(self.buttons) do
        local command_id = self:getCommandID(button.id)
        if command_id == old_armed or command_id == new_armed then
            self.state_dirty[instance_id] = true
        end
    end
end

function ButtonManager:registerButton(button)
    if not button or not button.instance_id then
        return
    end

    -- Ensure button has a cache table
    CACHE_UTILS.ensureButtonCache(button)

    -- Use instance_id instead of id for unique button tracking
    self.buttons[button.instance_id] = button
    self:syncButtonCommandWatch(button)
    self:markButtonStateDirty(button)
    return button
end

function ButtonManager:unregisterButton(button)
    if button and button.instance_id then
        local instance_id = button.instance_id
        self.buttons[instance_id] = nil
        self.state_dirty[instance_id] = nil
        self.toggle_instances[instance_id] = nil
        self.armed_flash_instances[instance_id] = nil
    end
end

function ButtonManager:getCommandID(action_id)
    return BUTTON_UTILS.resolveActionCommandId(action_id)
end

local function actionNameRequiresAutoArm(action_name)
    local name = tostring(action_name or ""):lower()
    return name:find(UNDER_MOUSE_CURSOR_PATTERN, 1, true) ~= nil
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

function ButtonManager:updateSingleButtonState(button)
    local instance_id = button.instance_id

    CACHE_UTILS.ensureButtonCache(button)

    local command_id = self:getCommandID(button.id)

    button.is_armed = (command_id ~= NOOP_COMMAND_ID and self.armed_command == command_id)

    if command_id and self:isToggleCommand(command_id) then
        button.is_toggled = self:getToggleState(command_id)
    else
        button.is_toggled = false
    end

    button.is_flashing = (button.is_armed and self.flash_state)

    if button.is_armed then
        self.armed_flash_instances[instance_id] = true
    else
        self.armed_flash_instances[instance_id] = nil
        button.is_flashing = false
    end

    self.state_dirty[instance_id] = nil
end

function ButtonManager:pollToggleCommandStates()
    local polled = {}

    for instance_id, command_id in pairs(self.toggle_instances) do
        if not polled[command_id] then
            polled[command_id] = true
            local toggle_state = reaper.GetToggleCommandState(command_id)
            if self.command_state_cache[command_id] ~= toggle_state then
                self.command_state_cache[command_id] = toggle_state
                for iid, cid in pairs(self.toggle_instances) do
                    if cid == command_id then
                        self.state_dirty[iid] = true
                    end
                end
            end
        end
    end
end

function ButtonManager:updateFlashStates()
    for instance_id in pairs(self.armed_flash_instances) do
        local button = self.buttons[instance_id]
        if button then
            button.is_flashing = (button.is_armed and self.flash_state)
        else
            self.armed_flash_instances[instance_id] = nil
        end
    end
end

function ButtonManager:flushDirtyButtonStates()
    for instance_id in pairs(self.state_dirty) do
        local button = self.buttons[instance_id]
        if button then
            self:updateSingleButtonState(button)
        else
            self.state_dirty[instance_id] = nil
        end
    end
end

function ButtonManager:updateAllButtonStates()
    local prev_armed = self.armed_command
    self.armed_command = reaper.GetArmedCommand()

    local flash_interval = CONFIG.UI.FLASH_INTERVAL
    local current_time = reaper.time_precise()
    local flash_state = math.floor(current_time / (flash_interval / 2)) % 2 == 0
    local flash_changed = (flash_state ~= self.flash_state)
    self.flash_state = flash_state

    if self.armed_command ~= prev_armed then
        self:markArmedCommandChange(prev_armed, self.armed_command)
    end

    if current_time - self.last_toggle_poll_time >= TOGGLE_POLL_INTERVAL then
        self.last_toggle_poll_time = current_time
        self:pollToggleCommandStates()
    end

    self:flushDirtyButtonStates()

    if flash_changed then
        self:updateFlashStates()
    end
end

-- Execute button command
function ButtonManager:executeButtonCommand(button)
    local cmdID = self:getCommandID(button.id)  -- Use button.id for the actual command
    if cmdID then
        reaper.Main_OnCommand(cmdID, 0)
        self:markCommandStateDirty(cmdID)

        if cmdID ~= NOOP_COMMAND_ID and actionNameRequiresAutoArm(button and button.original_text) then
            reaper.ArmCommand(cmdID, "")
            self.armed_command = reaper.GetArmedCommand()
        end

        self:flushDirtyButtonStates()
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
    if cmdID == NOOP_COMMAND_ID then
        return false
    end

    if self.armed_command == cmdID then
        reaper.Main_OnCommand(2020, 0) -- Disarm command
    else
        reaper.ArmCommand(cmdID, "")
    end
    self.armed_command = reaper.GetArmedCommand()
    self:markCommandStateDirty(cmdID)
    self:flushDirtyButtonStates()

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
    -- Full registry/cache wipe; call once after all controllers have unregistered their buttons.
    self.buttons = {}
    self.command_state_cache = {}
    self.toggle_support_cache = {}
    self.state_dirty = {}
    self.toggle_instances = {}
    self.armed_flash_instances = {}
    self.armed_command = nil
    self.flash_state = false
    self.last_toggle_poll_time = 0

    -- Delegate to IconManager
    if C.IconManager then
        C.IconManager:cleanup()
    end
end

return ButtonManager
