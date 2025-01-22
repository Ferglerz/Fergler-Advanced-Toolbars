-- button_group.lua

local ButtonGroup = {}
ButtonGroup.__index = ButtonGroup

function ButtonGroup.new(reaper, helpers)
    local self = setmetatable({}, ButtonGroup)
    self.r = reaper
    self.helpers = helpers

    self.buttons = {}
    self.label = {
        text = "Group",
        position = "below"
    }

    return self
end

function ButtonGroup:updateButtonStates()
    for i, button in ipairs(self.buttons) do
        button.is_section_start = (i == 1)
        button.is_section_end = (i == #self.buttons)
        button.is_alone = (#self.buttons == 1)
    end
end

function ButtonGroup:addButton(button)
    table.insert(self.buttons, button)
    self:updateButtonStates()
end

return {
    new = ButtonGroup.new
}