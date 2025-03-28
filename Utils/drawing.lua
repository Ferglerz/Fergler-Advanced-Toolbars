-- Utils/drawing.lua
local Drawing = {}

-- angle: Direction in degrees (0 = up, 90 = right, 180 = down, 270 = left)
function Drawing.triangle(draw_list, center_x, center_y, width, height, color, angle)
    -- Convert angle to radians
    local rad = math.rad(angle)
    
    -- Calculate the three points of the triangle based on the angle
    -- The triangle points in the direction specified by angle
    local point1_x = center_x + math.sin(rad) * (height / 2)
    local point1_y = center_y - math.cos(rad) * (height / 2)
    
    local point2_x = center_x - math.sin(rad + math.pi/2) * (width / 2)
    local point2_y = center_y + math.cos(rad + math.pi/2) * (width / 2)
    
    local point3_x = center_x + math.sin(rad + math.pi/2) * (width / 2)
    local point3_y = center_y - math.cos(rad + math.pi/2) * (width / 2)
    
    -- Draw the triangle
    reaper.ImGui_DrawList_AddTriangleFilled(
        draw_list,
        point1_x, point1_y,  -- Point in the direction of angle
        point2_x, point2_y,  -- Point to the 'left' of the direction
        point3_x, point3_y,  -- Point to the 'right' of the direction
        color
    )
end

Drawing.ANGLE_UP = 0
Drawing.ANGLE_RIGHT = 90
Drawing.ANGLE_DOWN = 180
Drawing.ANGLE_LEFT = 270

return Drawing