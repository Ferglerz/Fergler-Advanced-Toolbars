local M = {}

-- The clock belongs to the widget instance, so equal intervals do not compete.
function M.refresh(widget, current_time, fetch)
    local interval = widget.update_interval
    if interval == nil then interval = 0.5 end
    if widget.last_update_time ~= nil and current_time - widget.last_update_time < interval then
        return false
    end
    if not widget.getValue then return false end
    local ok, value = fetch(widget)
    if ok then widget.value = value end
    widget.last_update_time = current_time
    return ok
end

return M
