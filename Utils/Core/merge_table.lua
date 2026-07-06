-- Utils/Core/merge_table.lua
local M = {}

function M.merge(target, source, opts)
    opts = opts or {}
    for k, v in pairs(source) do
        if not opts.skip_underscore_keys or k:sub(1, 1) ~= "_" then
            target[k] = v
        end
    end
    return target
end

return M
