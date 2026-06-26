-- Managers/Layout/Ghost.lua
return function(LayoutManager)
function LayoutManager:cloneToolbarLayout(layout)
    local L = self._drag_ghost_scratch
    if not L then
        L = { groups = {} }
        self._drag_ghost_scratch = L
    end
    for k, v in pairs(layout) do
        if k ~= "groups" then
            L[k] = v
        end
    end
    local src_groups = layout.groups or {}
    while #L.groups > #src_groups do
        table.remove(L.groups)
    end
    for gi, gl in ipairs(src_groups) do
        local NG = L.groups[gi]
        if not NG then
            NG = { buttons = {} }
            L.groups[gi] = NG
        else
            NG.buttons = NG.buttons or {}
        end
        for k, v in pairs(gl) do
            if k ~= "buttons" then
                NG[k] = v
            end
        end
        while #NG.buttons > #(gl.buttons or {}) do
            table.remove(NG.buttons)
        end
        for bi, bl in ipairs(gl.buttons or {}) do
            local NB = NG.buttons[bi]
            if not NB then
                NB = {}
                NG.buttons[bi] = NB
            end
            NB.x = bl.x
            NB.y = bl.y
            NB.width = bl.width
            NB.height = bl.height
            NB.is_vertical = bl.is_vertical
            NB.title_height = bl.title_height
            NB.title_lines = bl.title_lines
        end
    end
    return L
end

-- Width/height of dragged group for ghost reserve when source layout row is not on this toolbar's layout (cross-toolbar).
local function estimate_drag_source_group_extent(src_grp, layout, editing_mode, tgt_group_layout)
    if not src_grp or not layout then
        return 0, 0
    end
    local spacing = CONFIG.SIZES.SPACING or 0
    local is_vert = layout.is_vertical
    local tw = tgt_group_layout and tgt_group_layout.width or 0
    local src_w, src_h = 0, 0
    for bi, btn in ipairs(src_grp.buttons) do
        local gw = (btn.cached_width and btn.cached_width.total) or CONFIG.SIZES.MIN_WIDTH
        local ghh = CONFIG.SIZES.HEIGHT
        if btn:isSeparator() then
            if is_vert then
                gw = tw > 0 and tw or CONFIG.SIZES.MIN_WIDTH
                ghh = (btn.cache.layout and btn.cache.layout.height) or CONFIG.SIZES.SEPARATOR_SIZE
            else
                gw = (btn.cache.layout and btn.cache.layout.width) or CONFIG.SIZES.SEPARATOR_SIZE
            end
        elseif is_vert then
            gw = tw > 0 and tw or CONFIG.SIZES.MIN_WIDTH
        end
        if is_vert then
            src_h = src_h + ghh + (bi < #src_grp.buttons and spacing or 0)
            src_w = math.max(src_w, gw)
        else
            src_w = src_w + gw + (bi < #src_grp.buttons and spacing or 0)
            src_h = math.max(src_h, ghh)
        end
    end
    if BUTTON_UTILS.shouldShowGroupLabelRow(editing_mode, src_grp) then
        src_h = src_h + 20
    end
    return src_w, src_h
end

-- Reserve space for whole-group drag ghost by shifting following groups.
function LayoutManager:applyGroupDragGhostLayoutShift(layout, toolbar)
    local dd = C.DragDropManager
    if not layout or not toolbar or not dd or not dd:isGroupDrag() then
        return nil
    end
    local payload = dd.drag_payload
    local src_gi = payload and payload.source_group_index
    local tgt_toolbar = dd.drop_target_toolbar
    local tgt_gi = dd.drop_target_group_index
    if not src_gi or not tgt_toolbar or not tgt_gi then
        return nil
    end
    if tgt_toolbar.section ~= toolbar.section then
        return nil
    end
    if src_gi == tgt_gi then
        return nil
    end
    local src_grp = dd:getDragSourceGroup()
    local src_gl = nil
    if src_grp and toolbar.groups[src_gi] == src_grp and layout.groups[src_gi] then
        src_gl = layout.groups[src_gi]
    end
    local tgt_gl = layout.groups[tgt_gi]
    local spacing = CONFIG.SIZES.SPACING or 0
    local delta
    if src_gl then
        delta = layout.is_vertical and (src_gl.height + spacing) or (src_gl.width + spacing)
    elseif src_grp then
        local ew, eh = estimate_drag_source_group_extent(src_grp, layout, self._layout_editing_mode, tgt_gl)
        delta = layout.is_vertical and (eh + spacing) or (ew + spacing)
    else
        return nil
    end
    if not delta or delta <= 0 then
        return nil
    end
    local drop_after = dd.drop_position == "after"
    local start_g = drop_after and (tgt_gi + 1) or tgt_gi
    local L = self:cloneToolbarLayout(layout)
    if layout.is_vertical then
        for g = start_g, #L.groups do
            L.groups[g].y = (L.groups[g].y or 0) + delta
        end
        L.height = (L.height or 0) + delta
    else
        for g = start_g, #L.groups do
            L.groups[g].x = (L.groups[g].x or 0) + delta
        end
        L.width = (L.width or 0) + delta
    end
    if L.split_point then
        self:adjustLayoutForSplit(L)
        self:computeSplitCenterOffsets(L)
    end
    return L
end

-- Reserve space for the drag ghost by shifting buttons/groups (visual only; does not mutate cached layout).
function LayoutManager:applyDragGhostLayoutShift(layout, toolbar)
    if not layout or not toolbar or not C.DragDropManager or not C.DragDropManager:isDragging() then
        return nil
    end
    if C.DragDropManager:isGroupDrag() then
        return self:applyGroupDragGhostLayoutShift(layout, toolbar)
    end
    local dd_btn = C.DragDropManager
    local dt_tb = dd_btn.drop_trailing_new_group_toolbar
    if dt_tb and toolbar.section == dt_tb.section and layout.groups and #layout.groups >= 1 then
        local src_tb = dd_btn:getDragSource()
        if src_tb and not src_tb:isSeparator() then
            local GL_last = layout.groups[#layout.groups]
            local bl = GL_last.buttons and GL_last.buttons[1]
            if bl then
                local ghost_geom = BUTTON_UTILS.computeDragGhostGroupLayout(src_tb, bl, layout)
                local spacing = CONFIG.SIZES.SPACING or 0
                local delta = layout.is_vertical and (ghost_geom.height + spacing) or (ghost_geom.width + spacing)
                local L = self:cloneToolbarLayout(layout)
                if layout.is_vertical then
                    L.height = (L.height or 0) + delta
                else
                    L.width = (L.width or 0) + delta
                end
                if L.split_point then
                    self:adjustLayoutForSplit(L)
                    self:computeSplitCenterOffsets(L)
                end
                return L
            end
        end
    end
    local tgt = C.DragDropManager:getCurrentDropTarget()
    local src = C.DragDropManager:getDragSource()
    if not tgt or not src or tgt.is_empty_toolbar_placeholder then
        return nil
    end
    local gi, bi = findGroupButtonIndex(toolbar, tgt)
    if not gi or not bi then
        return nil
    end
    local GL_src = layout.groups[gi]
    local button_layout = GL_src.buttons[bi]
    if not button_layout then
        return nil
    end
    local ghost_geom = BUTTON_UTILS.computeDragGhostGroupLayout(src, button_layout, layout)
    local spacing = CONFIG.SIZES.SPACING or 0
    local delta
    if layout.is_vertical then
        delta = ghost_geom.height + spacing
    else
        delta = ghost_geom.width + spacing
    end
    local drop_after = C.DragDropManager.drop_position == "after"
    local start_idx = drop_after and (bi + 1) or bi

    local L = self:cloneToolbarLayout(layout)
    local GL = L.groups[gi]

    if layout.is_vertical then
        local n = #GL.buttons
        for k = start_idx, n do
            GL.buttons[k].y = GL.buttons[k].y + delta
        end
        GL.height = (GL.height or 0) + delta
        if GL.content_height then
            GL.content_height = GL.content_height + delta
        end
        for g = gi + 1, #L.groups do
            L.groups[g].y = (L.groups[g].y or 0) + delta
        end
        L.height = (L.height or 0) + delta
    else
        local n = #GL.buttons
        for k = start_idx, n do
            GL.buttons[k].x = GL.buttons[k].x + delta
        end
        GL.width = (GL.width or 0) + delta
        for g = gi + 1, #L.groups do
            L.groups[g].x = (L.groups[g].x or 0) + delta
        end
        L.width = (L.width or 0) + delta
    end

    if L.split_point then
        self:adjustLayoutForSplit(L)
        self:computeSplitCenterOffsets(L)
    end
    return L
end

return LayoutManager
end
