-- Windows/Button_Color_Editor.lua

local ButtonColorEditor = {}
ButtonColorEditor.__index = ButtonColorEditor

function ButtonColorEditor.new()
    local self = setmetatable({}, ButtonColorEditor)

    self.color_picker_state = {
        clicked_button = nil,
        current_color = 0,
        apply_to_group = false,
        apply_to_icon = false,
        apply_to_text = false,
        color_type = "background"
    }
    return self
end

function ButtonColorEditor:handleColorChange(button, new_color)
    self.color_picker_state.current_color = new_color

    -- Extract RGBA components and format as hex color
    local r = (new_color >> 24) & 0xFF
    local g = (new_color >> 16) & 0xFF
    local b = (new_color >> 8) & 0xFF
    local a = new_color & 0xFF
    local baseColor = string.format("#%02X%02X%02X%02X", r, g, b, a)

    -- Get color type and ensure custom_color exists
    local color_type = self.color_picker_state.color_type
    if not button.custom_color then
        button.custom_color = {}
    end

    -- Get target buttons
    local targetButtons = {button}
    if self.color_picker_state.apply_to_group and button.parent_group then
        targetButtons = button.parent_group.buttons
    end

    -- Apply colors to all target buttons
    for _, targetButton in ipairs(targetButtons) do
        if not targetButton.custom_color then
            targetButton.custom_color = {}
        end

        -- Apply color
        if not targetButton.custom_color[color_type] then
            targetButton.custom_color[color_type] = {}
        end
        targetButton.custom_color[color_type].normal = baseColor

        -- Apply linked color if needed
        local shouldApplyLink =
            (color_type == "text" and self.color_picker_state.apply_to_icon) or
            (color_type == "icon" and self.color_picker_state.apply_to_text)

        if shouldApplyLink then
            local linked_key = color_type == "text" and "icon" or "text"
            if not targetButton.custom_color[linked_key] then
                targetButton.custom_color[linked_key] = {}
            end
            targetButton.custom_color[linked_key].normal = baseColor
        end
    end

    CONFIG_MANAGER:saveToolbarConfig(button.parent_toolbar)
end

function ButtonColorEditor:renderColorPicker(ctx, button, colorType)
    -- Set color type
    colorType = colorType or "background"

    -- Initialize color state when menu is opened
    if self.color_picker_state.clicked_button ~= button or self.color_picker_state.color_type ~= colorType then
        self.color_picker_state.clicked_button = button
        self.color_picker_state.color_type = colorType

        -- Initialize color based on type
        local colorRef
        if button.custom_color then
            if colorType == "background" and button.custom_color.background then
                colorRef = button.custom_color.background.normal
            elseif colorType == "border" and button.custom_color.border then
                colorRef = button.custom_color.border.normal
            elseif colorType == "text" and button.custom_color.text then
                colorRef = button.custom_color.text.normal
            elseif colorType == "icon" and button.custom_color.icon then
                colorRef = button.custom_color.icon.normal
            end
        end

        -- Default colors if no custom color is set
        if not colorRef then
            if colorType == "background" then
                colorRef = CONFIG.COLORS.NORMAL.BG.NORMAL
            elseif colorType == "border" then
                colorRef = CONFIG.COLORS.NORMAL.BORDER.NORMAL
            elseif colorType == "text" then
                colorRef = CONFIG.COLORS.NORMAL.TEXT.NORMAL
            elseif colorType == "icon" then
                colorRef = CONFIG.COLORS.NORMAL.ICON.NORMAL
            end
        end

        self.color_picker_state.current_color = COLOR_UTILS.toImGuiColor(colorRef)
        self.color_picker_state.apply_to_group = false
        self.color_picker_state.apply_to_icon = false
        self.color_picker_state.apply_to_text = false
    end

    local flags =
        reaper.ImGui_ColorEditFlags_AlphaBar() | reaper.ImGui_ColorEditFlags_AlphaPreview() |
        reaper.ImGui_ColorEditFlags_NoInputs() |
        reaper.ImGui_ColorEditFlags_PickerHueBar() |
        reaper.ImGui_ColorEditFlags_DisplayRGB() |
        reaper.ImGui_ColorEditFlags_DisplayHex()

    -- Add apply to group checkbox
    local apply_changed, apply_value =
        reaper.ImGui_Checkbox(ctx, "Apply to group", self.color_picker_state.apply_to_group)
    if apply_changed then
        self.color_picker_state.apply_to_group = apply_value
    end

    -- Add type-specific toggles
    if colorType == "text" then
        local apply_icon_changed, apply_icon_value =
            reaper.ImGui_Checkbox(ctx, "Apply to icon", self.color_picker_state.apply_to_icon)
        if apply_icon_changed then
            self.color_picker_state.apply_to_icon = apply_icon_value
        end
    elseif colorType == "icon" then
        local apply_text_changed, apply_text_value =
            reaper.ImGui_Checkbox(ctx, "Apply to text", self.color_picker_state.apply_to_text)
        if apply_text_changed then
            self.color_picker_state.apply_to_text = apply_text_value
        end
    end

    -- Show color picker with persistent state
    local changed, new_color =
        reaper.ImGui_ColorPicker4(
        ctx,
        "##colorpicker" .. button.id .. colorType,
        self.color_picker_state.current_color,
        flags
    )

    if changed then
        self:handleColorChange(button, new_color)
    end
end

function ButtonColorEditor:cleanup()
    self.color_picker_state = {
        clicked_button = nil,
        current_color = 0,
        apply_to_group = false,
        apply_to_icon = false,
        apply_to_text = false,
        color_type = "background"
    }
end

return ButtonColorEditor.new()
