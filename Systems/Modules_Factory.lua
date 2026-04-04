-- Systems/Modules_Factory.lua
-- Module loading policy: normal code uses require("Dotted.Name") (cached in package.loaded).
-- Toolbar widget scripts under Widgets/ are discovered and loaded with dofile(full_path) so each
-- script run re-reads files. Renderer fragments (e.g. 03_Button_*, Managers/Ini/*) use loadfile with
-- a custom env, same idea as require but without a module return.
local ModulesFactory = {}

-- Always force widget definitions to be reloaded on each script run.
-- REAPER shares Lua state across runs, so package.loaded can retain the
-- previous Widgets manager instance. Clearing it here ensures widget files
-- are re-read every time the script starts instead of reusing stale data.
local function resetWidgetCache()
    _G.WIDGETS = nil
    package.loaded["Managers.Widgets"] = nil
end

function ModulesFactory.createGlobalModules()
    resetWidgetCache()
    _G.C = {}

    -- Load core systems first (no dependencies)
    C.ButtonDefinition = require("Systems.Button_Definition")
    C.IniManager = require("Managers.Ini").new()
    
    -- Load systems that may depend on IniManager
    C.IconManager = require("Managers.Icon").new()
    C.ButtonManager = require("Managers.Button").new()
    C.WidgetsManager = require("Managers.Widgets").new()
    C.Interactions = require("Systems.Interactions").new()
    C.LayoutManager = require("Managers.Layout").new()
    C.DragDropManager = require("Managers.Drag_Drop").new()
    C.PopupContext = require("Systems.Popup_Context")

    -- Load UI components
    C.GlobalStyle = require("Windows._Global_Style")
    C.ButtonColorEditor = require("Windows.Button_Color_Editor").new()
    C.ButtonDropdownEditor = require("Windows.Button_Dropdown_Editor").new()
    C.GlobalColorEditor = require("Windows.Global_Color_Editor").new()
    C.IconSelector = require("Windows.Icon_Selector").new()

    C.ButtonDropdownMenu = require("Menus.Button_Dropdown_Menu").new()
    C.ButtonSettingsMenu = require("Menus.Button_Settings_Menu").new()
    C.GlobalSettingsMenu = require("Menus.Global_Settings_Menu").new()

    -- Load parsing components (these depend on IniManager)
    C.ParseGrouping = require("Parsing.Parse_Grouping")
    C.ParseToolbars = require("Parsing.Parse_Toolbars").new()

    -- Load renderers
    C.WidgetRenderer = require("Renderers._Widgets").new()
    C.ButtonContent = require("Renderers.04_Content").new()
    C.ButtonRenderer = require("Renderers.03_Button").new()
    C.GroupRenderer = require("Renderers.02_Group").new()
    C.ActionSearch = require("Windows.Action_Search").new()

    -- Load controllers and loaders last (these depend on parsing components)
    C.ToolbarController = require("Systems.Toolbar_Controller")
    C.ToolbarRenderer = require("Renderers.01_Toolbar")
    C.ToolbarLoader = require("Parsing.Load_Toolbar")

    return C
end

function ModulesFactory.createToolbar(toolbar_id)
    -- Create controller and renderer instances
    local controller = C.ToolbarController.new(toolbar_id)
    local renderer = C.ToolbarRenderer.new(controller)
    controller.loader = C.ToolbarLoader.new(controller)
    
    -- Initialize with toolbars
    controller.loader:loadToolbars()
    
    return controller, renderer
end

return ModulesFactory