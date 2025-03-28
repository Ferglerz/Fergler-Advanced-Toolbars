-- Systems/Modules_Factory.lua
local ModulesFactory = {}

function ModulesFactory.createModules()
    local folder = ""

    folder = "Utils."
    _G.UTILS = require(folder .. "utils")
    _G.DRAWING = require(folder .. "drawing")
    _G.DIM_UTILS = require(folder .. "dim_utils")
    _G.COLOR_UTILS = require(folder .. "color_utils")

    _G.C = {} -- Global Components

    folder = "Systems."

    local defaults = require(folder .. "DEFAULT_CONFIG")
    _G.CONFIG_MANAGER = require(folder .. "Config_Manager").new(defaults)

    C.ButtonDefinition = require(folder .. "Button_Definition")
    C.IconManager = require(folder .. "Icon_Manager")
    C.ButtonManager = require(folder .. "Button_Manager").new()
    C.WidgetsManager = require(folder .. "Widgets_Manager").new()

    local Interactions = require(folder .. "Interactions").new()

    folder = "Windows."
    C.GlobalStyle = require(folder .. "_Global_Style")

    C.ButtonColorEditor = require(folder .. "Button_Color_Editor").new()
    C.ButtonDropdownEditor = require(folder .. "Button_Dropdown_Editor").new()
    C.GlobalColorEditor = require(folder .. "Global_Color_Editor").new()
    C.IconSelector = require(folder .. "Icon_Selector").new()

    folder = "Menus."
    C.ButtonDropdownMenu = require(folder .. "Button_Dropdown_Menu").new()
    C.ButtonSettingsMenu = require(folder .. "Button_Settings_Menu").new()
    C.GlobalSettingsMenu = require(folder .. "Global_Settings_Menu").new()
    
    ToolbarController = require("Systems.Toolbar_Controller").new(
        Interactions
    )

    folder = "Parsing."
    local ParseGrouping = require(folder .. "Parse_Grouping")
    local ParseToolbars = require(folder .. "Parse_Toolbars").new(ParseGrouping)
    C.ToolbarLoader = require(folder .. "Load_Toolbar").new(ParseToolbars, ToolbarController)

    folder = "Renderers."
    local WidgetRenderer = require(folder .. "_Widgets").new(ToolbarController)
    local ButtonContent = require(folder .. "04_Content").new()
    local ButtonRenderer = require(folder .. "03_Button").new(Interactions, ButtonContent, WidgetRenderer)
    local GroupRenderer = require(folder .. "02_Group").new(ButtonRenderer)
    local ToolbarRenderer = require(folder .. "01_Toolbar").new(Interactions, ToolbarController, GroupRenderer)

    return ToolbarController, ToolbarRenderer
end

return ModulesFactory