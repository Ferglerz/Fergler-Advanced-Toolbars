-- Parsing/Parse_Grouping.lua

local ButtonGrouping = {}
ButtonGrouping.__index = ButtonGrouping

function ButtonGrouping.new()
    local self = setmetatable({}, ButtonGrouping)
    self.buttons = {}
    self.group_label = {text = "", position = "below"}
    self.is_split_point_h = false
    self.is_split_point_v = false
    
    -- Simple cache
    self.cache = {}
    
    return self
end

function ButtonGrouping:addButton(button)
    table.insert(self.buttons, button)
    button.parent_group = self
    self:updateButtonStates()
end

function ButtonGrouping:updateButtonStates()
    local n = #self.buttons
    local first_non_sep, last_non_sep = nil, nil
    for i, button in ipairs(self.buttons) do
        if not button:isSeparator() then
            if not first_non_sep then
                first_non_sep = i
            end
            last_non_sep = i
        end
    end

    for i, button in ipairs(self.buttons) do
        button.is_section_start = (i == 1)
        button.is_section_end = (i == n)
        button.is_alone = (n == 1)
        button.parent_group = self

        if not button:isSeparator() then
            button.is_visual_section_end = (i == last_non_sep)
            button.is_visual_section_start = (i == first_non_sep)
        else
            button.is_visual_section_end = false
            button.is_visual_section_start = false
        end

        button.is_group_bridge = button:isSeparator() and button.is_section_end
    end
    self:clearCache()
end

function ButtonGrouping:setLabel(text, position)
    self.group_label.text = text or ""
    if position then self.group_label.position = position end
    self:clearCache()
end

function ButtonGrouping:cacheDimensions(width, height, is_vertical, available_width, label_height, content_height)
    if not self.cache.dimensions then
        self.cache.dimensions = {}
    end
    
    self.cache.dimensions.width = width
    self.cache.dimensions.height = height
    self.cache.dimensions.is_vertical = is_vertical
    self.cache.dimensions.available_width = available_width
    self.cache.dimensions.label_height = label_height
    self.cache.dimensions.content_height = content_height
end

function ButtonGrouping:getDimensions()
    return self.cache.dimensions
end

function ButtonGrouping:clearCache()
    self.cache = {}
    
    for _, button in ipairs(self.buttons) do
        if button then
            button.layout_dirty = true
            
            -- Clear layout cache
            if button.cache.layout then
                button.cache.layout = nil
            end
        end
    end
end

function ButtonGrouping:getButtons()
    return self.buttons
end

return ButtonGrouping