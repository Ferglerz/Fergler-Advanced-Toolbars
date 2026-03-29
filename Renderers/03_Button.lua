-- Renderers/03_Button.lua
-- Button renderer: merges implementation fragments from 03_Button_*.lua

local ButtonRenderer = {}
ButtonRenderer.__index = ButtonRenderer

local function merge_methods(target, fragment)
    for k, v in pairs(fragment) do
        target[k] = v
    end
end

function ButtonRenderer.new()
    local self = setmetatable({}, ButtonRenderer)
    self.cached_shadow_color = nil
    return self
end

merge_methods(ButtonRenderer, require("Renderers.03_Button_separator"))
merge_methods(ButtonRenderer, require("Renderers.03_Button_insertion"))
merge_methods(ButtonRenderer, require("Renderers.03_Button_main"))

return ButtonRenderer.new()
