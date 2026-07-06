function GroupRenderer:renderDragGhostButtonIfNeeded(params, button, button_layout, when)
    if not params.editing_mode or not C.DragDropManager:isDragging() then
        return
    end
    if C.DragDropManager:isGroupDrag() then
        return
    end
    local tgt = C.DragDropManager:getCurrentDropTarget()
    local src = C.DragDropManager:getDragSource()
    if not tgt or not src or not tgt.parent_group then
        return
    end
    if tgt.parent_group ~= params.group then
        return
    end
    if tgt.instance_id ~= button.instance_id then
        return
    end
    if C.DragDropManager.drop_position ~= when then
        return
    end
    local ghost_layout = BUTTON_UTILS.computeDragGhostGroupLayout(src, button_layout, params.toolbar_layout)
    local gx = params.position.x + ghost_layout.x
    local gy = params.position.y + ghost_layout.y
    local gl = {
        width = ghost_layout.width,
        height = ghost_layout.height,
        is_vertical = ghost_layout.is_vertical
    }
    C.ButtonRenderer:renderButton(
        params.ctx,
        src,
        gx,
        gy,
        params.coords,
        params.draw_list,
        params.editing_mode,
        gl,
        { ghost_mode = true }
    )
end

function GroupRenderer:renderGroupBlockGhostIfNeeded(params)
    if not params.editing_mode or not C.DragDropManager:isGroupDrag() then
        return
    end
    local dd = C.DragDropManager
    if dd.drop_target_toolbar and params.toolbar_owner and dd.drop_target_toolbar ~= params.toolbar_owner then
        return
    end
    if not dd.drop_target_group_index or not params.group_index or dd.drop_target_group_index ~= params.group_index then
        return
    end
    local payload = dd.drag_payload
    local src_grp = dd:getDragSourceGroup()
    if not payload or not src_grp or not params.toolbar_layout then
        return
    end
    local src_gi = payload.source_group_index
    local layout = params.toolbar_layout
    local tb = params.toolbar_owner
    local src_gl = nil
    if tb and tb.groups and tb.groups[src_gi] == src_grp and layout.groups[src_gi] then
        src_gl = layout.groups[src_gi]
    end
    local spacing = CONFIG.SIZES.SPACING or 0
    local is_vert = layout.is_vertical
    local drop_after = dd.drop_position == "after"
    local tgt_h = params.layout.height
    local tgt_w = params.layout.width
    local src_w, src_h
    if src_gl then
        src_w, src_h = src_gl.width, src_gl.height
    else
        src_w, src_h = 0, 0
        for bi, btn in ipairs(src_grp.buttons) do
            local gw = (btn.cached_width and btn.cached_width.total) or CONFIG.SIZES.MIN_WIDTH
            local ghh = CONFIG.SIZES.HEIGHT
            if btn:isSeparator() then
                if is_vert then
                    gw = params.layout.width
                    ghh = (btn.cache.layout and btn.cache.layout.height) or CONFIG.SIZES.SEPARATOR_SIZE
                else
                    gw = (btn.cache.layout and btn.cache.layout.width) or CONFIG.SIZES.SEPARATOR_SIZE
                end
            elseif is_vert then
                gw = params.layout.width
            end
            if is_vert then
                src_h = src_h + ghh + (bi < #src_grp.buttons and spacing or 0)
                src_w = math.max(src_w, gw)
            else
                src_w = src_w + gw + (bi < #src_grp.buttons and spacing or 0)
                src_h = math.max(src_h, ghh)
            end
        end
        local _lbl = BUTTON_UTILS.shouldShowGroupLabelRow(params.editing_mode, src_grp)
        if _lbl then
            src_h = src_h + 20
        end
    end
    local bx = params.position.x
    local by = params.position.y
    if is_vert then
        if drop_after then
            by = by + tgt_h + spacing
        else
            by = by - src_h - spacing
        end
    else
        if drop_after then
            bx = bx + tgt_w + spacing
        else
            bx = bx - src_w - spacing
        end
    end
    local ox, oy = bx, by
    for bi, btn in ipairs(src_grp.buttons) do
        local bl = src_gl and src_gl.buttons[bi]
        local gw = bl and bl.width or ((btn.cached_width and btn.cached_width.total) or CONFIG.SIZES.MIN_WIDTH)
        local ghh = bl and bl.height or CONFIG.SIZES.HEIGHT
        if not bl then
            if btn:isSeparator() then
                if is_vert then
                    gw = params.layout.width
                    ghh = (btn.cache.layout and btn.cache.layout.height) or CONFIG.SIZES.SEPARATOR_SIZE
                else
                    gw = (btn.cache.layout and btn.cache.layout.width) or CONFIG.SIZES.SEPARATOR_SIZE
                end
            elseif is_vert then
                gw = params.layout.width
            end
        end
        local gl = { width = gw, height = ghh, is_vertical = is_vert }
        C.ButtonRenderer:renderButton(
            params.ctx,
            btn,
            ox,
            oy,
            params.coords,
            params.draw_list,
            params.editing_mode,
            gl,
            { ghost_mode = true }
        )
        if is_vert then
            oy = oy + ghh + spacing
        else
            ox = ox + gw + spacing
        end
    end
    if BUTTON_UTILS.shouldShowGroupLabelRow(params.editing_mode, src_grp) then
        local ghost_params = {
            group = src_grp,
            layout = src_gl or params.layout,
            toolbar_layout = params.toolbar_layout,
            is_vertical = is_vert,
            has_visible_label = is_vert and BUTTON_UTILS.shouldShowGroupLabelRow(params.editing_mode, src_grp),
            group_index = src_gi,
            position = { x = bx, y = by },
        }
        local label_x, label_w = self:measureGroupLabelBounds(ghost_params)
        local ch = src_gl and src_gl.content_height or (is_vert and math.max(0, src_h - 20) or CONFIG.SIZES.HEIGHT)
        local label_text = BUTTON_UTILS.getGroupLabelTextForRender(params.editing_mode, src_grp)
        self:renderGroupLabelGhost(
            params.ctx,
            label_x,
            by,
            ch,
            label_w,
            params.coords,
            params.draw_list,
            params.toolbar_layout,
            label_text
        )
    end
end

-- Button drag onto trailing zone (new group after last): ghost after this group's bounds.
function GroupRenderer:renderTrailingNewGroupButtonGhostIfNeeded(params)
    if not params.editing_mode or not C.DragDropManager:isDragging() then
        return
    end
    if C.DragDropManager:isGroupDrag() then
        return
    end
    local dt = C.DragDropManager.drop_trailing_new_group_toolbar
    if not dt or not params.toolbar_owner or dt ~= params.toolbar_owner then
        return
    end
    local tl = params.toolbar_layout
    if not tl or not tl.groups or #tl.groups < 1 or params.group_index ~= #tl.groups then
        return
    end
    local src = C.DragDropManager:getDragSource()
    if not src or src:isSeparator() then
        return
    end
    local ref_bl = params.layout.buttons and params.layout.buttons[1]
    if not ref_bl then
        return
    end
    local spacing = CONFIG.SIZES.SPACING or 0
    local is_vert = tl.is_vertical
    local gw = (src.cached_width and src.cached_width.total) or CONFIG.SIZES.MIN_WIDTH
    local gh = CONFIG.SIZES.HEIGHT
    if is_vert then
        gw = ref_bl.width
    end
    local bx = params.position.x
    local by = params.position.y
    if is_vert then
        by = by + params.layout.height + spacing
    else
        bx = bx + params.layout.width + spacing
        by = by + (ref_bl.y or 0)
    end
    local gl = { width = gw, height = gh, is_vertical = is_vert }
    C.ButtonRenderer:renderButton(
        params.ctx,
        src,
        bx,
        by,
        params.coords,
        params.draw_list,
        params.editing_mode,
        gl,
        { ghost_mode = true }
    )
end

