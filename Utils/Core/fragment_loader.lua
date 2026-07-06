-- Utils/Core/fragment_loader.lua
local merge_table = require("Utils.Core.merge_table")

local M = {}

function M.load_fragment(env, fragment_modname)
    local path = package.searchpath(fragment_modname, package.path)
    if not path then
        error("cannot find module: " .. fragment_modname)
    end
    local chunk, err = loadfile(path, "bt", env)
    if not chunk then
        error(err or path)
    end
    chunk()
end

function M.loadFragments(host_key, host_table, fragment_modnames, extra_env)
    local bindings = merge_table.merge({}, extra_env or {})
    bindings[host_key] = host_table
    local env = setmetatable(bindings, {__index = _G})
    for _, fragment_modname in ipairs(fragment_modnames) do
        M.load_fragment(env, fragment_modname)
    end
end

return M
