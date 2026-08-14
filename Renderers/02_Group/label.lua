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
    local draw_label_x, draw_label_y, tw = DRAWING.drawCenteredText(
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
    
    -- Save width for decoration later
    label_cache.text_width = tw
    
    return draw_label_x, draw_label_y
end

function GroupRenderer:renderGroupLabelGhost(ctx, pos_x, pos_y, content_height, total_width, coords, draw_list, toolbar_layout, label_text)
    local is_vertical = toolbar_layout and toolbar_layout.is_vertical
    local padding_x = (toolbar_layout and toolbar_layout.padding_x) or CONFIG.SIZES.PADDING
    local th = reaper.ImGui_GetTextLineHeight(ctx)
    local label_rel_y = pos_y + content_height + 1
    local lc = COLOR_UTILS.ghostTint(CONFIG_MANAGER:color("GROUP", "LABEL"))
    
    local draw_label_x, draw_label_y, tw = DRAWING.drawCenteredText(ctx, coords, draw_list, pos_x, label_rel_y, total_width, th, label_text, lc)
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

    local draw_label_x, draw_label_y, tw = DRAWING.drawCenteredText(ctx, coords, draw_list, pos_x, label_cache.label_rel_y, total_width, label_cache.text_height, label_cache.text, label_draw_color)
    label_cache.text_width = tw

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
        deco_draw_color,
        label_cache
    )

    return label_cache.text_height + 8
end
