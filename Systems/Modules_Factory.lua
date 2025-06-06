-- Systems/Modules_Factory.lua
local ModulesFactory = {}

function ModulesFactory.createGlobalModules()
    _G.C = {}

    -- Load core systems first (no dependencies)
    C.ButtonDefinition = require("Systems.Button_Definition")
    C.IniManager = require("Systems.Ini_Manager").new()
    
    -- Load systems that may depend on IniManager
    C.IconManager = require("Systems.Icon_Manager").new()
    C.ButtonManager = require("Systems.Button_Manager").new()
    C.WidgetsManager = require("Systems.Widgets_Manager").new()
    C.Interactions = require("Systems.Interactions").new()
    C.LayoutManager = require("Systems.Layout_Manager").new()
    C.DragDropManager = require("Systems.Drag_Drop_Manager").new()

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