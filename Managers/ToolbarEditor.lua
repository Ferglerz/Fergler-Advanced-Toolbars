-- Managers/ToolbarEditor.lua
-- Independent toolbar editing: implementation split across Managers/ToolbarEditor/*.lua (loaded into ToolbarEditor).

local FRAGMENT_LOADER = require("Utils.Core.fragment_loader")

local ToolbarEditor = {}
ToolbarEditor.__index = ToolbarEditor

FRAGMENT_LOADER.loadFragments("ToolbarEditor", ToolbarEditor, {
    "Managers.ToolbarEditor.core",
    "Managers.ToolbarEditor.styles",
    "Managers.ToolbarEditor.insert",
    "Managers.ToolbarEditor.move",
})

return ToolbarEditor
