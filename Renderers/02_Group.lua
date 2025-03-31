-- Renderers/02_Group.lua

local GroupRenderer = {}
GroupRenderer.__index = GroupRenderer

function GroupRenderer.new(ButtonRenderer)
    local self = setmetatable({}, GroupRenderer)

self.button_renderer = ButtonRenderer

    return self
end

function GroupRenderer:renderGroup(ctx, group, pos_x, pos_y, window_pos, draw_list, icon_font, editing_mode)
    -- Use cached dimensions if available
    local cached_dims = group:getDimensions()
    local total_width = cached_dims and cached_dims.width or 0
    local total_height = CONFIG.SIZES.HEIGHT
    local current_x = pos_x

    -- Render buttons
    for i, button in ipairs(group.buttons) do
        local button_width = self.button_renderer:renderButton(
            ctx,
            button,
            current_x,
            pos_y,
            icon_font,
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
            label_color = COLOR_UTILS.hexToImGuiColor(CONFIG.COLORS.GROUP.group_label)
        }
    end

    -- Use cached values for rendering
    local cache = group.group_label_cache
    reaper.ImGui_DrawList_AddText(
        draw_list,
        cache.label_x,
        cache.label_y,
        cache.label_color,
        cache.text
    )

    -- Render decorative lines
    self:renderLabelDecoration(
        draw_list,
        cache.label_x,
        cache.label_y,
        cache.text_width,
        cache.text_height,
        pos_x,
        window_pos.x
    )

    return cache.text_height + 8 -- Return height including padding
end

-- Render decorative lines for group labels
function GroupRenderer:renderLabelDecoration(
    draw_list,
    label_x,
    label_y,
    text_width,
    text_height,
    pos_x,
    window_offset_x)
    
    local line_color = COLOR_UTILS.hexToImGuiColor(CONFIG.COLORS.GROUP.DECORATION)
    local line_thickness = 1.0
    local screen_label_y = label_y + (text_height / 2) + 1
    local rounding = math.min(CONFIG.SIZES.ROUNDING, CONFIG.SIZES.HEIGHT / 2)
    local curve_size = rounding + 4 + text_height / 2
    local h_padding = 10

    -- Calculate line positions
    local left_x1 = window_offset_x + pos_x + curve_size - text_height / 2 + 2
    local left_x2 = label_x - h_padding
    local right_x1 = label_x + text_width + h_padding
    local right_x2 = right_x1 + (left_x2 - left_x1)

    -- Draw horizontal lines
    reaper.ImGui_DrawList_AddLine(draw_list, left_x1, screen_label_y, left_x2, screen_label_y, line_color, line_thickness)
    reaper.ImGui_DrawList_AddLine(draw_list, right_x1, screen_label_y, right_x2, screen_label_y, line_color, line_thickness)

    -- Draw curves
    local segments = 16
    for i = 0, segments do
        local t = i / segments
        local alpha_left = 1 - t
        local alpha_right = t

        -- Calculate curve points
        local angle_left = math.pi * (1 - t) / 2
        local angle_right = math.pi * t / 2

        local x1_left = left_x1 - curve_size * math.cos(angle_left)
        local y1_left = screen_label_y - curve_size + curve_size * math.sin(angle_left)

        local x1_right = right_x2 + curve_size * math.cos(angle_right)
        local y1_right = screen_label_y - curve_size + curve_size * math.sin(angle_right)

        if i < segments then
            local next_t = (i + 1) / segments
            local next_angle_left = math.pi * (1 - next_t) / 2
            local next_angle_right = math.pi * next_t / 2

            local x2_left = left_x1 - curve_size * math.cos(next_angle_left)
            local y2_left = screen_label_y - curve_size + curve_size * math.sin(next_angle_left)

            local x2_right = right_x2 + curve_size * math.cos(next_angle_right)
            local y2_right = screen_label_y - curve_size + curve_size * math.sin(next_angle_right)

            local color_left = (line_color & 0xFFFFFF00) | math.floor((line_color & 0xFF) * alpha_left)
            local color_right = (line_color & 0xFFFFFF00) | math.floor((line_color & 0xFF) * alpha_right)

            reaper.ImGui_DrawList_AddLine(draw_list, x1_left, y1_left, x2_left, y2_left, color_left, line_thickness)
            reaper.ImGui_DrawList_AddLine(draw_list, x1_right, y1_right, x2_right, y2_right, color_right, line_thickness)
        end
    end
end

return GroupRenderer