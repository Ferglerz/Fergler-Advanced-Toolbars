-- Renderers/03_Button.lua
-- Button renderer: implementation split across 03_Button_*.lua (loaded into ButtonRenderer)

local ButtonRenderer = {}
ButtonRenderer.__index = ButtonRenderer

local function import(fragment_modname)
    local path = package.searchpath(fragment_modname, package.path)
    if not path then
        error("cannot find module: " .. fragment_modname)
    end
    local env = setmetatable({ButtonRenderer = ButtonRenderer}, {__index = _G})
    local chunk, err = loadfile(path, "bt", env)
    if not chunk then
        error(err or path)
    end
    chunk()
end

function ButtonRenderer.new()
    local self = setmetatable({}, ButtonRenderer)
    self.cached_shadow_color = nil
    return self
end

import("Renderers.03_Button_separator")
import("Renderers.03_Button_insertion")
import("Renderers.03_Button_main")

return ButtonRenderer.new()
