-- Renderers/03_Button.lua
-- Button renderer: implementation split across 03_Button_*.lua (loaded into ButtonRenderer)

local FRAGMENT_LOADER = require("Utils.Core.fragment_loader")

local ButtonRenderer = {}
ButtonRenderer.__index = ButtonRenderer

function ButtonRenderer.new()
    local self = setmetatable({}, ButtonRenderer)
    self.cached_shadow_color = nil
    return self
end

FRAGMENT_LOADER.loadFragments("ButtonRenderer", ButtonRenderer, {
    "Renderers.03_Button.separator",
    "Renderers.03_Button.insertion",
    "Renderers.03_Button.content",
    "Renderers.03_Button.drag_drop",
    "Renderers.03_Button.edit_mode",
    "Renderers.03_Button.main",
})

return ButtonRenderer
