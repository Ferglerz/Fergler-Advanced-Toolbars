-- button_group.lua

local ButtonGroup = {}
ButtonGroup.__index = ButtonGroup

function ButtonGroup.new(reaper, helpers)
    local self = setmetatable({}, ButtonGroup)
    self.r = reaper
    self.helpers = helpers
    self.buttons = {}
    self.label = {text = "", position = "below"}
    self.cached_dimensions = nil
    return self
end

function ButtonGroup:updateButtonStates()
    for i, button in ipairs(self.buttons) do
        button.is_section_start = (i == 1)
        button.is_section_end = (i == #self.buttons)
        button.is_alone = (#self.buttons == 1)
        button.group = self
    end
    self:clearCache()
end

function ButtonGroup:addButton(button)
    table.insert(self.buttons, button)
    self:updateButtonStates()
end

function ButtonGroup:removeButton(index)
    if index > 0 and index <= #self.buttons then
        table.remove(self.buttons, index)
        self:updateButtonStates()
        return true
    end
    return false
end

function ButtonGroup:moveButton(from_index, to_index)
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

function ButtonGroup:setLabel(text, position)
    self.label.text = text or ""
    if position then self.label.position = position end
    self:clearCache()
end

function ButtonGroup:cacheDimensions(width, height)
    self.cached_dimensions = {width = width, height = height}
end

function ButtonGroup:getDimensions()
    return self.cached_dimensions
end

function ButtonGroup:clearCache()
    self.cached_dimensions = nil
    for _, button in ipairs(self.buttons) do
        if button.clearCache then button:clearCache() end
    end
end

function ButtonGroup:getButtons()
    return self.buttons
end

function ButtonGroup:getButtonCount()
    return #self.buttons
end

function ButtonGroup:isEmpty()
    return #self.buttons == 0
end

function ButtonGroup:hasLabel()
    return self.label.text and #self.label.text > 0
end

return {
    new = ButtonGroup.new
}
