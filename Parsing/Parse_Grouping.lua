-- Parsing/Parse_Grouping.lua

local ButtonGrouping = {}
ButtonGrouping.__index = ButtonGrouping

function ButtonGrouping.new()
    local self = setmetatable({}, ButtonGrouping)
    self.buttons = {}
    self.group_label = {text = "", position = "below"}
    self.is_split_point = false
    
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
    for i, button in ipairs(self.buttons) do
        button.is_section_start = (i == 1)
        button.is_section_end = (i == #self.buttons)
        button.is_alone = (#self.buttons == 1)
        button.parent_group = self
        
        -- Fix issue #5: Only non-separator buttons should get visual end treatment
        if not button:isSeparator() then
            -- Check if this is the last non-separator button in the group
            local is_visual_end = true
            for j = i + 1, #self.buttons do
                if not self.buttons[j]:isSeparator() then
                    is_visual_end = false
                    break
                end
            end
            button.is_visual_section_end = is_visual_end
            
            -- Check if this is the first non-separator button in the group
            local is_visual_start = true
            for j = 1, i - 1 do
                if not self.buttons[j]:isSeparator() then
                    is_visual_start = false
                    break
                end
            end
            button.is_visual_section_start = is_visual_start
        else
            button.is_visual_section_end = false
            button.is_visual_section_start = false
        end
        
        -- Separators at the end of groups get special handling for visual continuity
        if button:isSeparator() and button.is_section_end then
            -- This separator bridges to the next group, so it might need special styling
            button.is_group_bridge = true
        else
            button.is_group_bridge = false
        end
    end
    self:clearCache()
end

-- UNUSED
function ButtonGrouping:removeButton(index)
    if index > 0 and index <= #self.buttons then
        table.remove(self.buttons, index)
        self:updateButtonStates()
        return true
    end
    return false
end

-- UNUSED
function ButtonGrouping:moveButton(from_index, to_index)
    if from_index > 0 and from_index <= #self.buttons and 
       to_index > 0 and to_index <= #self.buttons and
       from_index ~= to_index then
        local button = table.remove(self.buttons, from_index)
        if to_index > from_index then
            to_index = to_index - 1
        end
        table.insert(self.buttons, to_index, button)
        self:updateButtonStates()
        return true
    end
    return false
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