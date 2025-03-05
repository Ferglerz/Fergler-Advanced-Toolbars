-- button_renderer.lua
local ButtonVisuals = require "button_visuals"
local ButtonContent = require "button_content"
local ColorUtils = require "color_utils"
local GroupRenderer = require "group_renderer"

local ButtonRenderer = {}
ButtonRenderer.__index = ButtonRenderer

function ButtonRenderer.new(reaper, button_state, helpers)
    local self = setmetatable({}, ButtonRenderer)
    self.r = reaper
    self.button_state = button_state
    self.helpers = helpers
    self.hover_start_times = {}
    self.ColorUtils = ColorUtils
    self.group_renderer = GroupRenderer.new(reaper, helpers)
    return self
end

function ButtonRenderer:renderButton(ctx, button, pos_x, pos_y, icon_font, window_pos, draw_list, editing_mode)
    -- Early return for separators
    if button.is_separator then
        return ButtonVisuals.renderSeparator(
            ctx,
            self.r,
            pos_x,
            pos_y,
            button.width or CONFIG.SIZES.SEPARATOR_WIDTH,
            window_pos,
            draw_list
        )
    end

    -- Calculate dimensions once
    local width, extra_padding = ButtonContent.calculateButtonWidth(ctx, button, icon_font, self.helpers)

    -- Set up invisible button for interaction
    self:setupInteractionArea(ctx, pos_x, pos_y, width)

    -- Track mouse state and handle interactions
    local is_hovered, is_clicked = self:trackButtonState(ctx, button, width, editing_mode)

    -- Get colors based on state
    local bg_color, border_color, icon_color, text_color =
        ButtonVisuals.getButtonColors(button, is_hovered, is_clicked, self.helpers)

    -- Render visuals
    ButtonVisuals.renderBackground(
        self.r,
        draw_list,
        button,
        pos_x,
        pos_y,
        width,
        bg_color,
        border_color,
        window_pos
    )

    -- Render content based on mode
    if editing_mode and is_hovered then
        self:renderEditMode(ctx, pos_x, pos_y, width, text_color)
    else
        self:renderButtonContent(ctx, button, pos_x, pos_y, icon_font, icon_color, text_color, width, extra_padding)
    end

    return width
end

-- Set up the invisible button for interaction
function ButtonRenderer:setupInteractionArea(ctx, pos_x, pos_y, width)
    self.r.ImGui_SetCursorPos(ctx, pos_x, pos_y)
    self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_Button(), 0x00000000)
    self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_ButtonHovered(), 0x00000000)
    self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_ButtonActive(), 0x00000000)
end

-- Handle interaction state tracking and events
function ButtonRenderer:trackButtonState(ctx, button, width, editing_mode)
    local clicked = self.r.ImGui_Button(ctx, "##" .. button.id, width, CONFIG.SIZES.HEIGHT)
    local is_hovered = self.r.ImGui_IsItemHovered(ctx)
    local is_clicked = self.r.ImGui_IsItemActive(ctx)

    self.r.ImGui_PopStyleColor(ctx, 3)

    -- Store states on button
    button.is_hovered = is_hovered
    button.is_right_clicked = is_hovered and self.r.ImGui_IsMouseClicked(ctx, 1)

    -- Handle hover tracking and tooltips
    if is_hovered then
        local hover_time = self.button_state:trackHoverState(ctx, button.id, true)
        if not editing_mode then
            ButtonVisuals.renderTooltip(ctx, self.r, button, hover_time, self.button_state)
        end
    else
        self.button_state:trackHoverState(ctx, button.id, false)
    end

    -- Handle click
    if clicked then
        self.button_state:buttonClicked(button, false)
    end

    return is_hovered, is_clicked
end

-- Render edit mode overlay
function ButtonRenderer:renderEditMode(ctx, pos_x, pos_y, width, text_color)
    -- Center "Edit" text in the button
    local edit_text = "Edit"
    local text_width = self.r.ImGui_CalcTextSize(ctx, edit_text)
    local text_x = pos_x + (width - text_width) / 2
    local text_y = pos_y + (CONFIG.SIZES.HEIGHT - self.r.ImGui_GetTextLineHeight(ctx)) / 2

    self.r.ImGui_SetCursorPos(ctx, text_x, text_y)
    self.r.ImGui_PushStyleColor(ctx, self.r.ImGui_Col_Text(), text_color)
    self.r.ImGui_Text(ctx, edit_text)
    self.r.ImGui_PopStyleColor(ctx)
end

-- Render normal button content
function ButtonRenderer:renderButtonContent(
    ctx,
    button,
    pos_x,
    pos_y,
    icon_font,
    icon_color,
    text_color,
    width,
    extra_padding)
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
        self.button_state,
        self.helpers,
        extra_padding
    )

    ButtonContent.renderText(ctx, self.r, button, pos_x, pos_y, text_color, width, icon_width, extra_padding)
end

function ButtonRenderer:renderGroup(ctx, group, pos_x, pos_y, window_pos, draw_list, icon_font, editing_mode)
    return self.group_renderer:renderGroup(
        ctx, 
        group, 
        pos_x, 
        pos_y, 
        window_pos, 
        draw_list, 
        icon_font, 
        editing_mode, 
        self
    )
end

return ButtonRenderer