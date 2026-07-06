-- Managers/Layout/Math.lua
-- Layout math split across Managers/Layout/*.lua mixins.

return function(LayoutManager)
require("Managers.Layout.SplitLayout")(LayoutManager)
require("Managers.Layout.ButtonMeasure")(LayoutManager)
require("Managers.Layout.GroupLayout")(LayoutManager)
require("Managers.Layout.ToolbarLayout")(LayoutManager)
end
