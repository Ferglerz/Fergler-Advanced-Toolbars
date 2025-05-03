-- Renderers/02_Group.lua

local GroupRenderer = {}
GroupRenderer.__index = GroupRenderer

function GroupRenderer.new()
    local self = setmetatable({}, GroupRenderer)
    return self
end

function GroupRenderer:renderGroup(ctx, group, pos_x, pos_y, window_pos, draw_list, editing_mode)
    -- Use cached dimensions if available
    local cached_dims = group:getDimensions()
    local total_width = cached_dims and cached_dims.width or 0
    local total_height = CONFIG.SIZES.HEIGHT
    local current_x = pos_x

    -- Render buttons
    for i, button in ipairs(group.buttons) do
        local button_width = C.ButtonRenderer:renderButton(
            ctx,
            button,
            current_x,
            pos_y,
            window_pos,
            draw_list,
            editing_mode
        )

        -- Update width and position
        if not cached_dims then
            total_width = total_width + button_width
            if i < #group.buttons then
                total_width = total_width + CONFIG.SIZES.SPACING
            end
        end

        current_x = current_x + button_width + (i < #group.buttons and CONFIG.SIZES.SPACING or 0)
    end

    -- Render group label if needed
    if self:shouldGroupLabel(group) then
        local label_height = self:renderGroupLabel(ctx, group, pos_x, pos_y, total_width, window_pos, draw_list)
        if not cached_dims then
            total_height = total_height + label_height
        end
    end

    -- Cache dimensions if not already cached
    if not cached_dims then
        group:cacheDimensions(total_width, total_height)
    end

    return total_width, total_height
end

-- Check if group label should be rendered
function GroupRenderer:shouldGroupLabel(group)
    return CONFIG.UI.USE_GROUP_LABELS and group.group_label and group.group_label.text and #group.group_label.text > 0
end

-- Render the group label
function GroupRenderer:renderGroupLabel(ctx, group, pos_x, pos_y, total_width, window_pos, draw_list)
    -- Check if we need to recalculate label position
    local need_recalculation =
        not group.group_label_cache or 
        group.group_label_cache.text ~= group.group_label.text or 
        group.group_label_cache.pos_x ~= pos_x or
        group.group_label_cache.pos_y ~= pos_y or
        group.group_label_cache.total_width ~= total_width or
        group.group_label_cache.window_x ~= window_pos.x or
        group.group_label_cache.window_y ~= window_pos.y

    if need_recalculation then
        -- Calculate and cache label position and dimensions
        local text_width = reaper.ImGui_CalcTextSize(ctx, group.group_label.text)
        local text_height = reaper.ImGui_GetTextLineHeight(ctx)
        
        group.group_label_cache = {
            text = group.group_label.text,
            pos_x = pos_x,
            pos_y = pos_y,
            total_width = total_width,
            window_x = window_pos.x,
            window_y = window_pos.y,
            text_width = text_width,
            text_height = text_height,
            label_x = (window_pos.x + pos_x + (total_width / 2)) - text_width / 2.18,
            label_y = window_pos.y + pos_y + CONFIG.SIZES.HEIGHT + 1,
            label_color = COLOR_UTILS.toImGuiColor(CONFIG.COLORS.GROUP.group_label)
        }
    end

    -- Use cached values for rendering with scroll adjustment
    local cache = group.group_label_cache
    local label_x, label_y = UTILS.applyScrollOffset(ctx, cache.label_x, cache.label_y)
    
    reaper.ImGui_DrawList_AddText(
        draw_list,
        label_x,
        label_y,
        cache.label_color,
        cache.text
    )

    -- Render decorative lines with scroll offset
    self:renderLabelDecoration(
        draw_list,
        label_x,
        label_y + (cache.text_height / 2) + 1,
        cache.text_width,
        cache.text_height,
        UTILS.applyScrollOffset(ctx, pos_x, window_pos.x),
        window_pos.x
    )

    return cache.text_height + 8 -- Return height including padding
end

function GroupRenderer:renderLabelDecoration(
    draw_list,
    label_x,
    label_y,
    text_width,
    text_height,
    pos_x,
    window_pos_x
)
    
    local line_color = COLOR_UTILS.toImGuiColor(CONFIG.COLORS.GROUP.DECORATION)
    local line_thickness = 1.0
    local rounding = math.min(CONFIG.SIZES.ROUNDING, CONFIG.SIZES.HEIGHT / 2)
    local curve_size = rounding + 4 + text_height / 2
    local h_padding = 8

    -- Left side base positions
    local left_line_start = label_x - h_padding
    local left_line_end = pos_x + window_pos_x + curve_size - h_padding

    -- Right side base positions
    local right_line_start = label_x + text_width + h_padding
    local right_line_end = right_line_start + (left_line_start - left_line_end) - 2 -- I dunno why I need this constant of 2 but it works

    -- Draw horizontal lines
    reaper.ImGui_DrawList_AddLine(draw_list, left_line_start, label_y, left_line_end, label_y, line_color, line_thickness)
    reaper.ImGui_DrawList_AddLine(draw_list, right_line_start, label_y, right_line_end, label_y, line_color, line_thickness)

    -- Draw curves
    local segments = 16
    for i = 0, segments do
        local t = i / segments
        local alpha_left = 1 - t
        local alpha_right = t

        -- Left curve calculations
        local left_angle = math.pi * (1 - t) / 2
        local left_curve_x = left_line_end - curve_size * math.cos(left_angle)
        local left_curve_y = label_y - curve_size + curve_size * math.sin(left_angle)

        -- Right curve calculations
        local right_angle = math.pi * t / 2
        local right_curve_x = right_line_end + curve_size * math.cos(right_angle)
        local right_curve_y = label_y - curve_size + curve_size * math.sin(right_angle)

        if i < segments then
            local next_t = (i + 1) / segments
            
            -- Left curve next point
            local left_next_angle = math.pi * (1 - next_t) / 2
            local left_next_x = left_line_end - curve_size * math.cos(left_next_angle)
            local left_next_y = label_y - curve_size + curve_size * math.sin(left_next_angle)

            -- Right curve next point
            local right_next_angle = math.pi * next_t / 2
            local right_next_x = right_line_end + curve_size * math.cos(right_next_angle)
            local right_next_y = label_y - curve_size + curve_size * math.sin(right_next_angle)

            -- Colors with alpha
            local color_left = (line_color & 0xFFFFFF00) | math.floor((line_color & 0xFF) * alpha_left)
            local color_right = (line_color & 0xFFFFFF00) | math.floor((line_color & 0xFF) * alpha_right)

            -- Draw curve segments
            reaper.ImGui_DrawList_AddLine(draw_list, left_curve_x, left_curve_y, left_next_x, left_next_y, color_left, line_thickness)
            reaper.ImGui_DrawList_AddLine(draw_list, right_curve_x, right_curve_y, right_next_x, right_next_y, color_right, line_thickness)
        end
    end
end

return GroupRenderer.new()