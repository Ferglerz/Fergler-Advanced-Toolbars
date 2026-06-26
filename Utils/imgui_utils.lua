-- Utils/imgui_utils.lua
local M = {}

function M.safeCall(callback, ...)
    local success, result = pcall(callback, ...)
    if not success then
        reaper.ShowConsoleMsg("Error: " .. tostring(result) .. "\n")
        return nil
    end
    return result
end

function M.applyScrollOffset(ctx, x, y)
    if not ctx then
        return x, y
    end

    local scroll_x = reaper.ImGui_GetScrollX(ctx)
    local scroll_y = reaper.ImGui_GetScrollY(ctx)

    return x - scroll_x, y - scroll_y
end

function M.clampVerticalScroll(ctx)
    if not ctx or not reaper.ImGui_GetScrollY or not reaper.ImGui_SetScrollY then
        return
    end
    if (reaper.ImGui_GetScrollY(ctx) or 0) ~= 0 then
        reaper.ImGui_SetScrollY(ctx, 0)
    end
end

function M.clampHorizontalScroll(ctx)
    if not ctx or not reaper.ImGui_GetScrollX or not reaper.ImGui_SetScrollX then
        return
    end
    if (reaper.ImGui_GetScrollX(ctx) or 0) ~= 0 then
        reaper.ImGui_SetScrollX(ctx, 0)
    end
end

-- Row child: wheel would forward to parent (NoScrollbar); parent blocks vertical scroll.
function M.applyHorizontalWheelScroll(ctx)
    if not ctx or not reaper.ImGui_IsWindowHovered or not reaper.ImGui_GetMouseWheel then
        return
    end
    if not reaper.ImGui_IsWindowHovered(ctx) then
        return
    end
    if not reaper.ImGui_GetScrollMaxX or not reaper.ImGui_GetScrollX or not reaper.ImGui_SetScrollX then
        return
    end
    local scroll_max = reaper.ImGui_GetScrollMaxX(ctx) or 0
    if scroll_max <= 0 then
        return
    end
    local wheel_y, wheel_x = reaper.ImGui_GetMouseWheel(ctx)
    wheel_y = wheel_y or 0
    wheel_x = wheel_x or 0
    local delta = wheel_x ~= 0 and wheel_x or wheel_y
    if delta == 0 then
        return
    end
    local sx = reaper.ImGui_GetScrollX(ctx) or 0
    local next_x = sx - delta * 40
    if next_x < 0 then
        next_x = 0
    elseif next_x > scroll_max then
        next_x = scroll_max
    end
    reaper.ImGui_SetScrollX(ctx, next_x)
end

function M.snapWindowToMinimum(ctx, min_x, min_y, undocked_only)
    if not ctx then
        return false
    end

    min_x = tonumber(min_x) or 0
    min_y = tonumber(min_y) or 0

    if undocked_only then
        local dock_id = reaper.ImGui_GetWindowDockID(ctx)
        if dock_id and dock_id ~= 0 then
            return false
        end
    end

    local x, y = reaper.ImGui_GetWindowPos(ctx)
    local target_x = x
    local target_y = y

    if x < min_x then
        target_x = min_x
    end
    if y < min_y then
        target_y = min_y
    end

    if target_x ~= x or target_y ~= y then
        reaper.ImGui_SetWindowPos(ctx, target_x, target_y)
        return true
    end

    return false
end

function M.focusArrangeWindow(force_delay)
    local function delayedFocus()
        reaper.SetCursorContext(1)
    end

    if force_delay then
        reaper.defer(
            function()
                reaper.defer(delayedFocus)
            end
        )
    else
        delayedFocus()
    end

    return true
end

function M.throttleScan(widget, last_time_key, scan_fn)
    local interval = widget.update_interval
    if interval == nil then
        interval = 1
    end
    local now = reaper.time_precise()
    local last = widget[last_time_key]
    if not last or (now - last) > interval then
        scan_fn(widget)
        widget[last_time_key] = now
    end
end

return M
