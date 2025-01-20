-- button_system.lua
local CONFIG = require "Advanced Toolbars - User Config"

local Button = {}
Button.__index = Button

local function createPropertyKey(id, text)
    text = text:gsub("\\n", "\n")
    text = text:gsub("[\r\n]+", " "):gsub("%s+", " "):match("^%s*(.-)%s*$")
    return id .. "_" .. text
end


function Button.new(id, text)
    local self = setmetatable({}, Button)
    self.r = reaper
    
    -- Core identification
    self.id = id
    self.original_text = text
    self.property_key = createPropertyKey(id, text)
    
    -- Get custom properties or initialize defaults
    local custom_props = CONFIG.BUTTON_CUSTOM_PROPERTIES[self.property_key] or {}
    
    -- Display properties
    self.hide_label = custom_props.hide_label or false
    self.display_text = custom_props.name or text
    self.alignment = custom_props.justification or "center"
    self.icon_path = custom_props.icon_path
    self.icon_char = custom_props.icon_char
    self.custom_color = custom_props.custom_color
    
    -- State properties
    self.is_section_start = false
    self.is_section_end = false
    self.is_alone = false
    self.is_separator = (id == "-1")
    self.is_armed = false
    self.is_toggled = false
    self.is_flashing = false
    self.skip_icon = false
    
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

-- ButtonManager class
local ButtonManager = {}
ButtonManager.__index = ButtonManager

function ButtonManager.new(reaper)
    local self = setmetatable({}, ButtonManager)
    self.r = reaper
    self.texture_cache = {}
    self.buttons = {}
    self.command_state_cache = {}
    return self
end

function ButtonManager:clearAllButtonCaches()
    -- Clear texture cache with proper cleanup
    self:clearIconCache()

    -- Clear command state cache
    self.command_state_cache = {}

    -- Clear individual button caches
    for _, button in pairs(self.buttons) do
        button:clearCache()
    end
end

function ButtonManager:getCommandID(action_id)
    if type(action_id) == "string" and action_id:match("^_") then
        return self.r.NamedCommandLookup(action_id)
    else
        return tonumber(action_id)
    end
end

function ButtonManager:getToggleState(button)
    local cmdID = self:getCommandID(button.id)
    if cmdID then
        -- Check cache first
        if self.command_state_cache[cmdID] then
            return self.command_state_cache[cmdID]
        end
        
        -- Get fresh state
        local state = self.r.GetToggleCommandState(cmdID)
        self.command_state_cache[cmdID] = state
        return state
    end
    return -1
end

function ButtonManager:loadIcon(button)
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

    -- Check if file exists before loading
    local file = io.open(button.icon_path, "r")
    if not file then
        button.skip_icon = true
        button.icon_texture = nil
        button.icon_dimensions = nil

        -- Display an error message
        self.r.ShowMessageBox(
            "Icon file not found: " .. button.icon_path ..
            "\nPlease ensure the file exists and is accessible.",
            "Icon Load Error", 0
        )
        return
    end
    file:close()

    -- Check cache for valid texture
    if self.texture_cache[button.icon_path] then
        local cached_texture = self.texture_cache[button.icon_path]
        if self:isValidTexture(cached_texture) then
            button.icon_texture = cached_texture
            button.icon_dimensions = self:getIconDimensions(cached_texture)
            return
        else
            -- Remove invalid texture from cache
            self.texture_cache[button.icon_path] = nil
        end
    end

    -- Load new texture
    local success, texture = pcall(function()
        return self.r.ImGui_CreateImage(button.icon_path)
    end)

    if success and self:isValidTexture(texture) then
        self.texture_cache[button.icon_path] = texture
        button.icon_texture = texture
        button.icon_dimensions = self:getIconDimensions(texture)
    else
        button.skip_icon = true
        button.icon_texture = nil
        button.icon_dimensions = nil

        -- Display an error message
        self.r.ShowMessageBox(
            "Failed to load icon: " .. button.icon_path ..
            "\nPlease ensure the file is a valid image format.",
            "Icon Load Error", 0
        )
    end
end


function ButtonManager:isValidTexture(texture)
    if not texture then return false end
    
    local success, width, height = pcall(function()
        return self.r.ImGui_Image_GetSize(texture)
    end)
    
    return success and width and height and width > 0 and height > 0
end

function ButtonManager:getIconDimensions(texture)
    if not self:isValidTexture(texture) then return nil end
    
    local success, w, h = pcall(function()
        return self.r.ImGui_Image_GetSize(texture)
    end)
    
    if not success or not w or not h then return nil end
    
    local max_height = CONFIG.SIZES.HEIGHT - (CONFIG.ICON_FONT.PADDING * 2)
    
    local scale = math.min(1, max_height / h)
    return {
        width = math.floor(w * scale * CONFIG.ICON_FONT.SCALE),
        height = math.floor(h * scale * CONFIG.ICON_FONT.SCALE)
    }
end

function ButtonManager:clearIconCache()
    -- Simply clear the cache table - REAPER/ImGui handles cleanup
    self.texture_cache = {}
    
    -- Clear icon-related caches in all buttons
    for _, button in pairs(self.buttons) do
        button.icon_texture = nil
        button.icon_dimensions = nil
        button.skip_icon = false
    end
end

function ButtonManager:updateButtonState(button, armed_action, flash_state)
    local command_id = self:getCommandID(button.id)
    
    -- Get armed command directly from REAPER for Main section
    local main_armed = self.r.GetArmedCommand()
    
    button.is_armed = (main_armed == command_id)
    button.is_toggled = (self:getToggleState(button) == 1)
    button.is_flashing = (button.is_armed and flash_state)
end

function ButtonManager:executeCommand(button)
    local cmdID = self:getCommandID(button.id)
    if cmdID then
        self.r.Main_OnCommand(cmdID, 0)
        -- Clear command state cache for this command
        self.command_state_cache[cmdID] = nil
        return true
    end
    return false
end

function ButtonManager:handleRightClick(button)
    local cmdID = self:getCommandID(button.id)
    if cmdID then
        -- Get the state BEFORE any changes
        local pre_armed = self.r.GetArmedCommand()

        -- Make the change
        if pre_armed == cmdID then
            self.r.Main_OnCommand(2020, 0)  -- Disarm current action
        else
            self.r.ArmCommand(cmdID, "Main")  -- Arm this button's command
        end
    end
end

function ButtonManager:cleanup()
    -- Simply clear all caches - REAPER will handle texture cleanup
    self.texture_cache = {}
    self.buttons = {}
    self.command_state_cache = {}
end

return {
    Button = Button,
    ButtonManager = ButtonManager,
    createPropertyKey = createPropertyKey
}
