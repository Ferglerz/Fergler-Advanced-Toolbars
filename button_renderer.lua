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

    -- Calculate icon width using the helper function
    local icon_width = 0
    if button.icon_char and icon_font then
        icon_width = self.helpers.calculateTextWidth(ctx, button.icon_char, icon_font)
    elseif button.icon_texture and button.icon_dimensions then
        icon_width = button.icon_dimensions.width
    end

    -- Calculate total button width
    local total_width = 0
    if icon_width > 0 and max_text_width > 0 then
        -- Icon and text present: include padding between icon and text
        total_width = math.max(CONFIG.SIZES.MIN_WIDTH, icon_width + CONFIG.ICON_FONT.PADDING + max_text_width )
    elseif icon_width > 0 and max_text_width == 0 then
        -- Only an icon
        total_width = icon_width
    else
        -- Only text
        total_width = math.max(CONFIG.SIZES.MIN_WIDTH, max_text_width)
    end

    -- Add padding to both sides
    total_width = total_width + (CONFIG.ICON_FONT.PADDING * 2)

    -- Ensure the button respects the minimum width
    return  total_width
end



function ButtonRenderer:getButtonColors(button, is_hovered, is_active)
    -- First check for custom color - but ONLY if not armed
    if button.custom_color and not button.is_toggled and not button.is_armed then        
        if is_active then
            return self.helpers.hexToImGuiColor(button.custom_color.active)
        elseif is_hovered then
            return self.helpers.hexToImGuiColor(button.custom_color.hover)
        end
        return self.helpers.hexToImGuiColor(button.custom_color.normal)
    end

    -- Determine the base state category
    local category = "NORMAL"
    if button.is_armed then
        category = button.is_flashing and "ARMED_FLASH" or "ARMED"
        if button.is_toggled then
            if is_hovered then
                return self.helpers.hexToImGuiColor(CONFIG.COLORS[category].TOGGLED_HOVER)
            end
            return self.helpers.hexToImGuiColor(CONFIG.COLORS[category].TOGGLED_COLOR)
        end
    elseif button.is_toggled then
        category = "TOGGLED"
    end

    -- Get appropriate color based on state
    if is_active then 
        return self.helpers.hexToImGuiColor(CONFIG.COLORS.NORMAL.ACTIVE)
    elseif is_hovered then 
        return self.helpers.hexToImGuiColor(CONFIG.COLORS[category].HOVER)
    end
    return self.helpers.hexToImGuiColor(CONFIG.COLORS[category].COLOR)
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

function ButtonRenderer:renderButtonBackground(ctx, draw_list, button, pos_x, pos_y, width, color, window_pos, group)
    if not window_pos then return end
    
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
        x1, y1, x2, y2,
        self.helpers.hexToImGuiColor(color),
        CONFIG.SIZES.ROUNDING,
        flags
    )
    
    self.r.ImGui_DrawList_AddRect(
            draw_list,
            x1, y1, x2, y2,
            self.helpers.hexToImGuiColor(CONFIG.SIZES.BORDER),
            CONFIG.SIZES.ROUNDING,
            flags
        )
   
    
end

function ButtonRenderer:renderIcon(ctx, button, pos_x, pos_y, icon_font, text_color, total_width)
    local icon_width = 0

    -- Calculate text width first
    local max_text_width = 0
    local show_text = not (button.hide_label or CONFIG.UI.HIDE_ALL_LABELS)
    local max_text_width = 0
if show_text then
    max_text_width = self.helpers.calculateTextWidth(ctx, button.display_text, nil)
end

    -- Handle icon character first since it takes precedence
    if button.icon_char and icon_font then
        -- Push font for measurement and rendering
        self.r.ImGui_PushFont(ctx, icon_font)
        
        -- Get character width
        local char_width = self.r.ImGui_CalcTextSize(ctx, button.icon_char)
        
        -- Calculate position based on whether text is shown
        local icon_x
        if show_text and max_text_width > 0 then
            local group_width = char_width + CONFIG.ICON_FONT.PADDING + max_text_width
            local group_start = pos_x + (total_width - group_width) / 2
            group_start = math.max(group_start, pos_x + CONFIG.ICON_FONT.PADDING)
            icon_x = group_start
        else
            -- If no text, center the icon in the button
            icon_x = pos_x + (total_width - char_width) / 2
        end
        
        -- Calculate vertical centering
        local icon_y = pos_y + (CONFIG.SIZES.HEIGHT / 2) 
            
        -- Set icon color
        local icon_color = CONFIG.COLORS.FONT_ICON_COLOR and 
            self.helpers.hexToImGuiColor(CONFIG.COLORS.FONT_ICON_COLOR) or 
            text_color
            
        self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_Text(), icon_color)
        self.r.ImGui_SetCursorPos(ctx, icon_x, icon_y)
        self.r.ImGui_Text(ctx, button.icon_char)
        self.r.ImGui_PopStyleColor(ctx)
        self.r.ImGui_PopFont(ctx)
        
        icon_width = char_width + (show_text and max_text_width > 0 and CONFIG.ICON_FONT.PADDING or 0)
    end
    
    -- Handle image icon if no character icon is set
    if icon_width == 0 and button.icon_path then
        self.button_manager:loadIcon(button)
        
        if button.icon_texture then
            local dims = button.icon_dimensions
            if dims then
                local icon_x
                if show_text and max_text_width > 0 then
                    -- If showing text, use original group positioning
                    local group_width = dims.width + CONFIG.ICON_FONT.PADDING + max_text_width
                    local group_start = pos_x + (total_width - group_width) / 2
                    group_start = math.max(group_start, pos_x + CONFIG.ICON_FONT.PADDING)
                    icon_x = group_start
                else
                    -- If no text, center the icon in the button
                    icon_x = pos_x + (total_width - dims.width) / 2
                end
                
                -- Calculate vertical centering
                local icon_y = pos_y + (CONFIG.SIZES.HEIGHT - dims.height) / 2
                
                self.r.ImGui_SetCursorPos(ctx, icon_x, icon_y)
                self.r.ImGui_Image(ctx, button.icon_texture, dims.width, dims.height)
                
                icon_width = dims.width + (show_text and max_text_width > 0 and CONFIG.ICON_FONT.PADDING or 0)
            end
        end
    end
    
    return icon_width
end

function ButtonRenderer:renderText(ctx, button, pos_x, pos_y, width, icon_width)
    if button.hide_label or CONFIG.UI.HIDE_ALL_LABELS then
        return
    end
    
    -- Set text color
    local text_color = self.helpers.hexToImGuiColor(
        button.is_toggled and CONFIG.COLORS.TOGGLED_TEXT or CONFIG.COLORS.TEXT
    )
    self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_Text(), text_color)

    local text = button.display_text:gsub("\\n", "\n")
    local lines = {}
    for line in text:gmatch("[^\n]+") do
        table.insert(lines, line)
    end
    
    local line_height = self.r.ImGui_GetTextLineHeight(ctx)
    local total_height = line_height * #lines
    local text_start_y = pos_y + (CONFIG.SIZES.HEIGHT - total_height) / 2
    
    local available_width = width - (CONFIG.ICON_FONT.PADDING * 2)
    if icon_width > 0 then
        available_width = available_width - icon_width
    end
    
    for i, line in ipairs(lines) do
        local text_width = self.r.ImGui_CalcTextSize(ctx, line)
        -- Always start with the base padding
        local text_x = pos_x + CONFIG.ICON_FONT.PADDING
        
        -- Add additional offset if there's an icon
        if icon_width > 0 then
            text_x = text_x + icon_width
        end
        
        if text_width < available_width then
            local remaining_space = available_width - text_width
            if button.alignment == "center" then
                text_x = text_x + (remaining_space / 2)
            elseif button.alignment == "right" then
                text_x = text_x + remaining_space
            end
        end
        
        self.r.ImGui_SetCursorPos(ctx, text_x, text_start_y + (i-1) * line_height)
        self.r.ImGui_Text(ctx, line)
    end

    self.r.ImGui_PopStyleColor(ctx)
end

function ButtonRenderer:renderTooltip(ctx, button, hover_time)
    local fade_duration = 0.5
    local fade_delay = 0.3
    local fade_progress = math.min((hover_time - fade_delay) / fade_duration, 1)
    
    if fade_progress > 0 then
        local action_name = self.r.CF_GetCommandText(0, self.button_manager:getCommandID(button.id))
        if action_name then
            self.r.ImGui_BeginTooltip(ctx)
            self.r.ImGui_PushStyleVar(ctx, self.r.ImGui_StyleVar_Alpha(), fade_progress)
            self.r.ImGui_Text(ctx, action_name)
            self.r.ImGui_PopStyleVar(ctx)
            self.r.ImGui_EndTooltip(ctx)
        end
    end
end

function ButtonRenderer:renderSeparator(ctx, pos_x, pos_y, width, window_pos, draw_list)
    -- Draw handle visuals
    local handle_height = CONFIG.SIZES.HEIGHT * 0.5
    local handle_y = pos_y + (CONFIG.SIZES.HEIGHT - handle_height) / 2
    local handle_color = self.helpers.hexToImGuiColor(CONFIG.SIZES.BORDER)
    
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
        return self:renderSeparator(ctx, pos_x, pos_y, button.width or CONFIG.SIZES.SEPARATOR_WIDTH, window_pos, draw_list)
    end
    
    -- Calculate button width
    local width = self:calculateButtonWidth(ctx, button, icon_font)
    
    -- Set up invisible button for interaction
    self.r.ImGui_SetCursorPos(ctx, pos_x, pos_y)    
    self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_Button(), 0x00000000)
    self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_ButtonHovered(), 0x00000000)
    self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_ButtonActive(), 0x00000000)
    
    local clicked = self.r.ImGui_Button(ctx, "##" .. button.id, width, CONFIG.HEIGHT)
    local is_hovered = self.r.ImGui_IsItemHovered(ctx)
    local is_active = self.r.ImGui_IsItemActive(ctx)
    
    self.r.ImGui_PopStyleColor(ctx, 3)
    
    -- Handle hover tooltip
    if is_hovered then
        if not self.hover_start_times[button.id] then
            self.hover_start_times[button.id] = self.r.ImGui_GetTime(ctx)
        end
        self:renderTooltip(ctx, button, self.r.ImGui_GetTime(ctx) - self.hover_start_times[button.id])
    else
        self.hover_start_times[button.id] = nil
    end
    
    -- Get button color based on state
    local color = self:getButtonColors(button, is_hovered, is_active)
    
    -- Get text color
    local text_color = self.helpers.hexToImGuiColor(
        button.is_toggled and CONFIG.COLORS.TOGGLED_TEXT or CONFIG.COLORS.TEXT
    )
    
    -- Render button visuals
    self:renderButtonBackground(ctx, draw_list, button, pos_x, pos_y, width, color, window_pos, group)
    local icon_width = self:renderIcon(ctx, button, pos_x, pos_y, icon_font, text_color, width)
    self:renderText(ctx, button, pos_x, pos_y, width, icon_width)
    
    -- Handle interactions
    if clicked then
        self.button_manager:executeCommand(button)
    elseif is_hovered and self.r.ImGui_IsMouseClicked(ctx, 1) then  -- Right click
        if self.r.ImGui_IsKeyDown(ctx, self.r.ImGui_Key_LeftAlt()) or
           self.r.ImGui_IsKeyDown(ctx, self.r.ImGui_Key_RightAlt()) then
            -- Alt + Right click - show context menu
            if button.on_context_menu then
                button.on_context_menu()
            end
        else
            -- Regular right click - handle arming
            self.button_manager:handleRightClick(button)
        end
    end
    
    return width
end

function ButtonRenderer:renderGroup(ctx, group, pos_x, pos_y, window_pos, draw_list, icon_font)
   
    -- Calculate initial dimensions
    local total_width = 0
    local total_height = CONFIG.SIZES.HEIGHT
    local content_x = pos_x 
    local content_y = pos_y
        
        -- First pass: calculate total width
    local current_x = content_x
    for i, button in ipairs(group.buttons) do
        local button_width = self:calculateButtonWidth(ctx, button, icon_font)
        total_width = total_width + button_width
        if i > 1 and not CONFIG.GROUPING then
        	total_width = total_width + CONFIG.SIZES.SPACING
        end
    end
    
   current_x = content_x
    for i, button in ipairs(group.buttons) do
        local button_width = self:renderButton(
            ctx, button, current_x, content_y, icon_font, window_pos, draw_list, group
        )
        current_x = current_x + button_width
        if i > 0 and not CONFIG.UI.GROUPING then
        	current_x = current_x + CONFIG.SIZES.SPACING
        end
    end
        
        
    -- Render group label if present
    if CONFIG.UI.USE_GROUP_LABELS and #group.label.text > 0 then
               
        -- Get text dimensions
        local text_width = self.r.ImGui_CalcTextSize(ctx, group.label.text)
        local text_height = self.r.ImGui_GetTextLineHeight(ctx)
        
        -- Calculate label position (centered below buttons)
        local label_x = (window_pos.x + pos_x + (total_width / 2)) - text_width / 2.18
        local label_y = window_pos.y + pos_y + total_height + 1  -- 4px padding
        
        
        -- Draw label text
        self.r.ImGui_DrawList_AddText(
            draw_list,
            label_x,
            label_y,
            self.helpers.hexToImGuiColor(CONFIG.COLORS.TEXT),
            group.label.text
        )
        
        -- Update total height to include label
        total_height = total_height + text_height + 8
        
        self:renderLabelDecoration(ctx, draw_list, group, label_x, label_y, text_width, text_height, window_pos, pos_x)

    end
    
        
    
    return total_width
end




function ButtonRenderer:renderLabelDecoration(ctx, draw_list, group, label_x, label_y, text_width, text_height, window_pos, pos_x)
    local line_color = self.helpers.hexToImGuiColor(CONFIG.COLORS.TEXT)
    local line_thickness = 1.0
    
        
    -- Calculate positions
    local screen_label_x = label_x
    local screen_label_y = label_y + (text_height/2) + 1
    
    
    local rounding = math.min(CONFIG.SIZES.ROUNDING, CONFIG.SIZES.HEIGHT / 2 )
    
    -- Use button rounding for curve size
    local curve_size = rounding + 4 + text_height / 2
    local h_padding = 10  -- Padding between label and horizontal lines
    
    local h_len = (label_x - h_padding) - (pos_x + curve_size)
    
    local left_x1 = pos_x + curve_size - text_height/2 + 2
    local left_x2 = label_x - h_padding
    
    local right_x1 = label_x + text_width + h_padding
    local right_x2 = label_x + text_width + h_padding + h_len
    
    -- Draw horizontal lines
    self.r.ImGui_DrawList_AddLine(
        draw_list,
        left_x1, screen_label_y,
        left_x2, screen_label_y,
        line_color,
        line_thickness
    )
    
    self.r.ImGui_DrawList_AddLine(
        draw_list,
        right_x1, screen_label_y,
        right_x2, screen_label_y,
        line_color,
        line_thickness
    )
    
    screen_label_y = screen_label_y - curve_size
    
    -- Function to create color with alpha
    local function getAlphaColor(base_color, alpha_factor)
        local r = (base_color >> 24) & 0xFF
        local g = (base_color >> 16) & 0xFF
        local b = (base_color >> 8) & 0xFF
        local a = math.floor(((base_color & 0xFF) * alpha_factor))
        return (r << 24) | (g << 16) | (b << 8) | a
    end
    
    -- Draw curved sections with fade using small line segments
    local segments = 16
    for i = 0, segments do
        local t = i / segments
        
        -- Left curve (flipped vertically, alpha fades from horizontal)
        local alpha_left = 1 - t  -- Alpha starts at 1 at horizontal line, fades as it goes up
        local color_left = getAlphaColor(line_color, alpha_left)
        
        local angle_left = math.pi * (1 - t) / 2  -- pi/2 to 0
        local x1_left = left_x1 - curve_size * math.cos(angle_left)
        local y1_left = screen_label_y + curve_size  * math.sin(angle_left)  -- Changed minus to plus
        
        if i < segments then
            local next_t = (i + 1) / segments
            local next_angle = math.pi * (1 - next_t) / 2
            local x2_left = left_x1 - curve_size  * math.cos(next_angle)
            local y2_left = screen_label_y + curve_size  * math.sin(next_angle)  -- Changed minus to plus
            
            self.r.ImGui_DrawList_AddLine(
                draw_list,
                x1_left, y1_left,
                x2_left, y2_left,
                color_left,
                line_thickness
            )
        end
        
        -- Right curve (flipped vertically, original alpha progression)
        local alpha_right = t  -- Alpha starts at 0 at horizontal line, increases as it goes up
        local color_right = getAlphaColor(line_color, alpha_right)
        
        local angle_right = math.pi * t / 2  -- 0 to pi/2
        local x1_right = right_x2 + curve_size * math.cos(angle_right)
        local y1_right = screen_label_y + curve_size * math.sin(angle_right)  -- Changed minus to plus
        
        if i < segments then
            local next_t = (i + 1) / segments
            local next_angle = math.pi * next_t / 2
            local x2_right = right_x2 + curve_size * math.cos(next_angle)
            local y2_right = screen_label_y + curve_size * math.sin(next_angle)  -- Changed minus to plus
            
            self.r.ImGui_DrawList_AddLine(
                draw_list,
                x1_right, y1_right,
                x2_right, y2_right,
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