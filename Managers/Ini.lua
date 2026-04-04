-- Managers/Ini.lua
-- INI / runtime toolbar line IO: implementation split across Managers/Ini/*.lua (loaded into IniManager).

local IniManager = {}
IniManager.__index = IniManager

local function import(fragment_modname)
    local path = package.searchpath(fragment_modname, package.path)
    if not path then
        error("cannot find module: " .. fragment_modname)
    end
    local env = setmetatable({IniManager = IniManager}, {__index = _G})
    local chunk, err = loadfile(path, "bt", env)
    if not chunk then
        error(err or path)
    end
    chunk()
end

import("Managers.Ini.core")
import("Managers.Ini.query")
import("Managers.Ini.styles")
import("Managers.Ini.insert")
import("Managers.Ini.move")
import("Managers.Ini.util")

return IniManager
