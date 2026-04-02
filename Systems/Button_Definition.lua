-- Systems/Button_Definition.lua
-- Defines the structure and properties of toolbar buttons

local ButtonDefinition = {}
ButtonDefinition.__index = ButtonDefinition

--- Built-in REAPER command id used for placeholder / no-op toolbar slots.
local NOOP_ACTION_ID = "65535"

function ButtonDefinition.createPropertyKey(id, text, position)
    text = text:gsub("\\n", "\n")
    text = text:gsub("[\r\n]+", " "):gsub("%s+", " "):match("^%s*(.-)%s*$")
    -- Use position to make each button instance have a unique but stable property key
    if position then
        return id .. "_" .. text .. "_pos" .. position
    else
        -- Fallback for buttons created without position (like new buttons being added)
        return ID_GENERATOR.generateButtonInstanceId(id .. "_" .. text)
    end
end

function ButtonDefinition.generateInstanceId()
    return ID_GENERATOR.generateButtonId()
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

function ButtonDefinition.createNoopButton(text, position)
    return ButtonDefinition.createButton(NOOP_ACTION_ID, text or "No-op (no action)", position)
end

--- Copy custom colors and related styling from one button to another (e.g. insertion / new button).
function ButtonDefinition.copyCustomColorProperties(source_button, target_button)
    if not source_button then
        return
    end

    local default_state = source_button:isSeparator() and "SEPARATOR" or "NORMAL"
    local default_colors = CONFIG.COLORS[default_state]

    target_button.custom_color = {}

    if source_button.custom_color and source_button.custom_color.background and source_button.custom_color.background.normal then
        target_button.custom_color.background = {
            normal = source_button.custom_color.background.normal
        }
    elseif default_colors and default_colors.BG then
        target_button.custom_color.background = {
            normal = default_colors.BG.NORMAL
        }
    end

    if source_button.custom_color and source_button.custom_color.border and source_button.custom_color.border.normal then
        target_button.custom_color.border = {
            normal = source_button.custom_color.border.normal
        }
    elseif default_colors and default_colors.BORDER then
        target_button.custom_color.border = {
            normal = default_colors.BORDER.NORMAL
        }
    end

    if source_button.custom_color and source_button.custom_color.text and source_button.custom_color.text.normal then
        target_button.custom_color.text = {
            normal = source_button.custom_color.text.normal
        }
    elseif default_colors and default_colors.TEXT then
        target_button.custom_color.text = {
            normal = default_colors.TEXT.NORMAL
        }
    end

    if source_button.custom_color and source_button.custom_color.icon and source_button.custom_color.icon.normal then
        target_button.custom_color.icon = {
            normal = source_button.custom_color.icon.normal
        }
    elseif default_colors and default_colors.ICON then
        target_button.custom_color.icon = {
            normal = default_colors.ICON.NORMAL
        }
    end

    if source_button.custom_color and source_button.custom_color.hover then
        target_button.custom_color.hover = {}
        if source_button.custom_color.hover.background then
            target_button.custom_color.hover.background = source_button.custom_color.hover.background
        elseif default_colors and default_colors.BG and default_colors.BG.HOVER then
            target_button.custom_color.hover.background = default_colors.BG.HOVER
        end
        if source_button.custom_color.hover.border then
            target_button.custom_color.hover.border = source_button.custom_color.hover.border
        elseif default_colors and default_colors.BORDER and default_colors.BORDER.HOVER then
            target_button.custom_color.hover.border = default_colors.BORDER.HOVER
        end
    elseif default_colors and default_colors.BG and (default_colors.BG.HOVER or default_colors.BORDER and default_colors.BORDER.HOVER) then
        target_button.custom_color.hover = {}
        if default_colors.BG.HOVER then
            target_button.custom_color.hover.background = default_colors.BG.HOVER
        end
        if default_colors.BORDER and default_colors.BORDER.HOVER then
            target_button.custom_color.hover.border = default_colors.BORDER.HOVER
        end
    end

    if source_button.custom_color and source_button.custom_color.active then
        target_button.custom_color.active = {}
        if source_button.custom_color.active.background then
            target_button.custom_color.active.background = source_button.custom_color.active.background
        elseif default_colors and default_colors.BG and default_colors.BG.CLICKED then
            target_button.custom_color.active.background = default_colors.BG.CLICKED
        end
        if source_button.custom_color.active.border then
            target_button.custom_color.active.border = source_button.custom_color.active.border
        elseif default_colors and default_colors.BORDER and default_colors.BORDER.CLICKED then
            target_button.custom_color.active.border = default_colors.BORDER.CLICKED
        end
    elseif default_colors and default_colors.BG and (default_colors.BG.CLICKED or default_colors.BORDER and default_colors.BORDER.CLICKED) then
        target_button.custom_color.active = {}
        if default_colors.BG.CLICKED then
            target_button.custom_color.active.background = default_colors.BG.CLICKED
        end
        if default_colors.BORDER and default_colors.BORDER.CLICKED then
            target_button.custom_color.active.border = default_colors.BORDER.CLICKED
        end
    end

    if source_button.user_colors then
        target_button.user_colors = {}
        for key, value in pairs(source_button.user_colors) do
            target_button.user_colors[key] = value
        end
    end

    if source_button.border_offset then
        target_button.border_offset = {
            saturation = source_button.border_offset.saturation or 0.0,
            value = source_button.border_offset.value or 0.0
        }
    end
end

-- Return the module with the factory pattern
return {
    NOOP_ACTION_ID = NOOP_ACTION_ID,
    createButton = function(id, text, position)
        return ButtonDefinition.createButton(id, text, position)
    end,
    createNoopButton = function(text, position)
        return ButtonDefinition.createNoopButton(text, position)
    end,
    copyCustomColorProperties = function(source_button, target_button)
        return ButtonDefinition.copyCustomColorProperties(source_button, target_button)
    end,
    createPropertyKey = function(id, text, position)
        return ButtonDefinition.createPropertyKey(id, text, position)
    end,
    generateInstanceId = function()
        return ButtonDefinition.generateInstanceId()
    end
}