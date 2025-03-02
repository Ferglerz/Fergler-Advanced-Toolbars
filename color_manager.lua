-- color_manager.lua

local ColorManager = {}
ColorManager.__index = ColorManager

function ColorManager.new(reaper, helpers)
    local self = setmetatable({}, ColorManager)
    self.r = reaper
    self.helpers = helpers
    self.color_picker_state = {
        clicked_button = nil,
        current_color = 0,
        apply_to_group = false
    }
    return self
end

function ColorManager:getCurrentButtonGroup(button, toolbar)
    local group = {}
    if not toolbar then
        return group
    end

    -- Find group boundaries
    local start_idx, end_idx
    for i, btn in ipairs(toolbar.buttons) do
        if btn == button then
            -- Search backwards for group start
            start_idx = i
            while start_idx > 1 and not toolbar.buttons[start_idx - 1].is_separator do
                start_idx = start_idx - 1
            end

            -- Search forwards for group end
            end_idx = i
            while end_idx < #toolbar.buttons and not toolbar.buttons[end_idx + 1].is_separator do
                end_idx = end_idx + 1
            end
            break
        end
    end

    -- Collect buttons in group
    if start_idx and end_idx then
        for i = start_idx, end_idx do
            table.insert(group, toolbar.buttons[i])
        end
    end

    return group
end

function ColorManager:handleColorChange(button, new_color, toolbar, saveConfig)
    -- Update state
    self.color_picker_state.current_color = new_color

    -- Extract RGBA components
    local r = (new_color >> 24) & 0xFF
    local g = (new_color >> 16) & 0xFF
    local b = (new_color >> 8) & 0xFF
    local a = new_color & 0xFF

    -- Format as hex color
    local baseColor = string.format("#%02X%02X%02X%02X", r, g, b, a)

    -- Calculate derived colors
    local hoverColor, clickedColor = self.helpers.getDerivedColors(baseColor, CONFIG.COLORS.NORMAL.BG.COLOR, CONFIG.COLORS.NORMAL.BG.HOVER, CONFIG.COLORS.NORMAL.BG.CLICKED)

    -- Create color settings
    local colorSettings = {
        normal = baseColor,
        hover = hoverColor,
        clicked = clickedColor
    }

    -- Apply to button(s)
    if self.color_picker_state.apply_to_group then
        local currentGroup = self:getCurrentButtonGroup(button, toolbar)
        for _, groupButton in ipairs(currentGroup) do
            groupButton.custom_color = colorSettings
        end
    else
        button.custom_color = colorSettings
    end

    saveConfig()
end

function ColorManager:renderColorPicker(ctx, button, toolbar, saveConfig)
    -- Initialize color state when menu is opened
    if self.color_picker_state.clicked_button ~= button then
        self.color_picker_state.clicked_button = button
        self.color_picker_state.current_color =
            self.helpers.hexToImGuiColor(button.custom_color and button.custom_color.normal or CONFIG.COLORS.NORMAL.BG.COLOR)
        self.color_picker_state.apply_to_group = false
    end

    local flags =
        self.r.ImGui_ColorEditFlags_AlphaBar() | self.r.ImGui_ColorEditFlags_AlphaPreview() |
        self.r.ImGui_ColorEditFlags_NoInputs() |
        self.r.ImGui_ColorEditFlags_PickerHueBar() |
        self.r.ImGui_ColorEditFlags_DisplayRGB() |
        self.r.ImGui_ColorEditFlags_DisplayHex()

    -- Add apply to group checkbox
    local apply_changed, apply_value =
        self.r.ImGui_Checkbox(ctx, "Apply to group", self.color_picker_state.apply_to_group)
    if apply_changed then
        self.color_picker_state.apply_to_group = apply_value
    end

    -- Show color picker with persistent state
    local changed, new_color =
        self.r.ImGui_ColorPicker4(ctx, "##colorpicker" .. button.id, self.color_picker_state.current_color, flags)

    if changed then
        self:handleColorChange(button, new_color, toolbar, saveConfig)
    end
end

function ColorManager:cleanup()
    self.color_picker_state = {
        clicked_button = nil,
        current_color = 0,
        apply_to_group = false
    }
end

return {
    new = function(reaper, helpers)
        return ColorManager.new(reaper, helpers)
    end
}
