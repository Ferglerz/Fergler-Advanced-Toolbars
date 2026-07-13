-- Utils/Core/button/drag.lua

local M = {}

--- Ensure entity.cache drag_state exists; optional drag_start_time field for separator holds.
function M.ensureDragCache(entity, key, include_drag_start_time, mode)
    key = key or "drag_state"
    local s
    if mode == "group" then
        s = CACHE_UTILS.ensureGroupCacheSubtable(entity, key)
    else
        CACHE_UTILS.ensureButtonCache(entity)
        if not entity.cache[key] then
            entity.cache[key] = {}
        end
        s = entity.cache[key]
    end
    if s.was_dragging_last_frame == nil then
        s.was_dragging_last_frame = false
    end
    if s.mouse_down_on_button == nil then
        s.mouse_down_on_button = false
    end
    if include_drag_start_time and s.drag_start_time == nil then
        s.drag_start_time = nil
    end
    return s
end

function M.canStartDrag(drag_cache, mouse_dragging)
    return drag_cache and
           drag_cache.mouse_down_on_button and
           mouse_dragging and
           not drag_cache.was_dragging_last_frame and
           not C.DragDropManager:isDragging()
end

function M.canStartSeparatorDrag(drag_cache, mouse_dragging, current_time)
    if not drag_cache or not drag_cache.mouse_down_on_button then
        return false
    end

    if C.DragDropManager:isDragging() or drag_cache.was_dragging_last_frame then
        return false
    end

    return mouse_dragging or
           (drag_cache.drag_start_time and current_time - drag_cache.drag_start_time > 0.05)
end

function M.computeDragGhostGroupLayout(source_button, target_button_layout, toolbar_layout)
    local spacing = CONFIG.SIZES.SPACING or 0
    local is_vert = toolbar_layout.is_vertical
    local drop_after = C.DragDropManager.drop_position == "after"
    local gw, gh

    if source_button:isSeparator() then
        if is_vert then
            gw = target_button_layout.width
            gh = (source_button.cache.layout and source_button.cache.layout.height) or CONFIG.SIZES.SEPARATOR_SIZE
        else
            gw = (source_button.cache.layout and source_button.cache.layout.width) or CONFIG.SIZES.SEPARATOR_SIZE
            gh = CONFIG.SIZES.HEIGHT
        end
    else
        gw = (source_button.cached_width and source_button.cached_width.total) or CONFIG.SIZES.MIN_WIDTH
        gh = CONFIG.SIZES.HEIGHT
        if is_vert then
            gw = target_button_layout.width
        end
    end

    local gx, gy
    if is_vert then
        gx = target_button_layout.x
        if drop_after then
            gy = target_button_layout.y + target_button_layout.height + spacing
        else
            gy = target_button_layout.y - gh - spacing
        end
    else
        gy = target_button_layout.y
        if drop_after then
            gx = target_button_layout.x + target_button_layout.width + spacing
        else
            gx = target_button_layout.x - gw - spacing
        end
    end

    return { x = gx, y = gy, width = gw, height = gh, is_vertical = is_vert }
end

return M
