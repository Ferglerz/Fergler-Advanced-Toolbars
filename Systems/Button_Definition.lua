-- Systems/Button_Definition.lua
-- Defines the structure and properties of toolbar buttons

local ButtonDefinition = {}
ButtonDefinition.__index = ButtonDefinition

-- Move the createPropertyKey function inside the ButtonDefinition namespace
function ButtonDefinition.createPropertyKey(id, text)
    text = text:gsub("\\n", "\n")
    text = text:gsub("[\r\n]+", " "):gsub("%s+", " "):match("^%s*(.-)%s*$")
    return id .. "_" .. text
end

-- Button factory function
function ButtonDefinition.createButton(id, text)
    local Button = {}
    Button.__index = Button

    local button = setmetatable({}, Button)

    -- Core identification
    button.id = id
    button.original_text = text
    button.property_key = ButtonDefinition.createPropertyKey(id, text)
    button.parent_toolbar = nil

    -- Display properties
    button.hide_label = false
    button.display_text = text
    button.alignment = "center"
    button.icon_path = nil
    button.icon_char = nil
    button.icon_font = nil
    button.custom_color = nil

    -- Action properties
    button.right_click = "arm" -- Default: "arm", can be "none" or "dropdown"
    button.right_click_action = nil
    button.dropdown_menu = {} -- Dropdown menu items

    -- Layout properties
    button.is_section_start = false
    button.is_section_end = false
    button.is_alone = false
    button.is_separator = (id == "-1")
    button.parent_group = nil

    -- Widget properties
    button.widget = nil

    -- State flags (managed externally by ButtonManager)
    button.is_armed = false
    button.is_toggled = false
    button.is_flashing = false
    button.is_hovered = false
    button.is_right_clicked = false

    -- Rendering cache
    button.cached_width = nil
    button.icon_texture = nil
    button.icon_dimensions = nil
    button.screen_coords = nil

    -- Dirty flags for rendering optimization
    button.is_dirty = true        -- Visual state dirty flag 
    button.layout_dirty = true    -- Layout-affecting changes flag
    button.previous_state = {
        is_armed = false,
        is_toggled = false,
        is_flashing = false,
        is_hovered = false
    }

    -- Attach methods to button
    button.clearCache = function(self)
        self.cached_width = nil
        self.icon_dimensions = nil
        self.icon_texture = nil
        self.screen_coords = nil
        self.is_dirty = true
        self.layout_dirty = true
        
        -- If parent group exists, mark it for recalculation
        if self.parent_group then
            self.parent_group:clearCache()
        end
    end

    button.checkStateChanged = function(self)
        local state_keys = {"is_armed", "is_toggled", "is_flashing", "is_hovered"}
        for _, key in ipairs(state_keys) do
            if self.previous_state[key] ~= self[key] then
                -- Update all previous states
                for _, k in ipairs(state_keys) do
                    self.previous_state[k] = self[k]
                end
                self.is_dirty = true
                return true
            end
        end
        return self.is_dirty
    end

    button.markClean = function(self)
        self.is_dirty = false
        self.layout_dirty = false
    end
    
    button.saveChanges = function(self)
        if self.parent_toolbar then
            CONFIG_MANAGER:saveToolbarConfig(self.parent_toolbar)
        end
        return false
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
    end
}
