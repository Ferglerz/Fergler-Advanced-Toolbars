-- Renderers/02_Group.lua

local GroupRenderer = {}
GroupRenderer.__index = GroupRenderer

function GroupRenderer.new()
    local self = setmetatable({}, GroupRenderer)
    return self
end

function GroupRenderer:renderGroup(ctx, group, pos_x, pos_y, coords, draw_list, editing_mode, layout)
    local current_x = pos_x
    
    -- Render all buttons (including separators)
    for i, button_layout in ipairs(layout.buttons) do
        local button = group.buttons[i]
        
        C.ButtonRenderer:renderButton(
            ctx,
            button,
            current_x + button_layout.x,
            pos_y,
            coords,
            draw_list,
            editing_mode,
            button_layout
        )
    end

    -- Render group label if needed
    local decoration_width = layout.width
    if self:shouldGroupLabel(group) then
        -- Calculate decoration width by subtracting separator width if group has separators
        for _, button in ipairs(group.buttons) do
            if button:isSeparator() then
                decoration_width = decoration_width - CONFIG.SIZES.SEPARATOR_WIDTH
                break -- Only subtract once per group
            end
        end
        self:renderGroupLabel(ctx, group, pos_x, pos_y, decoration_width, coords, draw_list)
    end

    return layout.width, layout.height
end

function GroupRenderer:shouldGroupLabel(group)
    return CONFIG.UI.USE_GROUP_LABELS and group.group_label and group.group_label.text and #group.group_label.text > 0
end

function GroupRenderer:renderGroupLabel(ctx, group, pos_x, pos_y, total_width, coords, draw_list)
    if not group.cache.label then
        group.cache.label = {}
    end
    
    local label_cache = group.cache.label
    local need_recalculation =
        not label_cache.text or 
        label_cache.text ~= group.group_label.text or 
        label_cache.pos_x ~= pos_x or
        label_cache.pos_y ~= pos_y or
        label_cache.total_width ~= total_width

    if need_recalculation then
        local text_width = reaper.ImGui_CalcTextSize(ctx, group.group_label.text)
        local text_height = reaper.ImGui_GetTextLineHeight(ctx)
        
        label_cache.text = group.group_label.text
        label_cache.pos_x = pos_x
        label_cache.pos_y = pos_y
        label_cache.total_width = total_width
        label_cache.text_width = text_width
        label_cache.text_height = text_height
        label_cache.label_rel_x = pos_x + (total_width / 2) - text_width / 2.18
        label_cache.label_rel_y = pos_y + CONFIG.SIZES.HEIGHT + 1
        -- Use cached color for performance
        if CONFIG_MANAGER and CONFIG_MANAGER.cached_colors and CONFIG_MANAGER.cached_colors.GROUP and CONFIG_MANAGER.cached_colors.GROUP.LABEL then
            label_cache.label_color = CONFIG_MANAGER.cached_colors.GROUP.LABEL
        else
            label_cache.label_color = COLOR_UTILS.toImGuiColor(CONFIG.COLORS.GROUP.LABEL)
        end
    end

    local draw_label_x, draw_label_y = coords:relativeToDrawList(label_cache.label_rel_x, label_cache.label_rel_y)
    
    reaper.ImGui_DrawList_AddText(
        draw_list,
        draw_label_x,
        draw_label_y,
        label_cache.label_color,
        label_cache.text
    )

    self:renderLabelDecoration(
        draw_list,
        draw_label_x,
        draw_label_y + (label_cache.text_height / 2) + 1,
        label_cache.text_width,
        label_cache.text_height,
        coords:relativeToDrawList(pos_x, 0)
    )

    return label_cache.text_height + 8
end

function GroupRenderer:renderLabelDecoration(draw_list, label_x, label_y, text_width, text_height, pos_x_draw, window_pos_x_draw)
    -- Use cached color for performance
    local line_color
    if CONFIG_MANAGER and CONFIG_MANAGER.cached_colors and CONFIG_MANAGER.cached_colors.GROUP and CONFIG_MANAGER.cached_colors.GROUP.DECORATION then
        line_color = CONFIG_MANAGER.cached_colors.GROUP.DECORATION
    else
        line_color = COLOR_UTILS.toImGuiColor(CONFIG.COLORS.GROUP.DECORATION)
    end
    local line_thickness = 1.0
    local rounding = math.min(CONFIG.SIZES.ROUNDING, CONFIG.SIZES.HEIGHT / 2)
    local curve_size = rounding + 4 + text_height / 2
    local h_padding = 8

    local left_line_start = label_x - h_padding
    local left_line_end = pos_x_draw + curve_size - h_padding

    local right_line_start = label_x + text_width + h_padding
    local right_line_end = right_line_start + (left_line_start - left_line_end) - 2

    reaper.ImGui_DrawList_AddLine(draw_list, left_line_start, label_y, left_line_end, label_y, line_color, line_thickness)
    reaper.ImGui_DrawList_AddLine(draw_list, right_line_start, label_y, right_line_end, label_y, line_color, line_thickness)

    local segments = 16
    for i = 0, segments do
        local t = i / segments
        local alpha_left = 1 - t
        local alpha_right = t

        local left_angle = math.pi * (1 - t) / 2
        local left_curve_x = left_line_end - curve_size * math.cos(left_angle)
        local left_curve_y = label_y - curve_size + curve_size * math.sin(left_angle)

        local right_angle = math.pi * t / 2
        local right_curve_x = right_line_end + curve_size * math.cos(right_angle)
        local right_curve_y = label_y - curve_size + curve_size * math.sin(right_angle)

        if i < segments then
            local next_t = (i + 1) / segments
            
            local left_next_angle = math.pi * (1 - next_t) / 2
            local left_next_x = left_line_end - curve_size * math.cos(left_next_angle)
            local left_next_y = label_y - curve_size + curve_size * math.sin(left_next_angle)

            local right_next_angle = math.pi * next_t / 2
            local right_next_x = right_line_end + curve_size * math.cos(right_next_angle)
            local right_next_y = label_y - curve_size + curve_size * math.sin(right_next_angle)

            local color_left = (line_color & 0xFFFFFF00) | math.floor((line_color & 0xFF) * alpha_left)
            local color_right = (line_color & 0xFFFFFF00) | math.floor((line_color & 0xFF) * alpha_right)

            reaper.ImGui_DrawList_AddLine(draw_list, left_curve_x, left_curve_y, left_next_x, left_next_y, color_left, line_thickness)
            reaper.ImGui_DrawList_AddLine(draw_list, right_curve_x, right_curve_y, right_next_x, right_next_y, color_right, line_thickness)
        end
    end
end

return GroupRenderer.new()