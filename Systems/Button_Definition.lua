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
    button.is_dirty = true
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
    end

    button.checkStateChanged = function(self)
        -- Check if any state that affects rendering changed
        local state_changed =
            self.previous_state.is_armed ~= self.is_armed or self.previous_state.is_toggled ~= self.is_toggled or
            self.previous_state.is_flashing ~= self.is_flashing or
            self.previous_state.is_hovered ~= self.is_hovered

        -- Update the previous state for next check
        self.previous_state.is_armed = self.is_armed
        self.previous_state.is_toggled = self.is_toggled
        self.previous_state.is_flashing = self.is_flashing
        self.previous_state.is_hovered = self.is_hovered

        if state_changed then
            self.is_dirty = true
        end

        return self.is_dirty
    end

    button.markClean = function(self)
        self.is_dirty = false
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
