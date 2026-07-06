-- Renderers/02_Group.lua
-- Group renderer: implementation split across Renderers/02_Group/*.lua.

local DRAWING = require("Utils.Draw.drawing")
local FRAGMENT_LOADER = require("Utils.Core.fragment_loader")

local GroupRenderer = {}
GroupRenderer.__index = GroupRenderer

function GroupRenderer.new()
    local self = setmetatable({}, GroupRenderer)
    return self
end

FRAGMENT_LOADER.loadFragments("GroupRenderer", GroupRenderer, {
    "Renderers.02_Group.main",
    "Renderers.02_Group.render",
    "Renderers.02_Group.ghost",
    "Renderers.02_Group.drag_drop",
    "Renderers.02_Group.label",
    "Renderers.02_Group.decoration",
}, {
    DRAWING = DRAWING,
})

return GroupRenderer
