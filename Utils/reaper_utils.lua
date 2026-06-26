-- Utils/reaper_utils.lua
local M = {}

function M.widgetSliderNormalized(widget)
    local min_v = widget.min_value or 0
    local max_v = widget.max_value or 1
    local range = max_v - min_v
    local normalized = range ~= 0 and ((widget.value or 0) - min_v) / range or 0
    normalized = math.max(0, math.min(1, normalized))
    return normalized, range, min_v, max_v
end

function M.hashSelectedMediaItems()
    local item_count = reaper.CountSelectedMediaItems(0)
    if item_count == 0 then
        return "empty"
    end
    local parts = {}
    for i = 0, item_count - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        table.insert(parts, tostring(item))
    end
    return table.concat(parts, ",")
end

function M.cachedOnSelectionChange(widget, hash_key, value_key, empty_value, on_change, on_empty)
    local current_hash = M.hashSelectedMediaItems()
    if current_hash == "empty" then
        if on_empty then
            on_empty()
        end
        widget[value_key] = empty_value
        widget[hash_key] = "empty"
        return empty_value
    end
    if current_hash ~= widget[hash_key] then
        widget[hash_key] = current_hash
        widget[value_key] = on_change()
    end
    return widget[value_key]
end

return M
