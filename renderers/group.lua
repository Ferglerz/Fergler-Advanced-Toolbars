-- group_renderer.lua
local ColorUtils = require "color_utils"

local GroupRenderer = {}
GroupRenderer.__index = GroupRenderer

function GroupRenderer.new(reaper, helpers)
    local self = setmetatable({}, GroupRenderer)
    self.r = reaper
    self.helpers = helpers
    self.ColorUtils = ColorUtils

    self.line_positions = {
        left = {x1 = 0, x2 = 0},
        right = {
            x1 = 0,
            x2 = 0,
            get_x2 = function(left_x1, left_x2)
                return left_x2 + (left_x2 - left_x1)
            end
        }
    }
    return self
end

function GroupRenderer:renderGroup(
    ctx,
    group,
    pos_x,
    pos_y,
    window_pos,
    draw_list,
    icon_font,
    editing_mode,
    buttonRenderer)
    -- Use cached dimensions if available
    local cached_dims = group:getDimensions()
    if cached_dims then
        -- Still need to render each button
        local current_x = pos_x
        for i, button in ipairs(group.buttons) do
            local icon_font_selector = buttonRenderer.icon_font_selector

            local button_width =
                buttonRenderer:renderButton(
                ctx,
                button,
                current_x,
                pos_y,
                icon_font,
                icon_font_selector,
                window_pos,
                draw_list,
                editing_mode
            )

            current_x = current_x + button_width

            -- Add spacing only between buttons, not after the last one
            if i < #group.buttons then
                current_x = current_x + CONFIG.SIZES.SPACING
            end
        end

        -- Render group label if enabled
        if self:shouldRenderGroupLabel(group) then
            self:renderGroupLabel(ctx, group, pos_x, pos_y, cached_dims.width, window_pos, draw_list)
        end

        return cached_dims.width, cached_dims.height
    end

    local total_width = 0
    local total_height = CONFIG.SIZES.HEIGHT
    local current_x = pos_x

    for i, button in ipairs(group.buttons) do
        -- Get icon_font_selector from buttonRenderer if available
        local icon_font_selector = buttonRenderer.icon_font_selector

        local button_width =
            buttonRenderer:renderButton(
            ctx,
            button,
            current_x,
            pos_y,
            icon_font,
            icon_font_selector,
            window_pos,
            draw_list,
            editing_mode
        )

        total_width = total_width + button_width
        current_x = current_x + button_width

        -- Add spacing only between buttons, not after the last one
        if i < #group.buttons then
            current_x = current_x + CONFIG.SIZES.SPACING
            total_width = total_width + CONFIG.SIZES.SPACING
        end
    end

    -- Render group label if enabled
    if self:shouldRenderGroupLabel(group) then
        local label_height = self:renderGroupLabel(ctx, group, pos_x, pos_y, total_width, window_pos, draw_list)
        total_height = total_height + label_height
    end

    -- Cache dimensions
    group:cacheDimensions(total_width, total_height)

    return total_width, total_height
end

-- Check if group label should be rendered
function GroupRenderer:shouldRenderGroupLabel(group)
    return CONFIG.UI.USE_GROUP_LABELS and group.label and group.label.text and #group.label.text > 0
end

-- Render the group label
function GroupRenderer:renderGroupLabel(ctx, group, pos_x, pos_y, total_width, window_pos, draw_list)
    -- Check if we need to recalculate label position
    local need_recalculation =
        not group.label_cache or group.label_cache.text ~= group.label.text or group.label_cache.pos_x ~= pos_x or
        group.label_cache.pos_y ~= pos_y or
        group.label_cache.total_width ~= total_width or
        group.label_cache.window_x ~= window_pos.x or
        group.label_cache.window_y ~= window_pos.y

    if need_recalculation then
        -- Initialize cache if it doesn't exist
        if not group.label_cache then
            group.label_cache = {}
        end

        -- Calculate and cache label position and dimensions
        local text_width = self.r.ImGui_CalcTextSize(ctx, group.label.text)
        local text_height = self.r.ImGui_GetTextLineHeight(ctx)

        group.label_cache = {
            text = group.label.text,
            pos_x = pos_x,
            pos_y = pos_y,
            total_width = total_width,
            window_x = window_pos.x,
            window_y = window_pos.y,
            text_width = text_width,
            text_height = text_height,
            label_x = (window_pos.x + pos_x + (total_width / 2)) - text_width / 2.18,
            label_y = window_pos.y + pos_y + CONFIG.SIZES.HEIGHT + 1,
            label_color = self.ColorUtils.hexToImGuiColor(CONFIG.COLORS.GROUP.LABEL)
        }
    end

    -- Use cached values for rendering
    self.r.ImGui_DrawList_AddText(
        draw_list,
        group.label_cache.label_x,
        group.label_cache.label_y,
        group.label_cache.label_color,
        group.label_cache.text
    )

    self:renderLabelDecoration(
        draw_list,
        group.label_cache.label_x,
        group.label_cache.label_y,
        group.label_cache.text_width,
        group.label_cache.text_height,
        pos_x,
        window_pos.x
    )

    return group.label_cache.text_height + 8 -- Return height including padding
end

function GroupRenderer:renderLabelDecoration(
    draw_list,
    label_x,
    label_y,
    text_width,
    text_height,
    pos_x,
    window_offset_x)
    local line_color = self.ColorUtils.hexToImGuiColor(CONFIG.COLORS.GROUP.DECORATION)
    local line_thickness = 1.0
    local screen_label_y = label_y + (text_height / 2) + 1
    local rounding = math.min(CONFIG.SIZES.ROUNDING, CONFIG.SIZES.HEIGHT / 2)
    local curve_size = rounding + 4 + text_height / 2
    local h_padding = 10

    -- Calculate line positions
    local line_positions =
        self:calculateLabelLinePositions(
        label_x,
        text_width,
        window_offset_x + pos_x,
        curve_size,
        text_height,
        h_padding
    )

    -- Draw horizontal lines
    self:drawLabelHorizontalLines(draw_list, line_positions, screen_label_y, line_color, line_thickness)

    -- Draw curves
    self:drawLabelCurves(draw_list, line_positions, curve_size, screen_label_y, line_color, line_thickness)
end

-- Helper to calculate label line positions
function GroupRenderer:calculateLabelLinePositions(label_x, text_width, pos_x, curve_size, text_height, h_padding)
    self.line_positions.left.x1 = pos_x + curve_size - text_height / 2 + 2
    self.line_positions.left.x2 = label_x - h_padding
    self.line_positions.right.x1 = label_x + text_width + h_padding
    return self.line_positions
end

-- Helper to draw label horizontal lines
function GroupRenderer:drawLabelHorizontalLines(draw_list, positions, y, color, thickness)
    -- Left horizontal line
    self.r.ImGui_DrawList_AddLine(draw_list, positions.left.x1, y, positions.left.x2, y, color, thickness)

    -- Right horizontal line
    self.r.ImGui_DrawList_AddLine(
        draw_list,
        positions.right.x1,
        y,
        positions.right.get_x2(positions.left.x1, positions.left.x2),
        y,
        color,
        thickness
    )
end

-- Helper to draw label curves
function GroupRenderer:drawLabelCurves(draw_list, positions, curve_size, y, color, thickness)
    local segments = 16

    for i = 0, segments do
        local t = i / segments
        local alpha_left = 1 - t
        local alpha_right = t

        -- Calculate curve points
        local angle_left = math.pi * (1 - t) / 2
        local angle_right = math.pi * t / 2

        local x1_left = positions.left.x1 - curve_size * math.cos(angle_left)
        local y1_left = y - curve_size + curve_size * math.sin(angle_left)

        local x1_right =
            positions.right.get_x2(positions.left.x1, positions.left.x2) + curve_size * math.cos(angle_right)
        local y1_right = y - curve_size + curve_size * math.sin(angle_right)

        if i < segments then
            local next_t = (i + 1) / segments
            local next_angle_left = math.pi * (1 - next_t) / 2
            local next_angle_right = math.pi * next_t / 2

            local x2_left = positions.left.x1 - curve_size * math.cos(next_angle_left)
            local y2_left = y - curve_size + curve_size * math.sin(next_angle_left)

            local x2_right =
                positions.right.get_x2(positions.left.x1, positions.left.x2) + curve_size * math.cos(next_angle_right)
            local y2_right = y - curve_size + curve_size * math.sin(next_angle_right)

            local color_left = (color & 0xFFFFFF00) | math.floor((color & 0xFF) * alpha_left)
            local color_right = (color & 0xFFFFFF00) | math.floor((color & 0xFF) * alpha_right)

            self.r.ImGui_DrawList_AddLine(draw_list, x1_left, y1_left, x2_left, y2_left, color_left, thickness)
            self.r.ImGui_DrawList_AddLine(draw_list, x1_right, y1_right, x2_right, y2_right, color_right, thickness)
        end
    end
end

return {
    new = function(reaper, helpers)
        return GroupRenderer.new(reaper, helpers)
    end
}
