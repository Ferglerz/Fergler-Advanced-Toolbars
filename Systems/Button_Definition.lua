-- Systems/Button_Definition.lua
-- Defines the structure and properties of toolbar buttons

local ButtonDefinition = {}
ButtonDefinition.__index = ButtonDefinition

function ButtonDefinition.createPropertyKey(id, text, position)
    text = text:gsub("\\n", "\n")
    text = text:gsub("[\r\n]+", " "):gsub("%s+", " "):match("^%s*(.-)%s*$")
    -- Use position to make each button instance have a unique but stable property key
    if position then
        return id .. "_" .. text .. "_pos" .. position
    else
        -- Fallback for buttons created without position (like new buttons being added)
        local time_str = tostring(reaper.time_precise()):gsub("%.", "")
        local random_str = tostring(math.random(10000, 99999))
        return id .. "_" .. text .. "_" .. time_str .. "_" .. random_str
    end
end

function ButtonDefinition.generateInstanceId()
    -- Create a unique ID using system time and random number
    local time_str = tostring(reaper.time_precise()):gsub("%.", "")
    local random_str = tostring(math.random(10000, 99999))
    return "btn_" .. time_str .. "_" .. random_str
end

-- Get default right-click behavior based on command type
function ButtonDefinition.getDefaultRightClickBehavior(id)
    -- Convert ID to command ID for checking
    local command_id
    if type(id) == "string" and id:match("^_") then
        command_id = reaper.NamedCommandLookup(id)
    else
        command_id = tonumber(id)
    end
    
    -- If we have a valid command ID, check if it's a toggle command
    if command_id and command_id > 0 then
        local toggle_state = reaper.GetToggleCommandState(command_id)
        -- If command supports toggling (returns 0 or 1), default to "none"
        if toggle_state >= 0 then
            return "none"
        end
    end
    
    -- Default to "arm" for non-toggle commands
    return "arm"
end

-- Button factory function
function ButtonDefinition.createButton(id, text, position)
    local Button = {}
    Button.__index = Button

    local button = setmetatable({}, Button)

    -- Core identification
    button.id = id
    button.instance_id = ButtonDefinition.generateInstanceId() -- Unique per button instance
    button.original_text = text
    button.property_key = ButtonDefinition.createPropertyKey(id, text, position)
    button.parent_toolbar = nil

    -- Button type determination
    button.button_type = (id == "-1") and "separator" or "normal"
    button.is_separator = (button.button_type == "separator")
    
    -- Separator indexing (assigned during toolbar parsing)
    button.separator_index = nil

    -- Display properties
    button.hide_label = false
    button.display_text = text
    button.alignment = "center"
    button.icon_path = nil
    button.icon_char = nil
    button.icon_font = nil
    button.custom_color = nil
    button.border_offset = { saturation = 0.0, value = 0.0 } -- HSV offset for border when linked to background

    -- Action properties (only for normal buttons)
    if not button.is_separator then
        -- Set default right-click behavior based on command type
        button.right_click = ButtonDefinition.getDefaultRightClickBehavior(id)
        button.right_click_action = nil
        button.dropdown_menu = {} -- Dropdown menu items
        button.widget = nil -- Widget properties
    else
        -- Separators have limited interaction
        button.right_click = "none"
        button.right_click_action = nil
        button.dropdown_menu = nil
        button.widget = nil
    end

    -- Layout properties
    button.is_section_start = false
    button.is_section_end = false
    button.is_alone = false
    button.parent_group = nil

    -- State flags (managed externally by ButtonManager)
    button.is_armed = false
    button.is_toggled = false
    button.is_flashing = false
    button.is_hovered = false
    button.is_right_clicked = false

    button.cache = {}
    button.layout_dirty = true

    -- Attach methods to button
    button.clearCache = function(self)
        self.cache = {}
        self.layout_dirty = true
        
        -- If parent group exists, mark it for recalculation
        if self.parent_group then
            self.parent_group:clearCache()
        end
    end
    
    -- Selective cache clearing - only clear layout cache, preserve colors
    button.clearLayoutCache = function(self)
        if self.cache.layout then
            self.cache.layout = nil
        end
        if self.cache.text then
            self.cache.text = nil
        end
        if self.cache.icon then
            self.cache.icon = nil
        end
        if self.cache.icon_font then
            self.cache.icon_font = nil
        end
        self.layout_dirty = true
        
        -- If parent group exists, mark it for recalculation
        if self.parent_group then
            self.parent_group:clearCache()
        end
    end
    
    -- Clear only color cache when colors change
    button.clearColorCache = function(self)
        if self.cache.colors then
            self.cache.colors = nil
        end
    end

    -- Check if layout needs recalculation
    button.isLayoutDirty = function(self)
        return self.layout_dirty
    end

    -- Mark layout as clean
    button.markLayoutClean = function(self)
        self.layout_dirty = false
    end
    
    button.saveChanges = function(self)
        if self.parent_toolbar then
            CONFIG_MANAGER:saveToolbarConfig(self.parent_toolbar)
        end
        return false
    end

    -- Separator-specific methods
    button.isSeparator = function(self)
        return self.button_type == "separator"
    end

    button.isNormalButton = function(self)
        return self.button_type == "normal"
    end

    return button
end

-- Return the module with the factory pattern
return {
    createButton = function(id, text, position)
        return ButtonDefinition.createButton(id, text, position)
    end,
    createPropertyKey = function(id, text, position)
        return ButtonDefinition.createPropertyKey(id, text, position)
    end,
    generateInstanceId = function()
        return ButtonDefinition.generateInstanceId()
    end
}