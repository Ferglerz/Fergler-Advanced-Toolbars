-- button_system.lua

-- Class
local Button = {}
Button.__index = Button

local function createPropertyKey(id, text)
    text = text:gsub("\\n", "\n")
    text = text:gsub("[\r\n]+", " "):gsub("%s+", " "):match("^%s*(.-)%s*$")
    return id .. "_" .. text
end

function Button.new(id, text)
    local self = setmetatable({}, Button)

    -- Core identification
    self.id = id
    self.original_text = text
    self.property_key = createPropertyKey(id, text)

    -- Display properties (defaults only - custom properties are loaded by parser)
    self.hide_label = false
    self.display_text = text
    self.alignment = "center"
    self.icon_path = nil
    self.icon_char = nil
    self.icon_font = nil
    self.custom_color = nil

    -- Action properties
    self.right_click = "arm" -- Default: "arm", can be "none" or "dropdown"
    self.dropdown = nil

    -- State properties
    self.is_section_start = false
    self.is_section_end = false
    self.is_alone = false
    self.is_separator = (id == "-1")
    self.is_armed = false
    self.is_toggled = false
    self.is_flashing = false
    self.skip_icon = false
    self.group = nil -- Reference to parent group

    -- Cached rendering properties
    self.cached_width = nil
    self.icon_texture = nil
    self.icon_dimensions = nil

    return self
end

function Button:clearCache()
    self.cached_width = nil
    self.icon_dimensions = nil
    self.skip_icon = false
    self.icon_texture = nil
end

-- ButtonState class (consolidated with state management)
local ButtonState = {}
ButtonState.__index = ButtonState

function ButtonState.new(reaper)
    local self = setmetatable({}, ButtonState)
    self.r = reaper

    -- Button management
    self.texture_cache = {}
    self.buttons = {}

    -- State management
    self.command_state_cache = {}
    self.armed_command = nil
    self.flash_state = false
    self.hover_start_times = {}

    return self
end

-- State management methods
function ButtonState:updateArmedCommand()
    self.armed_command = self.r.GetArmedCommand()
end

function ButtonState:updateFlashState()
    local flash_interval = CONFIG.UI.FLASH_INTERVAL or 0.5
    local current_time = self.r.time_precise()
    self.flash_state = math.floor(current_time / (flash_interval / 2)) % 2 == 0
    return self.flash_state
end

function ButtonState:getCommandID(action_id)
    if type(action_id) == "string" and action_id:match("^_") then
        return self.r.NamedCommandLookup(action_id)
    else
        return tonumber(action_id)
    end
end

function ButtonState:getToggleState(button)
    local cmdID = self:getCommandID(button.id)
    if not cmdID then
        return -1
    end

    -- Use cached state if available
    if self.command_state_cache[cmdID] == nil then
        self.command_state_cache[cmdID] = self.r.GetToggleCommandState(cmdID)
    end

    return self.command_state_cache[cmdID]
end

-- Optimized button state update
function ButtonState:updateButtonState(button)
    local command_id = self:getCommandID(button.id)

    -- Get armed command using stored value
    button.is_armed = (self.armed_command == command_id)

    -- Get toggle state with caching
    button.is_toggled = (self:getToggleState(button) == 1)

    -- Set flash state
    button.is_flashing = (button.is_armed and self.flash_state)
end

-- Optimized update for all buttons
function ButtonState:updateAllButtonStates()
    -- Get armed command once
    self.armed_command = self.r.GetArmedCommand()

    -- Update flash state once
    self.flash_state = self:updateFlashState()

    -- Update all buttons efficiently
    for _, button in pairs(self.buttons) do
        self:updateButtonState(button)
    end
end

function ButtonState:trackHoverState(ctx, button_id, is_hovered)
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

-- Helper function to execute commands
function ButtonState:executeCommand(action_id)
    local cmdID = self:getCommandID(action_id)
    if cmdID then
        self.r.Main_OnCommand(cmdID, 0)
        return true
    end
    return false
end

-- Button interaction
function ButtonState:buttonClicked(button, is_right_click)
    if is_right_click then
        -- Check the right-click behavior
        if button.right_click == "arm" then
            -- Get the state BEFORE any changes
            local pre_armed = self.r.GetArmedCommand()
            local cmdID = self:getCommandID(button.id)
            
            if not cmdID then
                return false
            end

            -- Make the change
            if pre_armed == cmdID then
                self.r.Main_OnCommand(2020, 0) -- Disarm current action
            else
                self.r.ArmCommand(cmdID, "Main") -- Arm this button's command
            end
        elseif button.right_click == "dropdown" then
            -- The dropdown will be handled by the UI rendering code
            return true
        elseif button.right_click == "none" then
            -- Do nothing for "none" behavior
            return false
        end
    else
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

-- Icon management
function ButtonState:isValidTexture(texture)
    if not texture then
        return false
    end

    local success, width, height =
        pcall(
        function()
            return self.r.ImGui_Image_GetSize(texture)
        end
    )

    return success and width and height and width > 0 and height > 0
end

function ButtonState:getIconDimensions(texture)
    if not self:isValidTexture(texture) then
        return nil
    end

    local success, w, h =
        pcall(
        function()
            return self.r.ImGui_Image_GetSize(texture)
        end
    )

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

-- Normalize path based on OS
function ButtonState:normalizeIconPath(path)
    local normalized = path:gsub("\\", "/")
    return normalized
end

-- Check if file exists
function ButtonState:fileExists(path)
    local file = io.open(path, "r")
    if file then
        file:close()
        return path
    end

    -- Try Windows path if on Windows
    if self.r.GetOS():match("Win") then
        local win_path = path:gsub("/", "\\")
        file = io.open(win_path, "r")
        if file then
            file:close()
            return win_path -- Return the working path
        end
    end

    return false
end

-- Handle missing icon
function ButtonState:handleMissingIcon(button)
    button.skip_icon = true
    button.icon_texture = nil
    button.icon_dimensions = nil

    -- Display an error message
    self.r.ShowMessageBox(
        "Icon file not found: " .. button.icon_path .. "\nPlease ensure the file exists and is accessible.",
        "Icon Load Error",
        0
    )
end

-- Use cached texture if available
function ButtonState:useCachedTexture(button, normalized_path)
    if self.texture_cache[normalized_path] then
        local cached_texture = self.texture_cache[normalized_path]
        if self:isValidTexture(cached_texture) then
            button.icon_texture = cached_texture
            button.icon_dimensions = self:getIconDimensions(cached_texture)
            return true
        else
            -- Remove invalid texture from cache
            self.texture_cache[normalized_path] = nil
        end
    end
    return false
end

-- Load new texture
function ButtonState:loadNewTexture(button, normalized_path)
    local success, texture =
        pcall(
        function()
            return self.r.ImGui_CreateImage(normalized_path)
        end
    )

    if success and self:isValidTexture(texture) then
        self.texture_cache[normalized_path] = texture
        button.icon_texture = texture
        button.icon_dimensions = self:getIconDimensions(texture)
    else
        button.skip_icon = true
        button.icon_texture = nil
        button.icon_dimensions = nil

        -- Display an error message
        self.r.ShowMessageBox(
            "Failed to load icon: " .. button.icon_path .. "\nPlease ensure the file is a valid image format.",
            "Icon Load Error",
            0
        )
    end
end

function ButtonState:loadIcon(button)
    -- Early return if no icon or if we should skip
    if (not button.icon_path and not button.icon_char) or button.skip_icon then
        button.icon_texture = nil
        button.icon_dimensions = nil
        return
    end

    -- Only try to load image icons, not character icons
    if not button.icon_path then
        button.icon_texture = nil
        button.icon_dimensions = nil
        return
    end

    -- Normalize path and check if file exists
    local normalized_path = self:normalizeIconPath(button.icon_path)
    local exists_path = self:fileExists(normalized_path)

    if not exists_path then
        self:handleMissingIcon(button)
        return
    end

    -- Store normalized path back to button
    button.icon_path = exists_path

    -- Check cache for valid texture
    if self:useCachedTexture(button, exists_path) then
        return
    end

    -- Load new texture
    self:loadNewTexture(button, exists_path)
end

-- Cache management
function ButtonState:clearIconCache()
    -- Simply clear the cache table - REAPER/ImGui handles cleanup
    self.texture_cache = {}

    -- Clear icon-related caches in all buttons
    for _, button in pairs(self.buttons) do
        button.icon_texture = nil
        button.icon_dimensions = nil
        button.skip_icon = false
    end
end

function ButtonState:clearAllButtonCaches()
    -- Clear texture cache with proper cleanup
    self:clearIconCache()

    -- Clear command state cache
    self.command_state_cache = {}

    -- Clear individual button caches
    for _, button in pairs(self.buttons) do
        button:clearCache()
    end

    -- Clear hover states
    self.hover_start_times = {}
end

function ButtonState:cleanup()
    -- Clear all caches - REAPER will handle texture cleanup
    self.texture_cache = {}
    self.buttons = {}
    self.command_state_cache = {}
    self.hover_start_times = {}
end

return {
    Button = Button,
    ButtonState = ButtonState,
    createPropertyKey = createPropertyKey
}