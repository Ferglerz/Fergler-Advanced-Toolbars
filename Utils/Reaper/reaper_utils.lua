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
            on_empty(widget)
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

function M.runAction(command_id)
    if command_id and command_id > 0 then
        reaper.Main_OnCommand(command_id, 0)
    end
end

function M.runNamedAction(action_id)
    if not action_id or action_id == "" then
        return false
    end
    local cmd = reaper.NamedCommandLookup(action_id)
    if cmd and cmd ~= 0 then
        reaper.Main_OnCommand(cmd, 0)
        return true
    end
    return false
end

function M.withUndoBlock(label, fn)
    reaper.Undo_BeginBlock()
    local ok, err = pcall(fn)
    reaper.UpdateArrange()
    reaper.Undo_EndBlock(label or "Advanced Toolbars", -1)
    if not ok then
        error(err)
    end
end

return M
