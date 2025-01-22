-- button_renderer.lua
local CONFIG = require "Advanced Toolbars - User Config"

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

function ButtonRenderer:calculateButtonWidth(ctx, button, icon_font)
    -- Calculate text width using the helper function
    local max_text_width = 0
    if not (button.hide_label or CONFIG.UI.HIDE_ALL_LABELS) then
        max_text_width = self.helpers.calculateTextWidth(ctx, button.display_text, nil)
    end

    local icon_width = 0
    if button.icon_char and icon_font then
        icon_width = self.helpers.calculateTextWidth(ctx, button.icon_char, icon_font)
    elseif button.icon_texture and button.icon_dimensions then
        icon_width = button.icon_dimensions.width
    end

    local total_width = 0
    if icon_width > 0 and max_text_width > 0 then
        total_width = math.max(CONFIG.SIZES.MIN_WIDTH, icon_width + CONFIG.ICON_FONT.PADDING + max_text_width)
    elseif icon_width > 0 then
        total_width = icon_width
    else
        total_width = math.max(CONFIG.SIZES.MIN_WIDTH, max_text_width)
    end

    return total_width + (CONFIG.ICON_FONT.PADDING * 2)
end

function ButtonRenderer:getButtonColors(button, is_hovered, is_clicked)
    local use_state = button.is_toggled and "TOGGLED" 
        or button.is_flashing and "ARMED_FLASH"
        or button.is_armed and "ARMED"
        or "NORMAL"

    local mouse_state = is_clicked and "CLICKED"
        or is_hovered and "HOVER"
        or "NORMAL"

    local bg_color = CONFIG.COLORS[use_state].BG[mouse_state]
    local border_color = CONFIG.COLORS[use_state].BORDER[mouse_state]
    local icon_color = CONFIG.COLORS[use_state].ICON[mouse_state]
    local text_color = CONFIG.COLORS[use_state].TEXT[mouse_state]

    if button.custom_color and not (button.is_toggled or button.is_armed) then
        bg_color =
            is_clicked and button.custom_color.clicked or 
            is_hovered and button.custom_color.hover or
            button.custom_color.normal
    end

    return 
    self.helpers.hexToImGuiColor(bg_color), 
    self.helpers.hexToImGuiColor(border_color), 
    self.helpers.hexToImGuiColor(icon_color),
    self.helpers.hexToImGuiColor(text_color)
end

function ButtonRenderer:getRoundingFlags(button, group)
    if not CONFIG.UI.USE_GROUPING or button.is_alone then
        return self.r.ImGui_DrawFlags_RoundCornersAll()
    elseif button.is_section_start then
        return self.r.ImGui_DrawFlags_RoundCornersLeft()
    elseif button.is_section_end then
        return self.r.ImGui_DrawFlags_RoundCornersRight()
    end
    return self.r.ImGui_DrawFlags_RoundCornersNone()
end

function ButtonRenderer:renderButtonBackground(
    draw_list,
    button,
    pos_x,
    pos_y,
    width,
    bgCol,
    borderCol,
    window_pos,
    group)
    if not window_pos then
        return
    end

    local flags = self:getRoundingFlags(button, group)
    local x1 = window_pos.x + pos_x
    local y1 = window_pos.y + pos_y
    local x2 = x1 + width
    local y2 = y1 + CONFIG.SIZES.HEIGHT

    if CONFIG.SIZES.DEPTH > 0 then
        self.r.ImGui_DrawList_AddRectFilled(
            draw_list,
            x1 + CONFIG.SIZES.DEPTH,
            y1 + CONFIG.SIZES.DEPTH,
            x2 + CONFIG.SIZES.DEPTH,
            y2 + CONFIG.SIZES.DEPTH,
            self.helpers.hexToImGuiColor(CONFIG.COLORS.SHADOW),
            CONFIG.SIZES.ROUNDING,
            flags
        )
    end

    -- Draw main button background
    self.r.ImGui_DrawList_AddRectFilled(
        draw_list,
        x1,
        y1,
        x2,
        y2,
        self.helpers.hexToImGuiColor(bgCol),
        CONFIG.SIZES.ROUNDING,
        flags
    )

    self.r.ImGui_DrawList_AddRect(
        draw_list,
        x1,
        y1,
        x2,
        y2,
        self.helpers.hexToImGuiColor(borderCol),
        CONFIG.SIZES.ROUNDING,
        flags
    )
end

function ButtonRenderer:renderIcon(ctx, button, pos_x, pos_y, icon_font, icon_color, total_width)
    local icon_width = 0
    local show_text = not (button.hide_label or CONFIG.UI.HIDE_ALL_LABELS)
    local max_text_width = show_text and self.helpers.calculateTextWidth(ctx, button.display_text, nil) or 0

    -- Handle icon character
    if button.icon_char and icon_font then
        -- Handle image icon
        self.r.ImGui_PushFont(ctx, icon_font)
        local char_width = self.r.ImGui_CalcTextSize(ctx, button.icon_char)

        local icon_x =
            pos_x +
            (show_text and max_text_width > 0 and
                math.max(
                    (total_width - (char_width + CONFIG.ICON_FONT.PADDING + max_text_width)) / 2,
                    CONFIG.ICON_FONT.PADDING
                ) or
                (total_width - char_width) / 2)

        local icon_y = pos_y + (CONFIG.SIZES.HEIGHT / 2)

        self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_Text(), icon_color)
        self.r.ImGui_SetCursorPos(ctx, icon_x, icon_y)
        self.r.ImGui_Text(ctx, button.icon_char)
        self.r.ImGui_PopStyleColor(ctx)
        self.r.ImGui_PopFont(ctx)

        icon_width = char_width + (show_text and max_text_width > 0 and CONFIG.ICON_FONT.PADDING or 0)
    elseif button.icon_path then
        self.button_manager:loadIcon(button)

        if button.icon_texture and button.icon_dimensions then
            local dims = button.icon_dimensions
            local icon_x =
                pos_x +
                (show_text and max_text_width > 0 and
                    math.max(
                        (total_width - (dims.width + CONFIG.ICON_FONT.PADDING + max_text_width)) / 2,
                        CONFIG.ICON_FONT.PADDING
                    ) or
                    (total_width - dims.width) / 2)

            local icon_y = pos_y + (CONFIG.SIZES.HEIGHT - dims.height) / 2

            self.r.ImGui_SetCursorPos(ctx, icon_x, icon_y)
            self.r.ImGui_Image(ctx, button.icon_texture, dims.width, dims.height)

            icon_width = dims.width + (show_text and max_text_width > 0 and CONFIG.ICON_FONT.PADDING or 0)
        end
    end

    return icon_width
end

function ButtonRenderer:renderText(ctx, button, pos_x, pos_y, text_color, width, icon_width)
    if button.hide_label or CONFIG.UI.HIDE_ALL_LABELS then
        return
    end

    self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_Text(), text_color)

    local text = button.display_text:gsub("\\n", "\n")
    local lines = {}
    for line in text:gmatch("[^\n]+") do
        table.insert(lines, line)
    end

    local line_height = self.r.ImGui_GetTextLineHeight(ctx)
    local text_start_y = pos_y + (CONFIG.SIZES.HEIGHT - line_height * #lines) / 2
    local available_width = width - (CONFIG.ICON_FONT.PADDING * 2) - (icon_width or 0)
    local base_x = pos_x + CONFIG.ICON_FONT.PADDING + (icon_width or 0)

    for i, line in ipairs(lines) do
        local text_width = self.r.ImGui_CalcTextSize(ctx, line)
        local text_x = base_x

        if text_width < available_width then
            local offset = available_width - text_width
            if button.alignment == "center" then
                text_x = text_x + (offset / 2)
            elseif button.alignment == "right" then
                text_x = text_x + offset
            end
        end

        self.r.ImGui_SetCursorPos(ctx, text_x, text_start_y + (i - 1) * line_height)
        self.r.ImGui_Text(ctx, line)
    end

    self.r.ImGui_PopStyleColor(ctx)
end

function ButtonRenderer:renderTooltip(ctx, button, hover_time)
    if hover_time <= CONFIG.UI.HOVER_DELAY then
        return
    end

    local fade_progress = math.min((hover_time - CONFIG.UI.HOVER_DELAY) / 0.5, 1)
    local action_name = self.r.CF_GetCommandText(0, self.button_manager:getCommandID(button.id))

    if action_name then
        self.r.ImGui_BeginTooltip(ctx)
        self.r.ImGui_PushStyleVar(ctx, self.r.ImGui_StyleVar_Alpha(), fade_progress)
        self.r.ImGui_Text(ctx, action_name)
        self.r.ImGui_PopStyleVar(ctx)
        self.r.ImGui_EndTooltip(ctx)
    end
end

function ButtonRenderer:renderSeparator(ctx, pos_x, pos_y, width, window_pos, draw_list)
    -- Draw handle visuals
    local handle_height = CONFIG.SIZES.HEIGHT * 0.5
    local handle_y = pos_y + (CONFIG.SIZES.HEIGHT - handle_height) / 2
    local handle_color = self.helpers.hexToImGuiColor(CONFIG.COLORS.BORDER)

    -- Draw separator handle
    self.r.ImGui_DrawList_AddRectFilled(
        draw_list,
        window_pos.x + pos_x + 2,
        window_pos.y + handle_y,
        window_pos.x + pos_x + width - 2,
        window_pos.y + handle_y + handle_height,
        handle_color
    )

    -- Add invisible button for drag interaction
    self.r.ImGui_SetCursorPos(ctx, pos_x, pos_y)
    return self.r.ImGui_InvisibleButton(ctx, "##separator", width, CONFIG.SIZES.HEIGHT)
end

function ButtonRenderer:renderButton(ctx, button, pos_x, pos_y, icon_font, window_pos, draw_list, group)
    if button.is_separator then
        return self:renderSeparator(
            ctx,
            pos_x,
            pos_y,
            button.width or CONFIG.SIZES.SEPARATOR_WIDTH,
            window_pos,
            draw_list
        )
    end

    local width = self:calculateButtonWidth(ctx, button, icon_font)

    self.r.ImGui_SetCursorPos(ctx, pos_x, pos_y)
    self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_Button(), 0x00000000)
    self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_ButtonHovered(), 0x00000000)
    self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_ButtonActive(), 0x00000000)

    local clicked = self.r.ImGui_Button(ctx, "##" .. button.id, width, CONFIG.SIZES.HEIGHT)
    local is_hovered = self.r.ImGui_IsItemHovered(ctx)
    local is_clicked = self.r.ImGui_IsItemActive(ctx)

    self.r.ImGui_PopStyleColor(ctx, 3)

    if is_hovered then
        if not self.hover_start_times[button.id] then
            self.hover_start_times[button.id] = self.r.ImGui_GetTime(ctx)
        end
        self:renderTooltip(ctx, button, self.r.ImGui_GetTime(ctx) - self.hover_start_times[button.id])
    else
        self.hover_start_times[button.id] = nil
    end

    local bg_color, border_color, icon_color, text_color = self:getButtonColors(button, is_hovered, is_clicked)

    self:renderButtonBackground(draw_list, button, pos_x, pos_y, width, bg_color, border_color, window_pos, group)
    local icon_width = self:renderIcon(ctx, button, pos_x, pos_y, icon_font, icon_color, width)
    self:renderText(ctx, button, pos_x, pos_y, text_color, width, icon_width)

    if clicked then
        self.button_manager:executeCommand(button)
    elseif is_hovered and self.r.ImGui_IsMouseClicked(ctx, 1) then
        if
            self.r.ImGui_IsKeyDown(ctx, self.r.ImGui_Key_LeftAlt()) or
                self.r.ImGui_IsKeyDown(ctx, self.r.ImGui_Key_RightAlt())
         then
            if button.on_context_menu then
                button.on_context_menu()
            end
        else
            self.button_manager:handleRightClick(button)
        end
    end

    return width
end

function ButtonRenderer:renderGroup(ctx, group, pos_x, pos_y, window_pos, draw_list, icon_font)
    local total_width = 0
    local total_height = CONFIG.SIZES.HEIGHT
    local current_x = pos_x

    -- Calculate total width and render buttons
    for i, button in ipairs(group.buttons) do
        local button_width = self:renderButton(ctx, button, current_x, pos_y, icon_font, window_pos, draw_list, group)
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
function ButtonRenderer:cleanup()
    -- Clean up any resources if needed
    self.hover_start_times = {}
end

return ButtonRenderer
