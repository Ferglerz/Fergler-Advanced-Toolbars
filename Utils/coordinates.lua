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

-- Convert relative position to absolute screen coordinates
function Coordinates:toScreen(rel_x, rel_y)
    return self.window_x + rel_x, self.window_y + rel_y
end

-- Convert screen coordinates to DrawList coordinates (apply scroll offset)
function Coordinates:toDrawList(screen_x, screen_y)
    return screen_x - self.scroll_x, screen_y - self.scroll_y
end

-- Convert relative position directly to DrawList coordinates
function Coordinates:relativeToDrawList(rel_x, rel_y)
    return self.window_x + rel_x - self.scroll_x, self.window_y + rel_y - self.scroll_y
end

-- Check if mouse is over a relative rectangle
function Coordinates:mouseOverRelative(rel_x, rel_y, width, height)
    local mouse_x, mouse_y = reaper.ImGui_GetMousePos(self.ctx)
    local screen_x, screen_y = self:toScreen(rel_x, rel_y)
    
    return mouse_x >= screen_x and mouse_x <= screen_x + width and
           mouse_y >= screen_y and mouse_y <= screen_y + height
end

-- Get mouse position in relative coordinates
function Coordinates:getRelativeMouse()
    local mouse_x, mouse_y = reaper.ImGui_GetMousePos(self.ctx)
    return mouse_x - self.window_x, mouse_y - self.window_y
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

return Coordinates