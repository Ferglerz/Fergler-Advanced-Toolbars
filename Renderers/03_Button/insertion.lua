-- Renderers/03_Button_insertion.lua
-- Intensely lean, DRY version; loaded into ButtonRenderer by 03_Button.lua

function ButtonRenderer:createInsertionControlsParams(ctx, button, rx, ry, w, coords, dl, msx, msy, vert, bh, glyph_outer_color, render_options)
    render_options = render_options or {}
    local mx, my = coords:screenToRelative(msx, msy)
    return {
        ctx = ctx,
        button = button,
        position = { x = rx, y = ry },
        width = w,
        coords = coords,
        draw_list = dl,
        mouse = { screen = { x = msx, y = msy }, relative = { x = mx, y = my } },
        is_vertical = vert,
        button_height = bh or CONFIG.SIZES.HEIGHT,
        glyph_outer_color = glyph_outer_color,
        button_index_in_group = render_options.button_index_in_group or 1
    }
end

function ButtonRenderer:renderInsertionControls(ctx, button, rx, ry, w, coords, dl, msx, msy, vert, bh, glyph_outer_color, render_options)
    return self:renderInsertionControlsWithParams(
        self:createInsertionControlsParams(ctx, button, rx, ry, w, coords, dl, msx, msy, vert, bh, glyph_outer_color, render_options)
    )
end

local INSERTION_HIT_PAD = 4

local function insertionHitSize(outer_r)
    return math.ceil(outer_r * 2 + INSERTION_HIT_PAD * 2)
end

local function insertionHitRect(glyph_cx, glyph_cy, outer_r)
    local hit = insertionHitSize(outer_r)
    return glyph_cx - hit * 0.5, glyph_cy - hit * 0.5, hit, hit
end

local function pointInInsertionHit(c, mx, my)
    local hx, hy, hw, hh = insertionHitRect(c.glyph_cx_rel, c.glyph_cy_rel, c.glyph_outer_r)
    return mx >= hx and mx <= hx + hw and my >= hy and my <= hy + hh
end

-- Closest pending control whose full + hit rect contains the pointer (same pick as renderPendingControlsOnTop).
function ButtonRenderer:pickInsertionControlAtMouse(coords)
    local controls = self.pending_insertion_controls or {}
    if #controls == 0 then
        return nil
    end
    local mx, my = coords:getRelativeMouse()
    local close, min = nil, math.huge
    for _, c in ipairs(controls) do
        if pointInInsertionHit(c, mx, my) then
            local dist = c.mouse_distance_to_center
            if dist < min then
                min = dist
                close = c
            end
        end
    end
    return close
end

function ButtonRenderer:isMouseOverActiveInsertionHit(_coords)
    return self.active_insertion_control ~= nil
end

function ButtonRenderer:beginRowInsertionPrescan()
    self.pending_insertion_controls = {}
    self.control_pool_index = 0
    self.active_insertion_control = nil
end

function ButtonRenderer:finishRowInsertionPrescan(coords)
    self.active_insertion_control = self:pickInsertionControlAtMouse(coords)
end

function ButtonRenderer:collectInsertionControl(ctx, button, rel_x, rel_y, width, coords, msx, msy, vert, bh, button_index_in_group)
    if button.is_empty_toolbar_placeholder then
        return
    end
    local mx, my = coords:screenToRelative(msx, msy)
    return self:renderInsertionControlsWithParams({
        ctx = ctx,
        button = button,
        position = { x = rel_x, y = rel_y },
        width = width,
        coords = coords,
        mouse = { screen = { x = msx, y = msy }, relative = { x = mx, y = my } },
        is_vertical = vert,
        button_height = bh or CONFIG.SIZES.HEIGHT,
        glyph_outer_color = 0xFFFFFFFF,
        button_index_in_group = button_index_in_group or 1,
    })
end

function ButtonRenderer:prescanRowInsertionControls(ctx, coords, opts)
    self:beginRowInsertionPrescan()
    if not opts or not opts.editing_mode then
        return
    end
    if C.DragDropManager:isDragging() then
        return
    end
    if C.Interactions and C.Interactions.isPresetBrowserOpen and C.Interactions:isPresetBrowserOpen() then
        return
    end

    local layout = opts.layout
    local layout_source_toolbar = opts.layout_source_toolbar
    if not layout or not layout.groups or not layout_source_toolbar or not layout_source_toolbar.groups then
        return
    end

    local msx, msy = reaper.ImGui_GetMousePos(ctx)
    local is_vertical = layout.is_vertical
    local editing_mode = opts.editing_mode
    local main_offset_x = opts.main_offset_x or 0
    local main_offset_y = opts.main_offset_y or 0
    local centered_y = opts.centered_y or 0

    for gi, group_layout in ipairs(layout.groups) do
        local group = layout_source_toolbar.groups[gi]
        if group and group_layout.buttons then
            local group_x = group_layout.x + main_offset_x
            local group_y = (is_vertical and (group_layout.y or 0) or centered_y) + main_offset_y
            if opts.group_origin_fn then
                group_x, group_y = opts.group_origin_fn(gi, group_x, group_y)
            end
            local skip_params = {
                toolbar_layout = layout,
                is_vertical = is_vertical,
                group_index = gi,
                group = group,
                has_visible_label = BUTTON_UTILS.shouldShowGroupLabelRow(editing_mode, group),
            }
            for i, button_layout in ipairs(group_layout.buttons) do
                local button = group.buttons[i]
                if button and not C.GroupRenderer:shouldSkipButtonRender(skip_params, button, i) then
                    if is_vertical then
                        button_layout.is_vertical = true
                    end
                    self:collectInsertionControl(
                        ctx,
                        button,
                        group_x + button_layout.x,
                        group_y + (button_layout.y or 0),
                        button_layout.width,
                        coords,
                        msx,
                        msy,
                        is_vertical,
                        button_layout.height,
                        i
                    )
                end
            end
        end
    end

    self:finishRowInsertionPrescan(coords)
end

function ButtonRenderer:clearRowInsertionPrescan()
    self.active_insertion_control = nil
    self.pending_insertion_controls = {}
    self.control_pool_index = 0
end

-- Halfway between two adjacent buttons (gap center). Odd spacing: ceil toward +x / +y so the chip sits slightly into the newer (right/lower) cell.
local function gapCenterBeforeEdge(edge_pos, spacing)
    local c = edge_pos - spacing * 0.5
    if spacing % 2 == 1 then
        return math.ceil(c - 1e-9)
    end
    return c
end

function ButtonRenderer:renderInsertionControlsWithParams(p)
    local bh = p.button_height
    local vert = p.is_vertical
    local pos, w, m = p.position, p.width, p.mouse.relative
    -- Diameter = 60% of minimum toolbar button height (config), +0.5px radius for pixel-centering
    local outer_r = 0.3 * CONFIG.SIZES.MIN_HEIGHT + 0.5
    local sep = p.button:isSeparator()
    local spacing = CONFIG.SIZES.SPACING or 0
    local bi = p.button_index_in_group or 1

    local glyph_cx, glyph_cy, dist
    local ccx

    -- Vertical alignment in the button strip; odd height → snap down (+y)
    glyph_cy = pos.y + bh * 0.5
    if bh % 2 == 1 then
        glyph_cy = math.ceil(glyph_cy - 1e-9)
    end

    if sep then
        ccx = pos.x + w * 0.5
        if w % 2 == 1 then
            ccx = math.ceil(ccx - 1e-9)
        end
        glyph_cx = ccx
    elseif vert then
        ccx = pos.x + w * 0.5
        if w % 2 == 1 then
            ccx = math.ceil(ccx - 1e-9)
        end
        glyph_cx = ccx
    else
        ccx = pos.x
        if bi > 1 then
            glyph_cx = gapCenterBeforeEdge(pos.x, spacing)
        else
            glyph_cx = pos.x
        end
    end

    if vert and bi > 1 then
        glyph_cy = gapCenterBeforeEdge(pos.y, spacing)
    end

    local hx, hy, hw, hh = insertionHitRect(glyph_cx, glyph_cy, outer_r)
    if not (m.x >= hx and m.x <= hx + hw and m.y >= hy and m.y <= hy + hh) then
        return false
    end

    if vert then
        dist = math.abs(m.y - glyph_cy)
    else
        dist = math.abs(m.x - glyph_cx)
    end

    self.control_pool = self.control_pool or {}
    self.control_pool_index = (self.control_pool_index or 0) + 1
    local pool = self.control_pool
    local i = self.control_pool_index
    pool[i] = pool[i] or {}
    local c = pool[i]
    c.is_vertical = vert
    c.control_rel_x = ccx or glyph_cx
    c.glyph_cx_rel = glyph_cx
    c.glyph_cy_rel = glyph_cy
    c.glyph_outer_r = outer_r
    c.glyph_outer_color = p.glyph_outer_color
    c.is_separator_button = sep
    c.button_instance_id = p.button.instance_id
    c.button = p.button
    c.mouse_distance_to_center = dist

    self.pending_insertion_controls = self.pending_insertion_controls or {}
    table.insert(self.pending_insertion_controls, c)

    return false, false, false
end

function ButtonRenderer:handleInsertionControlClick(ctx, control)
    local button = control.button
    if not button then
        return
    end
    if control.is_separator_button then
        self:handleDeleteSeparator(button)
    elseif C.Interactions and C.Interactions.openInsertMenu then
        C.Interactions:openInsertMenu(ctx, button)
    end
end

function ButtonRenderer:renderPendingControlsOnTop(ctx, dl, coords)
    local close = self.active_insertion_control
    if not close then
        self:clearRowInsertionPrescan()
        return
    end

    local glyph_color = close.glyph_outer_color
    if close.button then
        CACHE_UTILS.ensureButtonCache(close.button)
        local state_key = C.Interactions:determineStateKey(close.button)
        local _, _, _, insertion_glyph_outer = COLOR_UTILS.getButtonColors(close.button, state_key, "NORMAL")
        glyph_color = COLOR_UTILS.setAlpha(insertion_glyph_outer, 0xFF)
    end

    local hx, hy, hw, hh = insertionHitRect(close.glyph_cx_rel, close.glyph_cy_rel, close.glyph_outer_r)
    local hit_id = "insertion_" .. tostring(close.button_instance_id or "btn")
    local clicked, is_hovered, is_clicked =
        C.Interactions:setupInteractionArea(ctx, hx, hy, hw, hh, hit_id, coords)
    if not clicked and coords:mouseOverRelative(hx, hy, hw, hh) and reaper.ImGui_IsMouseClicked(ctx, 0) then
        clicked = true
        is_hovered = true
    end

    local sym = close.is_separator_button and "x" or "plus"
    local gx, gy = coords:relativeToDrawList(close.glyph_cx_rel, close.glyph_cy_rel)
    DRAWING.drawSymbolGlyph(ctx, dl, gx, gy, close.glyph_outer_r, glyph_color, sym, is_hovered or is_clicked)

    if clicked then
        self:handleInsertionControlClick(ctx, close)
    end

    self:clearRowInsertionPrescan()
end
