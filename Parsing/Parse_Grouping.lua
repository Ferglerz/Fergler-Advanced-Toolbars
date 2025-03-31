-- Parsing/Parse_Grouping.lua

local ButtonGrouping = {}
ButtonGrouping.__index = ButtonGrouping

function ButtonGrouping.new()
    local self = setmetatable({}, ButtonGrouping)
    self.buttons = {}
    self.group_label = {text = "", position = "below"}
    self.cached_dimensions = nil
    self.is_split_point = false
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

function ButtonGrouping:cacheDimensions(width, height)
    self.cached_dimensions = {width = width, height = height}
end

function ButtonGrouping:getDimensions()
    return self.cached_dimensions
end

function ButtonGrouping:clearCache()
    self.cached_dimensions = nil
    self.group_label_cache = nil
    for _, button in ipairs(self.buttons) do
        if button.clearCache then button:clearCache() end
    end
end

function ButtonGrouping:getButtons()
    return self.buttons
end


return ButtonGrouping