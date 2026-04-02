-- Renderers/02_Group.lua

local GroupRenderer = {}
GroupRenderer.__index = GroupRenderer

function GroupRenderer.new()
    local self = setmetatable({}, GroupRenderer)
    return self
end

local function lighten_rgba(c, delta)
    if not c then
        return c
    end
    local a = c & 0xFF
    local r = (c >> 24) & 0xFF
    local g = (c >> 16) & 0xFF
    local b = (c >> 8) & 0xFF
    r = math.min(255, r + delta)
    g = math.min(255, g + delta)
    b = math.min(255, b + delta)
    return (r << 24) | (g << 16) | (b << 8) | a
end

local function ghost_tint(color)
    if not color then
        return color
    end
    local a = color & 0xFF
    return (color & 0xFFFFFF00) | math.floor(a * 0.5)
end

-- Create render parameters object for group
function GroupRenderer:createGroupParams(ctx, group, pos_x, pos_y, coords, draw_list, editing_mode, layout, toolbar_layout, group_index, toolbar_owner)
    local is_vertical = toolbar_layout and toolbar_layout.is_vertical
    return {
        ctx = ctx,
        group = group,
        position = {x = pos_x, y = pos_y},
        coords = coords,
        draw_list = draw_list,
        editing_mode = editing_mode,
        layout = layout,
        toolbar_layout = toolbar_layout,
        is_vertical = is_vertical,
        has_visible_label = is_vertical and BUTTON_UTILS.shouldShowGroupLabelRow(editing_mode, group),
        group_index = group_index,
        toolbar_owner = toolbar_owner
    }
end

function GroupRenderer:renderGroup(ctx, group, pos_x, pos_y, coords, draw_list, editing_mode, layout, toolbar_layout, group_index, toolbar_owner)
    local params = self:createGroupParams(
        ctx,
        group,
        pos_x,
        pos_y,
        coords,
        draw_list,
        editing_mode,
        layout,
        toolbar_layout,
        group_index,
        toolbar_owner
    )
    return self:renderGroupWithParams(params)
end

-- Render group (using params object)
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
        local tww = src_gl and src_gl.width or src_w
        local ch = src_gl and src_gl.content_height or (is_vert and math.max(0, src_h - 20) or CONFIG.SIZES.HEIGHT)
        local label_text = BUTTON_UTILS.getGroupLabelTextForRender(params.editing_mode, src_grp)
        self:renderGroupLabelGhost(
            params.ctx,
            bx,
            by,
            ch,
            tww,
            params.coords,
            params.draw_list,
            params.toolbar_layout,
            label_text
        )
    end
end

function GroupRenderer:renderGroupWithParams(params)
    self:renderGroupBlockGhostIfNeeded(params)
    local current_x = params.position.x
    
    -- Render all buttons (including separators)
    for i, button_layout in ipairs(params.layout.buttons) do
        local button = params.group.buttons[i]
        local button_y = params.position.y + (button_layout.y or 0)
        
        -- Ensure button_layout has is_vertical from toolbar layout
        if params.toolbar_layout and params.toolbar_layout.is_vertical then
            button_layout.is_vertical = true
        end
        
        -- In vertical mode, skip rendering separator if it's the last button and group has visible label
        if BUTTON_UTILS.shouldSkipSeparatorInVerticalMode(button, params.is_vertical, params.has_visible_label) then
            -- Skip rendering this separator
        else
            self:renderDragGhostButtonIfNeeded(params, button, button_layout, "before")
            C.ButtonRenderer:renderButton(
                params.ctx,
                button,
                current_x + button_layout.x,
                button_y,
                params.coords,
                params.draw_list,
                params.editing_mode,
                button_layout
            )
            self:renderDragGhostButtonIfNeeded(params, button, button_layout, "after")
        end
    end

    -- Render group label if needed
    local decoration_width = params.layout.width
    if BUTTON_UTILS.shouldShowGroupLabelRow(params.editing_mode, params.group) then
        -- In horizontal mode separators contribute to width; in vertical mode they contribute to height.
        if (not params.is_vertical) and BUTTON_UTILS.groupHasSeparator(params.group) then
            decoration_width = decoration_width - CONFIG.SIZES.SEPARATOR_SIZE
        end
        self:renderGroupLabel(
            params.ctx,
            params.group,
            params.position.x,
            params.position.y,
            decoration_width,
            params.coords,
            params.draw_list,
            params.layout,
            params.toolbar_layout,
            params.editing_mode,
            params.toolbar_owner,
            params.group_index
        )
    end

    return params.layout.width, params.layout.height
end

-- Ensure label cache exists and is initialized
function GroupRenderer:ensureLabelCache(group)
    CACHE_UTILS.ensureGroupCacheSubtable(group, "label")
    return group.cache.label
end

-- Check if label cache needs recalculation
function GroupRenderer:needsLabelRecalculation(label_cache, group, pos_x, pos_y, total_width, is_vertical, padding_x, editing_mode)
    local eff = BUTTON_UTILS.getGroupLabelTextForRender(editing_mode, group)
    return not label_cache.text or
           label_cache.text ~= eff or
           label_cache.pos_x ~= pos_x or
           label_cache.pos_y ~= pos_y or
           label_cache.total_width ~= total_width or
           label_cache.is_vertical ~= is_vertical or
           label_cache.padding_x ~= padding_x
end

-- Calculate label position and cache text dimensions
function GroupRenderer:calculateLabelPosition(ctx, label_cache, group, pos_x, pos_y, total_width, content_height, is_vertical, padding_x, editing_mode)
    local disp = BUTTON_UTILS.getGroupLabelTextForRender(editing_mode, group)
    local text_width = reaper.ImGui_CalcTextSize(ctx, disp)
    local text_height = reaper.ImGui_GetTextLineHeight(ctx)
    
    label_cache.text = disp
    label_cache.pos_x = pos_x
    label_cache.pos_y = pos_y
    label_cache.total_width = total_width
    label_cache.text_width = text_width
    label_cache.text_height = text_height
    label_cache.is_vertical = is_vertical
    label_cache.padding_x = padding_x
    
    -- In vertical mode, center within the group's absolute content span.
    if is_vertical then
        label_cache.label_rel_x = pos_x + (total_width / 2) - text_width / 2.18
    else
        label_cache.label_rel_x = pos_x + (total_width / 2) - text_width / 2.18
    end
    label_cache.label_rel_y = pos_y + content_height + 1
    
    -- Use cached color for performance
    label_cache.label_color = CONFIG_MANAGER:getCachedColorSafe("GROUP", "LABEL") or COLOR_UTILS.toImGuiColor(CONFIG.COLORS.GROUP.LABEL)
end

-- Render label text
function GroupRenderer:renderLabelText(draw_list, coords, label_cache)
    local draw_label_x, draw_label_y = coords:relativeToDrawList(label_cache.label_rel_x, label_cache.label_rel_y)
    
    reaper.ImGui_DrawList_AddText(
        draw_list,
        draw_label_x,
        draw_label_y,
        label_cache.label_color,
        label_cache.text
    )
    
    return draw_label_x, draw_label_y
end

function GroupRenderer:renderGroupLabelGhost(ctx, pos_x, pos_y, content_height, total_width, coords, draw_list, toolbar_layout, label_text)
    local is_vertical = toolbar_layout and toolbar_layout.is_vertical
    local padding_x = (toolbar_layout and toolbar_layout.padding_x) or CONFIG.SIZES.PADDING
    local tw = reaper.ImGui_CalcTextSize(ctx, label_text)
    local th = reaper.ImGui_GetTextLineHeight(ctx)
    local label_rel_x
    if is_vertical then
        label_rel_x = pos_x + (total_width / 2) - tw / 2.18
    else
        label_rel_x = pos_x + (total_width / 2) - tw / 2.18
    end
    local label_rel_y = pos_y + content_height + 1
    local draw_label_x, draw_label_y = coords:relativeToDrawList(label_rel_x, label_rel_y)
    local lc = ghost_tint(CONFIG_MANAGER:getCachedColorSafe("GROUP", "LABEL") or COLOR_UTILS.toImGuiColor(CONFIG.COLORS.GROUP.LABEL))
    reaper.ImGui_DrawList_AddText(draw_list, draw_label_x, draw_label_y, lc, label_text)
    local dc = ghost_tint(CONFIG_MANAGER:getCachedColorSafe("GROUP", "DECORATION") or COLOR_UTILS.toImGuiColor(CONFIG.COLORS.GROUP.DECORATION))
    self:renderLabelDecoration(
        draw_list,
        draw_label_x,
        draw_label_y + (th / 2) + 1,
        tw,
        th,
        coords:relativeToDrawList(pos_x, 0),
        is_vertical,
        dc
    )
end

function GroupRenderer:ensureGroupLabelDragState(group)
    CACHE_UTILS.ensureGroupCacheSubtable(group, "label_drag_state")
    local s = group.cache.label_drag_state
    if s.was_dragging_last_frame == nil then
        s.was_dragging_last_frame = false
    end
    if s.mouse_down_on_button == nil then
        s.mouse_down_on_button = false
    end
    return s
end

function GroupRenderer:handleGroupLabelDragDrop(ctx, group, toolbar_owner, is_hovered, display_label)
    local ds = self:ensureGroupLabelDragState(group)
    local mouse_dragging = reaper.ImGui_IsMouseDragging(ctx, 0)
    local mouse_down = reaper.ImGui_IsMouseDown(ctx, 0)
    if is_hovered and reaper.ImGui_IsMouseClicked(ctx, 0) then
        ds.mouse_down_on_button = true
    end
    if not mouse_down then
        ds.mouse_down_on_button = false
    end
    if BUTTON_UTILS.canStartDrag(ds, mouse_dragging) and toolbar_owner then
        C.DragDropManager:startGroupDrag(ctx, group, toolbar_owner, display_label)
    end
    ds.was_dragging_last_frame = mouse_dragging
end

function GroupRenderer:promptGroupRename(group, toolbar_owner)
    if not group or not toolbar_owner then
        return
    end
    local current_name = (group.group_label and group.group_label.text) or ""
    local ok, new_name = reaper.GetUserInputs("Group Name", 1, "Group Name:,extrawidth=100", current_name)
    if not ok then
        return
    end
    group.group_label = group.group_label or {}
    group.group_label.text = new_name or ""
    if CONFIG_MANAGER and CONFIG_MANAGER.saveToolbarConfig then
        CONFIG_MANAGER:saveToolbarConfig(toolbar_owner)
    end
end

-- Main group label rendering function (orchestration)
function GroupRenderer:renderGroupLabel(ctx, group, pos_x, pos_y, total_width, coords, draw_list, layout, toolbar_layout, editing_mode, toolbar_owner, group_index)
    local label_cache = self:ensureLabelCache(group)
    
    local content_height = (layout and layout.content_height) or CONFIG.SIZES.HEIGHT
    local is_vertical = toolbar_layout and toolbar_layout.is_vertical
    -- Use padding_x from toolbar_layout, or fall back to CONFIG.SIZES.PADDING if not available
    local padding_x = (toolbar_layout and toolbar_layout.padding_x) or CONFIG.SIZES.PADDING
    
    -- Recalculate if needed
    if self:needsLabelRecalculation(label_cache, group, pos_x, pos_y, total_width, is_vertical, padding_x, editing_mode) then
        self:calculateLabelPosition(ctx, label_cache, group, pos_x, pos_y, total_width, content_height, is_vertical, padding_x, editing_mode)
    end

    if C.DragDropManager:shouldOmitDragSourceGroupLabel(group) then
        local th = label_cache.text_height
        return (th and th > 0) and (th + 8) or 20
    end

    local hit_pad = 4
    local hit_x1 = math.min(label_cache.label_rel_x, label_cache.label_rel_x + label_cache.text_width) - hit_pad
    local hit_y1 = label_cache.label_rel_y - hit_pad
    local hit_w = label_cache.text_width + 2 * hit_pad + 24
    local hit_h = label_cache.text_height + 2 * hit_pad + 10

    local label_draw_color = label_cache.label_color
    local deco_draw_color = CONFIG_MANAGER:getCachedColorSafe("GROUP", "DECORATION") or COLOR_UTILS.toImGuiColor(CONFIG.COLORS.GROUP.DECORATION)
    local is_hovered = false
    if editing_mode and toolbar_owner and not C.DragDropManager:isDragging() then
        local scr_x, scr_y = coords:relativeToDrawList(hit_x1, hit_y1)
        reaper.ImGui_SetCursorScreenPos(ctx, scr_x, scr_y)
        -- Unique ID stack: duplicated configs can reuse button instance_ids across groups; section + index must differ.
        local sec = (toolbar_owner.section and tostring(toolbar_owner.section):gsub("#", "_")) or "toolbar"
        local gi = tonumber(group_index) or 0
        reaper.ImGui_PushID(ctx, sec .. "_grp_" .. gi)
        reaper.ImGui_InvisibleButton(ctx, "##glabel_hit", hit_w, hit_h)
        is_hovered = reaper.ImGui_IsItemHovered(ctx)
        if is_hovered and reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
            self:promptGroupRename(group, toolbar_owner)
            local ds = self:ensureGroupLabelDragState(group)
            ds.mouse_down_on_button = false
            ds.was_dragging_last_frame = false
        end
        reaper.ImGui_PopID(ctx)
        local hint_key = sec .. "_glabel_" .. gi
        C.Interactions:updateEditModeGroupLabelDragHint(ctx, hint_key, is_hovered)
        if is_hovered then
            label_draw_color = lighten_rgba(label_cache.label_color, 40)
            deco_draw_color = lighten_rgba(deco_draw_color, 40)
        end
        self:handleGroupLabelDragDrop(ctx, group, toolbar_owner, is_hovered, label_cache.text)
    end

    if C.DragDropManager:isGroupDrag() and C.DragDropManager:getDragSourceGroup() == group then
        label_draw_color = label_draw_color & 0xFFFFFF88
        deco_draw_color = deco_draw_color & 0xFFFFFF88
    end

    local draw_label_x, draw_label_y = coords:relativeToDrawList(label_cache.label_rel_x, label_cache.label_rel_y)
    reaper.ImGui_DrawList_AddText(draw_list, draw_label_x, draw_label_y, label_draw_color, label_cache.text)

    local decoration_pos_x = pos_x
    self:renderLabelDecoration(
        draw_list,
        draw_label_x,
        draw_label_y + (label_cache.text_height / 2) + 1,
        label_cache.text_width,
        label_cache.text_height,
        coords:relativeToDrawList(decoration_pos_x, 0),
        is_vertical,
        deco_draw_color
    )

    return label_cache.text_height + 8
end

-- Calculate decoration geometry (line positions, curve parameters)
function GroupRenderer:calculateDecorationGeometry(label_x, label_y, text_width, text_height, pos_x_draw, is_vertical)
    local line_thickness = 1.0
    local h_padding = 8
    
    -- In vertical mode, use button rounding directly; in horizontal, add extra rounding
    local rounding
    if is_vertical then
        rounding = CONFIG.SIZES.ROUNDING
    else
        rounding = math.min(CONFIG.SIZES.ROUNDING, CONFIG.SIZES.HEIGHT / 2)
    end
    
    -- In vertical mode, curve_size should only be the rounding value (no extra terms)
    -- In horizontal mode, add extra terms for the curve
    local curve_size
    if is_vertical then
        curve_size = rounding
    else
        curve_size = rounding + 4 + text_height / 2
    end

    local left_line_start = label_x - h_padding
    -- In vertical mode, start decoration exactly at pos_x_draw (same x as buttons)
    -- In horizontal mode, offset by curve_size
    local left_line_end
    if is_vertical then
        left_line_end = pos_x_draw
    else
        left_line_end = pos_x_draw + curve_size - h_padding
    end

    local right_line_start = label_x + text_width + h_padding
    local right_line_end = right_line_start + (left_line_start - left_line_end) - 2

    return {
        left_line_start = left_line_start,
        left_line_end = left_line_end,
        right_line_start = right_line_start,
        right_line_end = right_line_end,
        label_y = label_y,
        curve_size = curve_size,
        line_thickness = line_thickness
    }
end

-- Draw a single curve segment
function GroupRenderer:drawCurveSegment(draw_list, line_end, label_y, curve_size, t, next_t, is_left, line_color, line_thickness)
    local alpha = is_left and (1 - t) or t
    local angle = is_left and (math.pi * (1 - t) / 2) or (math.pi * t / 2)
    local next_angle = is_left and (math.pi * (1 - next_t) / 2) or (math.pi * next_t / 2)
    
    local curve_x = line_end + (is_left and -1 or 1) * curve_size * math.cos(angle)
    local curve_y = label_y - curve_size + curve_size * math.sin(angle)
    
    local next_x = line_end + (is_left and -1 or 1) * curve_size * math.cos(next_angle)
    local next_y = label_y - curve_size + curve_size * math.sin(next_angle)
    
    local color = (line_color & 0xFFFFFF00) | math.floor((line_color & 0xFF) * alpha)
    
    reaper.ImGui_DrawList_AddLine(draw_list, curve_x, curve_y, next_x, next_y, color, line_thickness)
end

-- Render decoration lines (horizontal lines)
function GroupRenderer:renderDecorationLines(draw_list, geometry, line_color)
    reaper.ImGui_DrawList_AddLine(
        draw_list,
        geometry.left_line_start,
        geometry.label_y,
        geometry.left_line_end,
        geometry.label_y,
        line_color,
        geometry.line_thickness
    )
    reaper.ImGui_DrawList_AddLine(
        draw_list,
        geometry.right_line_start,
        geometry.label_y,
        geometry.right_line_end,
        geometry.label_y,
        line_color,
        geometry.line_thickness
    )
end

-- Render decoration curves
function GroupRenderer:renderDecorationCurves(draw_list, geometry, line_color)
    local segments = 16
    for i = 0, segments - 1 do
        local t = i / segments
        local next_t = (i + 1) / segments
        
        -- Draw left curve segment
        self:drawCurveSegment(
            draw_list,
            geometry.left_line_end,
            geometry.label_y,
            geometry.curve_size,
            t,
            next_t,
            true, -- is_left
            line_color,
            geometry.line_thickness
        )
        
        -- Draw right curve segment
        self:drawCurveSegment(
            draw_list,
            geometry.right_line_end,
            geometry.label_y,
            geometry.curve_size,
            t,
            next_t,
            false, -- is_left
            line_color,
            geometry.line_thickness
        )
    end
end

-- Main label decoration rendering function (orchestration)
function GroupRenderer:renderLabelDecoration(draw_list, label_x, label_y, text_width, text_height, pos_x_draw, is_vertical, line_color_override)
    local line_color = line_color_override or CONFIG_MANAGER:getCachedColorSafe("GROUP", "DECORATION") or
        COLOR_UTILS.toImGuiColor(CONFIG.COLORS.GROUP.DECORATION)
    
    -- Calculate geometry
    local geometry = self:calculateDecorationGeometry(label_x, label_y, text_width, text_height, pos_x_draw, is_vertical)
    
    -- Render lines
    self:renderDecorationLines(draw_list, geometry, line_color)
    
    -- Render curves
    self:renderDecorationCurves(draw_list, geometry, line_color)
end

return GroupRenderer.new()