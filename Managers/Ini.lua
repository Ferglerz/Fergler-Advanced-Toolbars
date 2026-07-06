-- Managers/Ini.lua
-- INI / runtime toolbar line IO: implementation split across Managers/Ini/*.lua (loaded into IniManager).

local FRAGMENT_LOADER = require("Utils.Core.fragment_loader")

local IniManager = {}
IniManager.__index = IniManager

FRAGMENT_LOADER.loadFragments("IniManager", IniManager, {
    "Managers.Ini.core",
    "Managers.Ini.query",
    "Managers.Ini.styles",
    "Managers.Ini.insert",
    "Managers.Ini.move",
    "Managers.Ini.util",
})

return IniManager
