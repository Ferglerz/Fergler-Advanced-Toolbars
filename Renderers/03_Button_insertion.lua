-- Renderers/03_Button_insertion.lua
-- Intensely lean, DRY version; loaded into ButtonRenderer by 03_Button.lua

function ButtonRenderer:createInsertionControlsParams(ctx, button, rx, ry, w, coords, dl, msx, msy, vert, bh, glyph_outer_color)
    local mx, my = coords:screenToRelative(msx, msy)
    return {
        ctx = ctx,
        button = button,
        position = { x = rx, y = ry },
        width = w,
        coords = coords,
        draw_list = dl,
        mouse = { screen = { x = msx, y = msy }, relative = { x = mx, y = my } },
        hover_zone = 25,
        is_vertical = vert,
        button_height = bh or CONFIG.SIZES.HEIGHT,
        glyph_outer_color = glyph_outer_color
    }
end

function ButtonRenderer:renderInsertionControls(ctx, button, rx, ry, w, coords, dl, msx, msy, vert, bh, glyph_outer_color)
    return self:renderInsertionControlsWithParams(
        self:createInsertionControlsParams(ctx, button, rx, ry, w, coords, dl, msx, msy, vert, bh, glyph_outer_color)
    )
end

function ButtonRenderer:renderInsertionControlsWithParams(p)
    local bh = p.button_height
    local vert = p.is_vertical
    local pos, w, m = p.position, p.width, p.mouse.relative
    -- Diameter = 60% of minimum toolbar button height (config)
    local outer_r = 0.3 * CONFIG.SIZES.MIN_HEIGHT
    local sep = p.button:isSeparator()
    local ccx = sep and (pos.x + w / 2) or pos.x
    local glyph_cy = pos.y + bh / 2
    local glyph_cx, dist

    if vert then
        if not (m.y >= pos.y - outer_r - 6 and m.y <= pos.y + p.hover_zone and math.abs(m.x - pos.x) <= w + outer_r + 45) then
            return false
        end
        glyph_cx = (sep and pos.x + w or ccx + w) + outer_r + 3
        dist = math.abs(m.y - glyph_cy)
    else
        if not (m.x >= pos.x and m.x <= pos.x + p.hover_zone and math.abs(m.y - pos.y) <= bh + 30) then
            return false
        end
        glyph_cx = ccx
        dist = math.abs(m.x - glyph_cx)
    end

    self.control_pool = self.control_pool or {}
    self.control_pool_index = (self.control_pool_index or 0) + 1
    local pool = self.control_pool
    local i = self.control_pool_index
    pool[i] = pool[i] or {}
    local c = pool[i]
    c.is_vertical = vert
    c.control_rel_x = ccx
    c.glyph_cx_rel = glyph_cx
    c.glyph_cy_rel = glyph_cy
    c.glyph_outer_r = outer_r
    c.glyph_outer_color = p.glyph_outer_color
    c.is_separator_button = sep
    c.button_instance_id = p.button.instance_id
    c.mouse_distance_to_center = dist

    self.pending_insertion_controls = self.pending_insertion_controls or {}
    table.insert(self.pending_insertion_controls, c)

    local clicked_insert_menu, clicked_sep, clicked_del = false, false, false
    if reaper.ImGui_IsMouseClicked(p.ctx, 0) then
        local d = math.sqrt((m.x - c.glyph_cx_rel) ^ 2 + (m.y - c.glyph_cy_rel) ^ 2)
        if d <= c.glyph_outer_r then
            if sep then
                clicked_del = true
            else
                clicked_insert_menu = true
            end
        end
    end

    return clicked_insert_menu, clicked_sep, clicked_del
end

function ButtonRenderer:renderPendingControlsOnTop(ctx, dl, coords)
    local controls = self.pending_insertion_controls or {}
    if #controls == 0 then
        self.control_pool_index = 0
        return
    end

    local close, min = nil, math.huge
    for _, c in ipairs(controls) do
        if c.mouse_distance_to_center < min then
            min = c.mouse_distance_to_center
            close = c
        end
    end
    if close then
        local sym = close.is_separator_button and "x" or "plus"
        local gx, gy = coords:relativeToDrawList(close.glyph_cx_rel, close.glyph_cy_rel)
        DRAWING.insertionGlyph(dl, gx, gy, close.glyph_outer_r, close.glyph_outer_color, sym)
    end
    self.pending_insertion_controls = {}
    self.control_pool_index = 0
end
