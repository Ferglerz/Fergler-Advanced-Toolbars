-- Renderers/01_Toolbar.lua
-- Toolbar window renderer: implementation split across Renderers/01_Toolbar/*.lua

local FRAGMENT_LOADER = require("Utils.Core.fragment_loader")

local ToolbarWindow = {}
ToolbarWindow.__index = ToolbarWindow

function ToolbarWindow.new(ToolbarController)
    local self = setmetatable({}, ToolbarWindow)
    self.toolbar_controller = ToolbarController
    self.fonts_preloaded = false
    self.last_window_width = 0
    self.last_window_height = 0
    self._pin_content_min_h = nil
    return self
end

FRAGMENT_LOADER.loadFragments("ToolbarWindow", ToolbarWindow, {
    "Renderers.01_Toolbar.helpers",
    "Renderers.01_Toolbar.render_loop",
    "Renderers.01_Toolbar.settings",
    "Renderers.01_Toolbar.layout_helpers",
    "Renderers.01_Toolbar.switch_separator",
    "Renderers.01_Toolbar.placeholders",
    "Renderers.01_Toolbar.edit_controls",
    "Renderers.01_Toolbar.drag_drop",
    "Renderers.01_Toolbar.single_row",
    "Renderers.01_Toolbar.toolbar_content",
    "Renderers.01_Toolbar.ui_elements",
})

return {
    new = function(...)
        return ToolbarWindow.new(...)
    end
}
