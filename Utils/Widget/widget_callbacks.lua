local M = {}

local function invoke(widget, method, ...)
    local fn = widget and widget[method]
    if not fn then return false end
    local ok, result = pcall(fn, ...)
    local reported_key = "__reported_error_" .. method
    if ok then
        widget[reported_key] = nil
        return true, result
    end
    if not widget[reported_key] then
        reaper.ShowConsoleMsg("Advanced Toolbars: widget " .. tostring(widget.name or "?")
            .. " " .. method .. " failed: " .. tostring(result) .. "\n")
        widget[reported_key] = true
    end
    return false
end

function M.getValue(widget)
    return invoke(widget, "getValue", widget)
end

-- Existing one-argument setters still receive value first. Widgets that keep
-- instance state can use the optional second argument.
function M.setValue(widget, value)
    return invoke(widget, "setValue", value, widget)
end

return M
