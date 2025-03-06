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

    -- Display properties
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

    -- State properties - managed by ButtonStateManager
    self.is_section_start = false
    self.is_section_end = false
    self.is_alone = false
    self.is_separator = (id == "-1")
    self.is_armed = false
    self.is_toggled = false
    self.is_flashing = false
    self.is_hovered = false
    self.is_right_clicked = false
    self.group = nil -- Reference to parent group

    -- Cached rendering properties
    self.cached_width = nil
    self.icon_texture = nil
    self.icon_dimensions = nil
    
    -- Dirty flags
    self.is_dirty = true
    self.previous_state = {
        is_armed = false,
        is_toggled = false,
        is_flashing = false,
        is_hovered = false
    }

    return self
end

function Button:clearCache()
    self.cached_width = nil
    self.icon_dimensions = nil
    self.icon_texture = nil
    self.screen_coords = nil
    self.is_dirty = true
end

function Button:checkStateChanged()
    -- Check if any state that affects rendering changed
    local state_changed = 
        self.previous_state.is_armed ~= self.is_armed or
        self.previous_state.is_toggled ~= self.is_toggled or
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

function Button:markClean()
    self.is_dirty = false
end

return {
    Button = Button,
    createPropertyKey = createPropertyKey
}