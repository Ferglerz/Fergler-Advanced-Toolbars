-- Utils/coordinates.lua
local Coordinates = {}
Coordinates.__index = Coordinates

function Coordinates.new(ctx)
    local self = setmetatable({}, Coordinates)
    
    self.ctx = ctx
    
    -- Get current scroll and window state once per frame
    self.scroll_x = reaper.ImGui_GetScrollX(ctx)
    self.scroll_y = reaper.ImGui_GetScrollY(ctx) 
    self.window_x, self.window_y = reaper.ImGui_GetWindowPos(ctx)
    
    return self
end

function Coordinates:refreshScroll()
    if not self.ctx then
        return
    end
    self.scroll_x = reaper.ImGui_GetScrollX(self.ctx)
    self.scroll_y = reaper.ImGui_GetScrollY(self.ctx)
end

function Coordinates:refreshWindowPos()
    if not self.ctx then
        return
    end
    self.window_x, self.window_y = reaper.ImGui_GetWindowPos(self.ctx)
end

-- Screen position of content (0,0): same space as SetCursorPos / layout rel_x, rel_y.
function Coordinates:contentOrigin()
    self:refreshScroll()
    self:refreshWindowPos()
    local cr_x, cr_y = 0, 0
    if reaper.ImGui_GetWindowContentRegionMin then
        cr_x, cr_y = reaper.ImGui_GetWindowContentRegionMin(self.ctx)
    end
    return self.window_x + cr_x - self.scroll_x, self.window_y + cr_y - self.scroll_y
end

-- Convert content-relative position to screen coordinates (includes scroll + content inset).
function Coordinates:toScreen(rel_x, rel_y)
    local ox, oy = self:contentOrigin()
    return ox + rel_x, oy + rel_y
end

-- Convert screen coordinates to DrawList coordinates (apply scroll offset)
function Coordinates:toDrawList(screen_x, screen_y)
    return screen_x - self.scroll_x, screen_y - self.scroll_y
end

-- Convert relative position directly to DrawList coordinates
function Coordinates:relativeToDrawList(rel_x, rel_y)
    return self:toScreen(rel_x, rel_y)
end

-- Convert relative rect (x, y, w, h) directly to DrawList coordinates (x1, y1, x2, y2)
function Coordinates:relativeRectToDrawList(rel_x, rel_y, width, height)
    local x1, y1 = self:relativeToDrawList(rel_x, rel_y)
    return x1, y1, x1 + width, y1 + height
end

-- Get ImGui line height (cached per frame since the main font is pushed once)
function Coordinates:textLineHeight(ctx)
    if not self.line_height then
        self.line_height = reaper.ImGui_GetTextLineHeight(ctx or self.ctx)
    end
    return self.line_height
end

-- Check if mouse is over a content-relative rectangle (screen-space compare).
function Coordinates:mouseOverRelative(rel_x, rel_y, width, height)
    local mouse_x, mouse_y = Coordinates.getMouseScreenForDrag(self.ctx)
    local x1, y1 = self:toScreen(rel_x, rel_y)
    return mouse_x >= x1 and mouse_x <= x1 + width and mouse_y >= y1 and mouse_y <= y1 + height
end

-- Mouse in the same space as SetCursorPos / layout rel_x, rel_y (includes window scroll).
function Coordinates:getRelativeMouse()
    local mouse_x, mouse_y = Coordinates.getMouseScreenForDrag(self.ctx)
    return self:screenToRelative(mouse_x, mouse_y)
end

-- Check if point is within relative rectangle
function Coordinates:pointInRelativeRect(point_rel_x, point_rel_y, rect_rel_x, rect_rel_y, width, height)
    return point_rel_x >= rect_rel_x and point_rel_x <= rect_rel_x + width and
           point_rel_y >= rect_rel_y and point_rel_y <= rect_rel_y + height
end

-- Calculate distance between two relative points
function Coordinates:relativeDistance(x1, y1, x2, y2)
    return math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
end

-- Convert screen coordinates to relative coordinates (accounting for scroll)
function Coordinates:screenToRelative(screen_x, screen_y)
    local ox, oy = self:contentOrigin()
    return screen_x - ox, screen_y - oy
end

-- During a drag, ImGui_GetMousePos(dest_ctx) can be stale on toolbars that did not start the drag.
-- Use the source context (or main) so screen-space hit-tests match the OS cursor across windows.
function Coordinates.getMouseScreenForDrag(ctx)
    local C = _G.C
    if C and C.DragDropManager and C.DragDropManager:isDragging() then
        local dctx = C.DragDropManager.drag_pointer_ctx
        if dctx then
            return reaper.ImGui_GetMousePos(dctx)
        end
        if _G.MAIN_IMGUI_CTX then
            return reaper.ImGui_GetMousePos(_G.MAIN_IMGUI_CTX)
        end
    end
    return reaper.ImGui_GetMousePos(ctx)
end

-- OS mouse inside this window's screen rectangle. Use for drag/drop hit-testing across toolbars:
-- each toolbar may use a different ImGui context; ImGui_IsWindowHovered often stays false on the
-- destination window while a drag began in another context, so hover-based checks break indicators and drops.
function Coordinates:isMouseOverWindow()
    local ctx = self.ctx
    local mx, my = Coordinates.getMouseScreenForDrag(ctx)
    local wx, wy = reaper.ImGui_GetWindowPos(ctx)
    local ww = reaper.ImGui_GetWindowWidth(ctx)
    local wh = reaper.ImGui_GetWindowHeight(ctx)
    return mx >= wx and mx <= wx + ww and my >= wy and my <= wy + wh
end

return Coordinates