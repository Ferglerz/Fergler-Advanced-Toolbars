-- Systems/Button_Definition.lua
-- Defines the structure and properties of toolbar buttons

local ButtonDefinition = {}
ButtonDefinition.__index = ButtonDefinition

function ButtonDefinition.createPropertyKey(id, text)
    text = text:gsub("\\n", "\n")
    text = text:gsub("[\r\n]+", " "):gsub("%s+", " "):match("^%s*(.-)%s*$")
    return id .. "_" .. text
end

function ButtonDefinition.generateInstanceId()
    -- Create a unique ID using system time and random number
    local time_str = tostring(reaper.time_precise()):gsub("%.", "")
    local random_str = tostring(math.random(10000, 99999))
    return "btn_" .. time_str .. "_" .. random_str
end

-- Button factory function
function ButtonDefinition.createButton(id, text)
    local Button = {}
    Button.__index = Button

    local button = setmetatable({}, Button)

    -- Core identification
    button.id = id
    button.instance_id = ButtonDefinition.generateInstanceId() -- Unique per button instance
    button.original_text = text
    button.property_key = ButtonDefinition.createPropertyKey(id, text)
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

    -- Action properties (only for normal buttons)
    if not button.is_separator then
        button.right_click = "arm" -- Default: "arm", can be "none" or "dropdown"
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
    createButton = function(id, text)
        return ButtonDefinition.createButton(id, text)
    end,
    createPropertyKey = function(id, text)
        return ButtonDefinition.createPropertyKey(id, text)
    end,
    generateInstanceId = function()
        return ButtonDefinition.generateInstanceId()
    end
}