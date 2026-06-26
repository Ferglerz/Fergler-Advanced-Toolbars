-- Renderers/02_Group.lua

local DRAWING = require("Utils.drawing")
local GroupRenderer = {}
GroupRenderer.__index = GroupRenderer

function GroupRenderer.new()
    local self = setmetatable({}, GroupRenderer)
    return self
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

function GroupRenderer:shouldSkipButtonRender(params, button, button_index)
    if params.toolbar_layout
        and params.toolbar_layout.split_active
        and params.toolbar_layout.split_point
        and params.group_index == params.toolbar_layout.split_point - 1
        and button:isSeparator()
        and button_index == #params.group.buttons then
        return true
    end
    if BUTTON_UTILS.shouldSkipSeparatorInVerticalMode(button, params.is_vertical, params.has_visible_label) then
        return true
    end
    return false
end

-- Span used to center the group label/decoration on what is actually drawn (not stale layout.width).
function GroupRenderer:shouldOmitButtonFromLabelSpan(params, button, button_index)
    if params.toolbar_layout
        and params.toolbar_layout.split_active
        and params.toolbar_layout.split_point
        and params.group_index == params.toolbar_layout.split_point - 1
        and button:isSeparator()
        and button_index == #params.group.buttons then
        return true
    end
    -- Parsed groups end on a separator; it is not part of the label/decoration span.
    if not params.is_vertical and button:isSeparator() and button_index == #params.group.buttons then
        return true
    end
    if BUTTON_UTILS.shouldSkipSeparatorInVerticalMode(button, params.is_vertical, params.has_visible_label) then
        return true
    end
    local bl = params.layout.buttons[button_index]
    if bl and (bl.width or 0) <= 0 and (bl.height or 0) <= 0 then
        return true
    end
    return false
end

function GroupRenderer:createLabelSpanAccumulator(is_vertical, fallback_x, fallback_w)
    return {
        is_vertical = is_vertical,
        fallback_x = fallback_x,
        fallback_w = fallback_w,
        left = nil,
        right = 0,
    }
end

function GroupRenderer:extendLabelSpanFromButton(span, abs_x, button_layout)
    if span.is_vertical then
        return
    end
    local right = abs_x + (button_layout.width or 0)
    span.left = span.left and math.min(span.left, abs_x) or abs_x
    span.right = math.max(span.right, right)
end

function GroupRenderer:labelSpanFromAccumulator(span)
    if span.is_vertical then
        return span.fallback_x, span.fallback_w
    end
    if span.left then
        return span.left, span.right - span.left
    end
    return span.fallback_x, span.fallback_w
end

function GroupRenderer:measureGroupLabelBounds(params)
    local layout = params.layout
    local px = params.position.x
    if not layout then
        return px, 0
    end
    if params.is_vertical then
        return px, layout.width or 0
    end

    local span = self:createLabelSpanAccumulator(false, px, layout.width or 0)
    for i, bl in ipairs(layout.buttons or {}) do
        local button = params.group.buttons[i]
        if not button or self:shouldOmitButtonFromLabelSpan(params, button, i) then
            goto continue
        end
        self:extendLabelSpanFromButton(span, px + (bl.x or 0), bl)
        ::continue::
    end
    return self:labelSpanFromAccumulator(span)
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

function GroupRenderer:renderGroupWithParams(params)
    self:renderGroupBlockGhostIfNeeded(params)
    self:renderTrailingNewGroupButtonGhostIfNeeded(params)
    local current_x = params.position.x
    local label_span = self:createLabelSpanAccumulator(
        params.is_vertical,
        params.position.x,
        params.layout and params.layout.width or 0
    )

    -- Render all buttons (including separators)
    for i, button_layout in ipairs(params.layout.buttons) do
        local button = params.group.buttons[i]
        local button_y = params.position.y + (button_layout.y or 0)

        -- Ensure button_layout has is_vertical from toolbar layout
        if params.toolbar_layout and params.toolbar_layout.is_vertical then
            button_layout.is_vertical = true
        end

        if self:shouldSkipButtonRender(params, button, i) then
            -- Skip rendering this separator
        else
            local button_x = current_x + button_layout.x
            self:renderDragGhostButtonIfNeeded(params, button, button_layout, "before")
            C.ButtonRenderer:renderButton(
                params.ctx,
                button,
                button_x,
                button_y,
                params.coords,
                params.draw_list,
                params.editing_mode,
                button_layout,
                { button_index_in_group = i }
            )
            self:renderDragGhostButtonIfNeeded(params, button, button_layout, "after")
            if not self:shouldOmitButtonFromLabelSpan(params, button, i) then
                self:extendLabelSpanFromButton(label_span, button_x, button_layout)
            end
        end
    end

    -- Render group label if needed
    if BUTTON_UTILS.shouldShowGroupLabelRow(params.editing_mode, params.group) then
        local label_x, label_w = self:labelSpanFromAccumulator(label_span)
        self:renderGroupLabel(
            params.ctx,
            params.group,
            label_x,
            params.position.y,
            label_w,
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
function GroupRenderer:needsLabelRecalculation(label_cache, group, pos_x, pos_y, total_width, content_height, is_vertical, padding_x, editing_mode)
    local eff = BUTTON_UTILS.getGroupLabelTextForRender(editing_mode, group)
    return not label_cache.text or
           label_cache.text ~= eff or
           label_cache.pos_x ~= pos_x or
           label_cache.pos_y ~= pos_y or
           label_cache.total_width ~= total_width or
           label_cache.content_height ~= content_height or
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
    label_cache.content_height = content_height
    label_cache.text_width = text_width
    label_cache.text_height = text_height
    label_cache.is_vertical = is_vertical
    label_cache.padding_x = padding_x
    
    label_cache.label_rel_x = pos_x
    label_cache.label_rel_y = pos_y + content_height + 1
    
    -- Use cached color for performance
    label_cache.label_color = CONFIG_MANAGER:color("GROUP", "LABEL")
end

-- Render label text
function GroupRenderer:renderLabelText(ctx, draw_list, coords, label_cache)
    DRAWING.drawCenteredText(
        ctx,
        coords,
        draw_list,
        label_cache.label_rel_x,
        label_cache.label_rel_y,
        label_cache.total_width,
        label_cache.text_height,
        label_cache.text,
        label_cache.label_color
    )
    
    local x = label_cache.label_rel_x + (label_cache.total_width - label_cache.text_width) / 2
    local draw_label_x, draw_label_y = coords:relativeToDrawList(x, label_cache.label_rel_y)
    return draw_label_x, draw_label_y
end

function GroupRenderer:renderGroupLabelGhost(ctx, pos_x, pos_y, content_height, total_width, coords, draw_list, toolbar_layout, label_text)
    local is_vertical = toolbar_layout and toolbar_layout.is_vertical
    local padding_x = (toolbar_layout and toolbar_layout.padding_x) or CONFIG.SIZES.PADDING
    local tw = reaper.ImGui_CalcTextSize(ctx, label_text)
    local th = reaper.ImGui_GetTextLineHeight(ctx)
    local label_rel_y = pos_y + content_height + 1
    local lc = COLOR_UTILS.ghostTint(CONFIG_MANAGER:color("GROUP", "LABEL"))
    
    DRAWING.drawCenteredText(ctx, coords, draw_list, pos_x, label_rel_y, total_width, th, label_text, lc)
    
    local x = pos_x + (total_width - tw) / 2
    local draw_label_x, draw_label_y = coords:relativeToDrawList(x, label_rel_y)
    local dc = COLOR_UTILS.ghostTint(CONFIG_MANAGER:color("GROUP", "DECORATION"))
    local left_draw_x = select(1, coords:relativeToDrawList(pos_x, 0))
    local right_draw_x = select(1, coords:relativeToDrawList(pos_x + total_width, 0))
    self:renderLabelDecoration(
        draw_list,
        draw_label_x,
        draw_label_y + (th / 2) + 1,
        tw,
        th,
        left_draw_x,
        right_draw_x,
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
    if CONFIG_MANAGER and CONFIG_MANAGER.requestSaveToolbarConfig then
        CONFIG_MANAGER:requestSaveToolbarConfig(toolbar_owner)
    end
end

-- Main group label rendering function (orchestration)
function GroupRenderer:renderGroupLabel(ctx, group, pos_x, pos_y, total_width, coords, draw_list, layout, toolbar_layout, editing_mode, toolbar_owner, group_index)
    local label_cache = self:ensureLabelCache(group)
    
    local is_vertical = toolbar_layout and toolbar_layout.is_vertical
    local content_height = (layout and layout.content_height) or CONFIG.SIZES.HEIGHT
    if not is_vertical and layout and layout.widget_title_band then
        content_height = content_height + layout.widget_title_band
    end
    
    -- Use padding_x from toolbar_layout, or fall back to CONFIG.SIZES.PADDING if not available
    local padding_x = (toolbar_layout and toolbar_layout.padding_x) or CONFIG.SIZES.PADDING
    
    -- Recalculate if needed
    if self:needsLabelRecalculation(label_cache, group, pos_x, pos_y, total_width, content_height, is_vertical, padding_x, editing_mode) then
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
    local deco_draw_color = CONFIG_MANAGER:color("GROUP", "DECORATION")
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
            label_draw_color = COLOR_UTILS.lightenByDelta(label_cache.label_color, 40)
            deco_draw_color = COLOR_UTILS.lightenByDelta(deco_draw_color, 40)
        end
        self:handleGroupLabelDragDrop(ctx, group, toolbar_owner, is_hovered, label_cache.text)
    end

    if C.DragDropManager:isGroupDrag() and C.DragDropManager:getDragSourceGroup() == group then
        label_draw_color = label_draw_color & 0xFFFFFF88
        deco_draw_color = deco_draw_color & 0xFFFFFF88
    end

    DRAWING.drawCenteredText(ctx, coords, draw_list, pos_x, label_cache.label_rel_y, total_width, label_cache.text_height, label_cache.text, label_draw_color)
    local x = pos_x + (total_width - label_cache.text_width) / 2
    local draw_label_x, draw_label_y = coords:relativeToDrawList(x, label_cache.label_rel_y)

    local decoration_pos_x = pos_x
    local left_draw_x = select(1, coords:relativeToDrawList(pos_x, 0))
    local right_draw_x = select(1, coords:relativeToDrawList(pos_x + total_width, 0))
    self:renderLabelDecoration(
        draw_list,
        draw_label_x,
        draw_label_y + (label_cache.text_height / 2) + 1,
        label_cache.text_width,
        label_cache.text_height,
        left_draw_x,
        right_draw_x,
        is_vertical,
        deco_draw_color
    )

    return label_cache.text_height + 8
end

-- Calculate decoration geometry (line positions, curve parameters)
function GroupRenderer:calculateDecorationGeometry(label_x, label_y, text_width, text_height, left_x_draw, right_x_draw, is_vertical)
    local line_thickness = 1.0
    local h_padding = math.max(1, math.floor((CONFIG.SIZES.PADDING or 6) / 2))

    local rounding
    if is_vertical then
        rounding = CONFIG.SIZES.ROUNDING
    else
        rounding = math.min(CONFIG.SIZES.ROUNDING, CONFIG.SIZES.HEIGHT / 2)
    end

    local curve_size
    if is_vertical then
        curve_size = rounding
    else
        curve_size = rounding + 4 + text_height / 2
    end

    local left_line_start = label_x - h_padding
    local left_line_end
    local right_line_start = label_x + text_width + h_padding
    local right_line_end
    if is_vertical then
        left_line_end = left_x_draw
        right_line_end = right_line_start + (left_line_start - left_line_end) - 2
    else
        left_line_end = left_x_draw + curve_size - h_padding
        right_line_end = right_x_draw - curve_size + h_padding
    end

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
    
    local color = COLOR_UTILS.modulateAlpha(line_color, alpha)
    
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
function GroupRenderer:renderLabelDecoration(draw_list, label_x, label_y, text_width, text_height, left_x_draw, right_x_draw, is_vertical, line_color_override)
    local line_color = line_color_override or CONFIG_MANAGER:color("GROUP", "DECORATION")

    local geometry = self:calculateDecorationGeometry(label_x, label_y, text_width, text_height, left_x_draw, right_x_draw, is_vertical)
    
    -- Render lines
    self:renderDecorationLines(draw_list, geometry, line_color)
    
    -- Render curves
    self:renderDecorationCurves(draw_list, geometry, line_color)
end

return GroupRenderer