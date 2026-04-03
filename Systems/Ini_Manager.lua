-- Systems/Ini_Manager.lua
-- INI / runtime toolbar line IO: implementation split across Ini_Manager_*.lua (loaded into IniManager).

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

import("Systems.Ini_Manager_core")
import("Systems.Ini_Manager_query")
import("Systems.Ini_Manager_styles")
import("Systems.Ini_Manager_insert")
import("Systems.Ini_Manager_move")
import("Systems.Ini_Manager_util")

return IniManager
