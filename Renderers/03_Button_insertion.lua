-- Renderers/03_Button_insertion.lua
-- Intensely lean, DRY version

local Insertion = {}

-- DRY triangle & symbol renderer
function Insertion:renderTriangleWithSymbol(dl, cx, cy, tw, th, tcol, angle, symbol, scol)
    DRAWING.triangle(dl, cx, cy, tw, th, tcol, angle)
    local s = tw / 2
    local t = 2.0
    local so = th / 12
    local sx, sy = cx, cy
    if angle == DRAWING.ANGLE_DOWN then sy = sy - so + 8
    elseif angle == DRAWING.ANGLE_UP then sy = sy + so - 8
    elseif angle == DRAWING.ANGLE_RIGHT then sx, sy = sx + 7 - so, sy - so + 8
    elseif angle == DRAWING.ANGLE_LEFT then sx, sy = sx + so + 6, sy - so + 8
    end
    if symbol == "plus" then
        reaper.ImGui_DrawList_AddLine(dl, sx - s/2, sy, sx + s/2, sy, scol, t)
        reaper.ImGui_DrawList_AddLine(dl, sx, sy - s/2, sx, sy + s/2, scol, t)
    elseif symbol == "x" then
        reaper.ImGui_DrawList_AddLine(dl, sx - s/2, sy - s/2, sx + s/2, sy + s/2, scol, t)
        reaper.ImGui_DrawList_AddLine(dl, sx + s/2, sy - s/2, sx - s/2, sy + s/2, scol, t)
    end
end

local function isFirst(button) return BUTTON_UTILS.isFirstButtonInGroup(button) end

function Insertion:createInsertionControlsParams(ctx, button, rx, ry, w, coords, dl, msx, msy, vert, bh)
    local mx, my = coords:screenToRelative(msx, msy)
    return {
        ctx=ctx, button=button, position={x=rx,y=ry}, width=w, coords=coords, draw_list=dl,
        mouse={screen={x=msx,y=msy}, relative={x=mx,y=my}},
        triangle_size=CONFIG.SIZES.HEIGHT/4, hover_zone=25, is_vertical=vert,
        button_height=bh or CONFIG.SIZES.HEIGHT
    }
end

function Insertion:renderInsertionControls(ctx, button, rx, ry, w, coords, dl, msx, msy, vert, bh)
    return self:renderInsertionControlsWithParams(
        self:createInsertionControlsParams(ctx, button, rx, ry, w, coords, dl, msx, msy, vert, bh)
    )
end

function Insertion:renderInsertionControlsWithParams(p)
    local bh = p.button_height
    local vert = p.is_vertical
    local pos, w, m = p.position, p.width, p.mouse.relative
    local tsz = p.triangle_size
    local sep = p.button:isSeparator()
    local is_first = isFirst(p.button)
    local ccx = sep and (pos.x + w/2) or pos.x
    local show_top, show_bottom, top_tr_y, bot_tr_y, ltr_x, rtr_x, tri_cy, dist

    if vert then
        local tri_above = pos.y - tsz - 8
        local tri_inside = pos.y + math.min(tsz+4, math.max(bh*0.28,4))
        tri_cy = (bh >= tsz*2+16) and tri_above or tri_inside
        if not (m.y >= math.min(pos.y-tsz-10,pos.y) and m.y <= pos.y+p.hover_zone and math.abs(m.x-pos.x)<=w+40) then return false end
        show_top = m.x < pos.x+w/2
        show_bottom = m.x >= pos.x+w/2
        if is_first and not sep then show_bottom = false end
        ltr_x = (sep and pos.x or ccx) - tsz - 8
        rtr_x = (sep and pos.x + w or ccx + w) + tsz + 8
        dist = math.abs(m.y - tri_cy)
    else
        if not (m.x >= pos.x and m.x <= pos.x+p.hover_zone and math.abs(m.y-pos.y)<=bh+30) then return false end
        show_top = m.y < pos.y + bh/2
        show_bottom = m.y >= pos.y + bh/2
        if is_first and not sep then show_bottom = false end
        top_tr_y = pos.y - tsz - 8
        bot_tr_y = pos.y + bh + tsz + 8
        dist = math.abs(m.x - ccx)
    end

    self.control_pool = self.control_pool or {}
    self.control_pool_index = (self.control_pool_index or 0) + 1
    local pool = self.control_pool
    local i = self.control_pool_index
    pool[i] = pool[i] or {}
    local c = pool[i]
    c.is_vertical = vert
    c.control_rel_x = ccx
    c.top_triangle_rel_y = top_tr_y
    c.bottom_triangle_rel_y = bot_tr_y
    c.left_triangle_rel_x = ltr_x
    c.right_triangle_rel_x = rtr_x
    c.tri_center_y = tri_cy
    c.triangle_size = tsz
    c.show_top = show_top
    c.show_bottom = show_bottom
    c.is_separator_button = sep
    c.button_instance_id = p.button.instance_id
    c.mouse_distance_to_center = dist

    self.pending_insertion_controls = self.pending_insertion_controls or {}
    table.insert(self.pending_insertion_controls, c)

    local clicked_add, clicked_sep, clicked_del = false, false, false
    if reaper.ImGui_IsMouseClicked(p.ctx, 0) then
        if vert then
            local dL = math.sqrt((m.x - c.left_triangle_rel_x)^2 + (m.y-c.tri_center_y)^2)
            local dR = math.sqrt((m.x - c.right_triangle_rel_x)^2 + (m.y-c.tri_center_y)^2)
            if c.show_top and dL <= tsz+5 then clicked_add = true
            elseif c.show_bottom and dR <= tsz+5 then
                if sep then clicked_del = true else clicked_sep = true end
            end
        else
            local dT = math.sqrt((m.x - c.control_rel_x)^2 + (m.y - c.top_triangle_rel_y)^2)
            local dB = math.sqrt((m.x - c.control_rel_x)^2 + (m.y - c.bottom_triangle_rel_y)^2)
            if c.show_top and dT <= tsz+5 then clicked_add = true
            elseif c.show_bottom and dB <= tsz+5 then
                if sep then clicked_del = true else clicked_sep = true end
            end
        end
    end

    return clicked_add, clicked_sep, clicked_del
end

function Insertion:renderPendingControlsOnTop(ctx, dl, coords)
    local controls = self.pending_insertion_controls or {}
    if #controls == 0 then self.control_pool_index = 0 return end

    -- Closest control only (exclusive visual)
    local close, min = nil, math.huge
    for _, c in ipairs(controls) do if c.mouse_distance_to_center < min then min = c.mouse_distance_to_center close = c end end
    if close then
        local tw, th = close.triangle_size*2, close.triangle_size*3
        self.cached_editing_colors = self.cached_editing_colors or {
            white = COLOR_UTILS.toImGuiColor("#FFFFFFFF"),
            add_button = COLOR_UTILS.toImGuiColor("#4A90E2FF") & 0xFFFFFF7F,
            delete = COLOR_UTILS.toImGuiColor("#FF0000FF") & 0xFFFFFF7F,
            add_separator = COLOR_UTILS.toImGuiColor("#CCCCCCFF") & 0xFFFFFF7F
        }
        local col = self.cached_editing_colors
        local white = col.white
        if close.is_vertical then
            local lx, ty = coords:relativeToDrawList(close.left_triangle_rel_x, close.tri_center_y)
            local rx, _ = coords:relativeToDrawList(close.right_triangle_rel_x, close.tri_center_y)
            if close.show_top then self:renderTriangleWithSymbol(dl, lx, ty, tw, th, col.add_button, DRAWING.ANGLE_RIGHT, "plus", white) end
            if close.show_bottom then
                local ccol, sym = close.is_separator_button and col.delete or col.add_separator, close.is_separator_button and "x" or "plus"
                self:renderTriangleWithSymbol(dl, rx, ty, tw, th, ccol, DRAWING.ANGLE_LEFT, sym, white)
            end
        else
            local cx = (coords:relativeToDrawList(close.control_rel_x, 0))
            local _, topy = coords:relativeToDrawList(0, close.top_triangle_rel_y)
            local _, boty = coords:relativeToDrawList(0, close.bottom_triangle_rel_y)
            if close.show_top then self:renderTriangleWithSymbol(dl, cx, topy, tw, th, col.add_button, DRAWING.ANGLE_DOWN, "plus", white) end
            if close.show_bottom then
                local ccol, sym = close.is_separator_button and col.delete or col.add_separator, close.is_separator_button and "x" or "plus"
                self:renderTriangleWithSymbol(dl, cx, boty, tw, th, ccol, DRAWING.ANGLE_UP, sym, white)
            end
        end
    end
    self.pending_insertion_controls = {}
    self.control_pool_index = 0
end

return Insertion
