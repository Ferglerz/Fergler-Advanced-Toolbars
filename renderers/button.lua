-- renderers/button.lua
local ButtonContent = require "button_content"
local ColorUtils = require "color_utils"
local GroupRenderer = require "renderers/group"

local ButtonRenderer = {}
ButtonRenderer.__index = ButtonRenderer

function ButtonRenderer.new(reaper, state, helpers)
    local self = setmetatable({}, ButtonRenderer)
    self.r = reaper
    self.state = state
    self.helpers = helpers
    self.ColorUtils = ColorUtils
    self.group_renderer = GroupRenderer.new(reaper, helpers)
    return self
end

function ButtonRenderer:renderButton(ctx, button, pos_x, pos_y, icon_font, window_pos, draw_list, editing_mode)
    -- Early return for separators
    if button.is_separator then
        -- Inline separator rendering
        local handle_height = CONFIG.SIZES.HEIGHT * 0.5
        local handle_y = pos_y + (CONFIG.SIZES.HEIGHT - handle_height) / 2
        local handle_color = self.ColorUtils.hexToImGuiColor(CONFIG.COLORS.BORDER)

        self.r.ImGui_DrawList_AddRectFilled(
            draw_list,
            window_pos.x + pos_x + 2,
            window_pos.y + handle_y,
            window_pos.x + pos_x + (button.width or CONFIG.SIZES.SEPARATOR_WIDTH) - 2,
            window_pos.y + handle_y + handle_height,
            handle_color
        )

        self.r.ImGui_SetCursorPos(ctx, pos_x, pos_y)
        self.r.ImGui_InvisibleButton(ctx, "##separator", button.width or CONFIG.SIZES.SEPARATOR_WIDTH, CONFIG.SIZES.HEIGHT)
        
        return button.width or CONFIG.SIZES.SEPARATOR_WIDTH
    end

    -- Calculate dimensions once - this now considers preset.width
    local width, extra_padding = ButtonContent.calculateButtonWidth(ctx, button, self.helpers)

    -- Set up invisible button for interaction - inline setupInteractionArea
    self.r.ImGui_SetCursorPos(ctx, pos_x, pos_y)
    
    -- Batch all style colors at once
    self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_Button(), 0x00000000)
    self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_ButtonHovered(), 0x00000000)
    self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_ButtonActive(), 0x00000000)
    
    -- Track mouse state and handle interactions - inline trackButtonState
    local clicked = self.r.ImGui_Button(ctx, "##" .. button.id, width, CONFIG.SIZES.HEIGHT)
    local is_hovered = self.r.ImGui_IsItemHovered(ctx)
    local is_clicked = self.r.ImGui_IsItemActive(ctx)

    -- Pop all style colors at once
    self.r.ImGui_PopStyleColor(ctx, 3)

    -- Track hover transitions
    local hover_changed = button.is_hovered ~= is_hovered
    
    -- Handle hover tracking and tooltips via state manager
    if is_hovered then
        local hover_time = self.state:trackHoverState(ctx, button.id, true)
        if not editing_mode then
            -- Inline tooltip rendering
            if hover_time > CONFIG.UI.HOVER_DELAY then
                local fade_progress = math.min((hover_time - CONFIG.UI.HOVER_DELAY) / 0.5, 1)
                local command_id = self.state:getCommandID(button.id)
                local action_name = command_id and self.r.CF_GetCommandText(0, command_id)

                if action_name and action_name ~= "" then
                    self.r.ImGui_BeginTooltip(ctx)
                    self.r.ImGui_PushStyleVar(ctx, self.r.ImGui_StyleVar_Alpha(), fade_progress)
                    self.r.ImGui_Text(ctx, action_name)
                    self.r.ImGui_PopStyleVar(ctx)
                    self.r.ImGui_EndTooltip(ctx)
                end
            end
        end
    else
        self.state:trackHoverState(ctx, button.id, false)
    end

    -- Track right-click state
    button.is_right_clicked = is_hovered and self.r.ImGui_IsMouseClicked(ctx, 1)

    -- Handle click via state manager, but only if not a slider preset
    if clicked and not (button.preset and button.preset.type == "slider") then
        self.state:handleButtonClick(button, false)
    end

    -- Store previous hover state to detect changes
    button.is_hovered = is_hovered
    
    -- Calculate colors directly
    local state_key = button.is_toggled and "TOGGLED" or (button.is_armed and (button.is_flashing and "ARMED_FLASH" or "ARMED") or "NORMAL")
    local mouse_key = is_clicked and "CLICKED" or (is_hovered and "HOVER" or "NORMAL")
    local mouse_key_lower = mouse_key:lower()
    
    local colors = {
        background = CONFIG.COLORS[state_key].BG[mouse_key],
        border = CONFIG.COLORS[state_key].BORDER[mouse_key],
        icon = CONFIG.COLORS[state_key].ICON[mouse_key],
        text = CONFIG.COLORS[state_key].TEXT[mouse_key]
    }
    
    if button.custom_color and state_key == "NORMAL" then
        for key, value in pairs(button.custom_color) do
            colors[key] = value[mouse_key_lower] or value.normal
        end
    end
    
    local bg_color = self.ColorUtils.hexToImGuiColor(colors.background)
    local border_color = self.ColorUtils.hexToImGuiColor(colors.border)
    local icon_color = self.ColorUtils.hexToImGuiColor(colors.icon)
    local text_color = self.ColorUtils.hexToImGuiColor(colors.text)

    -- Render the background - inline renderBackground
    if window_pos then
        local flags = self:getRoundingFlags(button)
        
        -- Use cached position coordinates if they're valid
        local screen_coords = button.screen_coords
        local recalculate = not screen_coords or 
                            screen_coords.window_x ~= window_pos.x or 
                            screen_coords.window_y ~= window_pos.y or
                            screen_coords.pos_x ~= pos_x or
                            screen_coords.pos_y ~= pos_y or
                            screen_coords.width ~= width
        
        if recalculate then
            -- Store the coordinates in a new table to avoid creating garbage each frame
            if not screen_coords then
                screen_coords = {}
            end
            
            screen_coords.window_x = window_pos.x
            screen_coords.window_y = window_pos.y
            screen_coords.pos_x = pos_x
            screen_coords.pos_y = pos_y
            screen_coords.width = width
            
            screen_coords.x1 = window_pos.x + pos_x
            screen_coords.y1 = window_pos.y + pos_y
            screen_coords.x2 = screen_coords.x1 + width
            screen_coords.y2 = screen_coords.y1 + CONFIG.SIZES.HEIGHT
            
            button.screen_coords = screen_coords
        end
        
        local x1, y1, x2, y2 = screen_coords.x1, screen_coords.y1, screen_coords.x2, screen_coords.y2
        
        -- Render shadow
        if CONFIG.SIZES.DEPTH > 0 then
            self.r.ImGui_DrawList_AddRectFilled(
                draw_list,
                x1 + CONFIG.SIZES.DEPTH,
                y1 + CONFIG.SIZES.DEPTH,
                x2 + CONFIG.SIZES.DEPTH,
                y2 + CONFIG.SIZES.DEPTH,
                self.ColorUtils.hexToImGuiColor(CONFIG.COLORS.SHADOW),
                CONFIG.SIZES.ROUNDING,
                flags
            )
        end
        
        -- Render button background and border
        self.r.ImGui_DrawList_AddRectFilled(draw_list, x1, y1, x2, y2, bg_color, CONFIG.SIZES.ROUNDING, flags)
        self.r.ImGui_DrawList_AddRect(draw_list, x1, y1, x2, y2, border_color, CONFIG.SIZES.ROUNDING, flags)
    end

    -- For preset buttons, delegate rendering to preset_renderer 
    if button.preset and not editing_mode and self.preset_renderer then
        local handled, preset_width = self.preset_renderer:renderPreset(
            ctx, button, pos_x, pos_y, width, window_pos, draw_list
        )
        
        -- Important: Even though preset rendering is handled by preset_renderer,
        -- we still need to check for context menu
        if button.is_right_clicked and (
           self.r.ImGui_IsKeyDown(ctx, self.r.ImGui_Mod_Ctrl()) or
           self.r.ImGui_IsKeyDown(ctx, self.r.ImGui_Key_RightCtrl()) or
           self.r.ImGui_IsKeyDown(ctx, self.r.ImGui_Key_LeftCtrl())
        ) then
            if button.on_context_menu then
                button.on_context_menu()
            end
        end
        
        if handled then
            -- Only mark as clean if there's no hover transition happening
            if not hover_changed then
                button:markClean()
            else
                -- Keep button dirty during hover transitions
                button.is_dirty = true
            end
            
            return width
        end
    end

    -- Always render content based on mode
    if editing_mode and is_hovered then
        -- Inline renderEditMode
        local edit_text = "Edit"
        local text_width = self.r.ImGui_CalcTextSize(ctx, edit_text)
        local text_x = pos_x + (width - text_width) / 2
        local text_y = pos_y + (CONFIG.SIZES.HEIGHT - self.r.ImGui_GetTextLineHeight(ctx)) / 2

        self.r.ImGui_SetCursorPos(ctx, text_x, text_y)
        self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_Text(), text_color)
        self.r.ImGui_Text(ctx, edit_text)
        self.r.ImGui_PopStyleColor(ctx)
    else
        -- Inline renderButtonContent
        local icon_width = ButtonContent.renderIcon(
            ctx,
            self.r,
            button,
            pos_x,
            pos_y,
            self.icon_font_selector,
            icon_color,
            width,
            self.state,
            self.helpers,
            extra_padding
        )

        ButtonContent.renderText(ctx, self.r, button, pos_x, pos_y, text_color, width, icon_width, extra_padding)
    end
        
    -- Only mark as clean if there's no hover transition happening
    if not hover_changed then
        button:markClean()
    else
        -- Keep button dirty during hover transitions
        button.is_dirty = true
    end

    return width
end

function ButtonRenderer:getRoundingFlags(button)
    if not CONFIG.UI.USE_GROUPING or button.is_alone then
        return self.r.ImGui_DrawFlags_RoundCornersAll()
    elseif button.is_section_start then
        return self.r.ImGui_DrawFlags_RoundCornersLeft()
    elseif button.is_section_end then
        return self.r.ImGui_DrawFlags_RoundCornersRight()
    end
    return self.r.ImGui_DrawFlags_RoundCornersNone()
end

function ButtonRenderer:renderGroup(ctx, group, pos_x, pos_y, window_pos, draw_list, icon_font, editing_mode)
    -- Use cached dimensions if available
    local cached_dims = group:getDimensions()
    if cached_dims then
        -- Still need to render each button
        local current_x = pos_x
        for i, button in ipairs(group.buttons) do
            local button_width =
                self:renderButton(
                ctx,
                button,
                current_x,
                pos_y,
                icon_font,
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
        if self.group_renderer:shouldRenderGroupLabel(group) then
            self.group_renderer:renderGroupLabel(ctx, group, pos_x, pos_y, cached_dims.width, window_pos, draw_list)
        end

        return cached_dims.width, cached_dims.height
    end

    local total_width = 0
    local total_height = CONFIG.SIZES.HEIGHT
    local current_x = pos_x

    for i, button in ipairs(group.buttons) do
        local button_width =
            self:renderButton(
            ctx,
            button,
            current_x,
            pos_y,
            icon_font,
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
    if self.group_renderer:shouldRenderGroupLabel(group) then
        local label_height = self.group_renderer:renderGroupLabel(ctx, group, pos_x, pos_y, total_width, window_pos, draw_list)
        total_height = total_height + label_height
    end

    -- Cache dimensions
    group:cacheDimensions(total_width, total_height)

    return total_width, total_height
end

return ButtonRenderer