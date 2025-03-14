-- manager_factory.lua
local ManagerFactory = {}

function ManagerFactory.createManagers(reaper, helpers)
    local modules = {}
    
    -- Core systems
    modules.button_system = require("button_system")
    modules.button_group = require("button_group")
    modules.parser = require("toolbar_parser")
    
    -- Core managers
    modules.config = require("config").new(reaper)
    modules.state = require("button_state").new(reaper)
    modules.color_utils = require("color_utils")
    modules.general_utils = require("general_utils")
    
    -- UI managers
    modules.settings_window = require("settings_window").new(reaper, helpers)
    modules.toolbar_settings = require("toolbar_settings").new(reaper, helpers)
    modules.button_context_manager = require("button_context_menu_manager").new(
        reaper, helpers, modules.button_system.createPropertyKey
    )
    modules.button_color_editor = require("button_color_editor").new(reaper, helpers)
    modules.global_color_editor = require("global_color_editor").new(reaper, helpers)
    modules.presets = require("presets").new(reaper, helpers)
    
    -- Renderers
    modules.button_renderer = require("renderers/button").new(reaper, modules.state, helpers)
    modules.preset_renderer = require("renderers/presets").new(reaper, helpers)
    modules.group_renderer = require("renderers/group").new(reaper, helpers)
    modules.dropdown_renderer = require("renderers/dropdown").new(reaper, helpers)
    modules.font_icon_selector = require("font_icon_selector").new(reaper, helpers)
    
    -- Ensure the button renderer has references to other managers
    if modules.button_renderer then
        modules.button_renderer.icon_font_selector = modules.font_icon_selector
        modules.button_renderer.preset_renderer = modules.preset_renderer
    end
    
    return modules
end

return ManagerFactory