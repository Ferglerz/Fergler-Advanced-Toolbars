-- Keep saved button menus and runtime button menus in the same format.
local M = {}

function M.normalize(items)
    local normalized = {}
    for _, item in ipairs(items or {}) do
        if item.is_separator then
            normalized[#normalized + 1] = { is_separator = true }
        elseif item.is_heading then
            normalized[#normalized + 1] = { is_heading = true, name = item.name or "" }
        else
            normalized[#normalized + 1] = {
                name = item.name or "Unnamed",
                action_id = tostring(item.action_id or ""),
            }
        end
    end
    return normalized
end

return M
