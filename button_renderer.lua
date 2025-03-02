-- button_renderer.lua
local ButtonVisuals = require "button_visuals"
local ButtonContent = require "button_content"

local ButtonRenderer = {}
ButtonRenderer.__index = ButtonRenderer

function ButtonRenderer.new(reaper, button_manager, helpers)
    local self = setmetatable({}, ButtonRenderer)
    self.r = reaper
    self.button_manager = button_manager
    self.helpers = helpers
    self.hover_start_times = {}
    return self
end

function ButtonRenderer:renderButton(ctx, button, pos_x, pos_y, icon_font, window_pos, draw_list, group, editing_mode)
    if button.is_separator then
        return ButtonVisuals.renderSeparator(
            ctx,
            self.r,
            pos_x,
            pos_y,
            button.width or CONFIG.SIZES.SEPARATOR_WIDTH,
            window_pos,
            draw_list,
            self.helpers
        )
    end

    local width = ButtonContent.calculateButtonWidth(ctx, button, icon_font, self.helpers)

    self.r.ImGui_SetCursorPos(ctx, pos_x, pos_y)
    self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_Button(), 0x00000000)
    self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_ButtonHovered(), 0x00000000)
    self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_ButtonActive(), 0x00000000)

    local clicked = self.r.ImGui_Button(ctx, "##" .. button.id, width, CONFIG.SIZES.HEIGHT)
    local is_hovered = self.r.ImGui_IsItemHovered(ctx)
    local is_clicked = self.r.ImGui_IsItemActive(ctx)
    
    -- Store hover state on the button (this is key)
    button.is_hovered = is_hovered
    button.is_right_clicked = is_hovered and self.r.ImGui_IsMouseClicked(ctx, 1)

    self.r.ImGui_PopStyleColor(ctx, 3)

    if is_hovered then
        if not self.hover_start_times[button.id] then
            self.hover_start_times[button.id] = self.r.ImGui_GetTime(ctx)
        end
        
        -- Only show the tooltip if not in editing mode
        if not editing_mode then
            ButtonVisuals.renderTooltip(
                ctx,
                self.r,
                button,
                self.r.ImGui_GetTime(ctx) - self.hover_start_times[button.id],
                self.button_manager
            )
        end
    else
        self.hover_start_times[button.id] = nil
    end

    local bg_color, border_color, icon_color, text_color =
        ButtonVisuals.getButtonColors(button, is_hovered, is_clicked, self.helpers)

    ButtonVisuals.renderBackground(
        self.r,
        draw_list,
        button,
        pos_x,
        pos_y,
        width,
        bg_color,
        border_color,
        window_pos,
        group,
        self.helpers
    )
    
    -- In editing mode and if hovered, show "Edit" text instead of regular content
    if editing_mode and is_hovered then
        -- Center "Edit" text in the button
        local edit_text = "Edit"
        local text_width = self.r.ImGui_CalcTextSize(ctx, edit_text)
        local text_x = pos_x + (width - text_width) / 2
        local text_y = pos_y + (CONFIG.SIZES.HEIGHT - self.r.ImGui_GetTextLineHeight(ctx)) / 2
        
        self.r.ImGui_SetCursorPos(ctx, text_x, text_y)
        self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_Text(), text_color)
        self.r.ImGui_Text(ctx, edit_text)
        self.r.ImGui_PopStyleColor(ctx)
    else
        -- Regular button content rendering
        local icon_width =
            ButtonContent.renderIcon(
            ctx,
            self.r,
            button,
            pos_x,
            pos_y,
            icon_font,
            icon_color,
            width,
            self.button_manager,
            self.helpers
        )
        ButtonContent.renderText(ctx, self.r, button, pos_x, pos_y, text_color, width, icon_width)
    end

    if clicked then
        self.button_manager:buttonClicked(button, false)
    end

    return width
end

function ButtonRenderer:renderGroup(ctx, group, pos_x, pos_y, window_pos, draw_list, icon_font, editing_mode)
    local total_width = 0
    local total_height = CONFIG.SIZES.HEIGHT
    local current_x = pos_x

    for i, button in ipairs(group.buttons) do
        local button_width = self:renderButton(ctx, button, current_x, pos_y, icon_font, window_pos, draw_list, group, editing_mode)
        total_width = total_width + button_width
        current_x = current_x + button_width

        if i > 0 and not CONFIG.UI.GROUPING then
            current_x = current_x + CONFIG.SIZES.SPACING
            total_width = total_width + CONFIG.SIZES.SPACING
        end
    end

    -- Render group label
    if CONFIG.UI.USE_GROUP_LABELS and #group.label.text > 0 then
        local text_width = self.r.ImGui_CalcTextSize(ctx, group.label.text)
        local text_height = self.r.ImGui_GetTextLineHeight(ctx)
        local label_x = (window_pos.x + pos_x + (total_width / 2)) - text_width / 2.18
        local label_y = window_pos.y + pos_y + total_height + 1

        self.r.ImGui_DrawList_AddText(
            draw_list,
            label_x,
            label_y,
            self.helpers.hexToImGuiColor(CONFIG.COLORS.GROUP.LABEL),
            group.label.text
        )

        total_height = total_height + text_height + 8
        self:renderLabelDecoration(draw_list, label_x, label_y, text_width, text_height, pos_x)
    end

    return total_width
end

function ButtonRenderer:renderLabelDecoration(draw_list, label_x, label_y, text_width, text_height, pos_x)
    local line_color = self.helpers.hexToImGuiColor(CONFIG.COLORS.GROUP.DECORATION)
    local line_thickness = 1.0
    local screen_label_y = label_y + (text_height / 2) + 1
    local rounding = math.min(CONFIG.SIZES.ROUNDING, CONFIG.SIZES.HEIGHT / 2)
    local curve_size = rounding + 4 + text_height / 2
    local h_padding = 10

    -- Calculate line positions
    local left_x1 = pos_x + curve_size - text_height / 2 + 2
    local left_x2 = label_x - h_padding
    local right_x1 = label_x + text_width + h_padding
    local right_x2 = right_x1 + (left_x2 - left_x1)

    -- Draw horizontal lines
    self.r.ImGui_DrawList_AddLine(
        draw_list,
        left_x1,
        screen_label_y,
        left_x2,
        screen_label_y,
        line_color,
        line_thickness
    )
    self.r.ImGui_DrawList_AddLine(
        draw_list,
        right_x1,
        screen_label_y,
        right_x2,
        screen_label_y,
        line_color,
        line_thickness
    )

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

            self.r.ImGui_DrawList_AddLine(draw_list, x1_left, y1_left, x2_left, y2_left, color_left, line_thickness)
            self.r.ImGui_DrawList_AddLine(
                draw_list,
                x1_right,
                y1_right,
                x2_right,
                y2_right,
                color_right,
                line_thickness
            )
        end
    end
end

return ButtonRenderer
