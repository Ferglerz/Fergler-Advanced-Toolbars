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

-- Popup / editor singletons: require + .new() on first C.<name> access (not at startup).
local LAZY_UI_MODULES = {
    ButtonColorEditor = "Windows.Button_Color_Editor",
    ButtonDropdownEditor = "Windows.Button_Dropdown_Editor",
    GlobalColorEditor = "Windows.Global_Color_Editor",
    IconSelector = "Windows.Icon_Selector",
    ButtonDropdownMenu = "Menus.Button_Dropdown_Menu",
    ButtonSettingsMenu = "Menus.Button_Settings_Menu",
    GlobalSettingsMenu = "Menus.Global_Settings_Menu",
    ActionSearch = "Windows.Action_Search",
}

local function installLazyAccessors(C)
    setmetatable(C, {
        __index = function(t, k)
            if k == "Interactions" then
                local inst = require("Systems.Interactions").new()
                rawset(t, k, inst)
                return inst
            end
            if k == "GlobalStyle" then
                local mod = require("Windows._Global_Style")
                rawset(t, k, mod)
                return mod
            end
            local module_path = LAZY_UI_MODULES[k]
            if module_path then
                local inst = require(module_path).new()
                rawset(t, k, inst)
                return inst
            end
        end
    })
end

-- Warm GlobalStyle for popup draw paths that batch-apply style before touching editors.
function ModulesFactory.ensureUiModules()
    local _ = C.GlobalStyle
end

function ModulesFactory.createGlobalModules()
    resetWidgetCache()
    _G.C = {}
    installLazyAccessors(C)

    -- Load core systems first (no dependencies)
    C.ButtonDefinition = require("Systems.Button_Definition")
    C.IniManager = require("Managers.Ini").new()

    -- Load systems that may depend on IniManager
    C.IconManager = require("Managers.Icon").new()
    C.ButtonManager = require("Managers.Button").new()
    C.WidgetsManager = require("Managers.Widgets").new()
    C.LayoutManager = require("Managers.Layout").new()
    C.DragDropManager = require("Managers.Drag_Drop").new()
    C.PopupContext = require("Systems.Popup_Context")

    -- Load parsing components (these depend on IniManager)
    C.ParseGrouping = require("Parsing.Parse_Grouping")
    C.ParseToolbars = require("Parsing.Parse_Toolbars").new()
    C.SharedToolbars = require("Parsing.Shared_Toolbars").new()

    -- Load renderers (core startup path)
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

function ModulesFactory.loadSharedToolbarsAtStartup()
    if not C or not C.SharedToolbars then
        return nil
    end
    local toolbars, menu_path = C.SharedToolbars:ensureLoaded()
    if toolbars then
        _G.STARTUP_TOOLBARS = toolbars
        _G.STARTUP_TOOLBAR_MENU_PATH = menu_path
    end
    return toolbars
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
