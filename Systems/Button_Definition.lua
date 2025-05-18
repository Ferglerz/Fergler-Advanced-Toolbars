-- Systems/Button_Definition.lua
-- Defines the structure and properties of toolbar buttons

local ButtonDefinition = {}
ButtonDefinition.__index = ButtonDefinition

function ButtonDefinition.createPropertyKey(id, text)
    text = text:gsub("\\n", "\n")
    text = text:gsub("[\r\n]+", " "):gsub("%s+", " "):match("^%s*(.-)%s*$")
    
    local uniqueTimestamp = os.time() .. "_" .. math.random(1000, 9999)
    
    return id .. "_" .. text .. "_" .. uniqueTimestamp
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

    -- Consolidated cache object for all cached values
    button.cache = {
        -- Layout caching
        width = nil,
        
        -- Icon caching
        icon = {
            font = nil,
            texture = nil,
            dimensions = nil
        },
        
        -- Positioning
        screen_coords = nil,
        
        -- Visual effects
        shadow_color = nil,
        
        -- Colors
        colors = {
            state_key = nil,
            mouse_key = nil,
            bg_color = nil,
            border_color = nil,
            icon_color = nil,
            text_color = nil
        },
        
        -- Text rendering
        text_width = nil,
        line_widths = nil,
        lines = nil
    }

    button.layout_dirty = true

    button.clearCache = function(self)
        -- Initialize the cache with all required fields to avoid nil references
        self.cache = {
            width = nil,
            
            icon = {
                font = nil,
                texture = nil,
                dimensions = nil
            },
            
            screen_coords = nil,
            shadow_color = nil,
            
            colors = {
                state_key = nil,
                mouse_key = nil,
                bg_color = nil,
                border_color = nil,
                icon_color = nil,
                text_color = nil
            },
            
            text_width = nil,
            line_widths = nil,
            lines = {} -- Initialize as an empty table, not nil
        }
        
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
