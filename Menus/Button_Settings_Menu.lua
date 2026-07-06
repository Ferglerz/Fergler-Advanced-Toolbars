-- Menus/Button_Settings_Menu.lua
-- Button settings menu: implementation split across Menus/Button_Settings/*.lua.

local FRAGMENT_LOADER = require("Utils.Core.fragment_loader")

local ButtonSettingsMenu = {}
ButtonSettingsMenu.__index = ButtonSettingsMenu

function ButtonSettingsMenu.new()
    local self = setmetatable({}, ButtonSettingsMenu)
    self._last_separator_screen_y = -9999
    return self
end

FRAGMENT_LOADER.loadFragments("ButtonSettingsMenu", ButtonSettingsMenu, {
    "Menus.Button_Settings.main",
    "Menus.Button_Settings.defaults",
    "Menus.Button_Settings.colors",
    "Menus.Button_Settings.widget_selector",
})

return ButtonSettingsMenu
