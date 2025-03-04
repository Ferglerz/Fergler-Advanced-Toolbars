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
        apply_to_group = false,
        apply_to_icon = false,
        apply_to_text = false,
        color_type = "background" -- Default color type
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

    -- Get color type
    local color_type = self.color_picker_state.color_type

    -- Initialize custom color settings if they don't exist
    if not button.custom_color then
        button.custom_color = {}
    end
    
    -- Create or update custom colors for the specific type
    if color_type == "background" then
        -- Calculate derived colors for background
        local hoverColor, clickedColor = self.helpers.getDerivedColors(baseColor, CONFIG.COLORS.NORMAL.BG.NORMAL, CONFIG.COLORS.NORMAL.BG.HOVER, CONFIG.COLORS.NORMAL.BG.CLICKED)
        
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
                if not groupButton.custom_color then
                    groupButton.custom_color = {}
                end
                groupButton.custom_color.background = colorSettings
            end
        else
            button.custom_color.background = colorSettings
        end
    elseif color_type == "border" then
        -- Calculate derived colors for border
        local hoverColor, clickedColor = self.helpers.getDerivedColors(baseColor, CONFIG.COLORS.NORMAL.BORDER.NORMAL, CONFIG.COLORS.NORMAL.BORDER.HOVER, CONFIG.COLORS.NORMAL.BORDER.CLICKED)
        
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
                if not groupButton.custom_color then
                    groupButton.custom_color = {}
                end
                groupButton.custom_color.border = colorSettings
            end
        else
            button.custom_color.border = colorSettings
        end
    elseif color_type == "text" then
        -- Calculate derived colors for text
        local hoverColor, clickedColor = self.helpers.getDerivedColors(baseColor, CONFIG.COLORS.NORMAL.TEXT.NORMAL, CONFIG.COLORS.NORMAL.TEXT.HOVER, CONFIG.COLORS.NORMAL.TEXT.CLICKED)
        
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
                if not groupButton.custom_color then
                    groupButton.custom_color = {}
                end
                groupButton.custom_color.text = colorSettings
                
                -- Apply to icon if that toggle is on
                if self.color_picker_state.apply_to_icon then
                    groupButton.custom_color.icon = colorSettings
                end
            end
        else
            button.custom_color.text = colorSettings
            
            -- Apply to icon if that toggle is on
            if self.color_picker_state.apply_to_icon then
                button.custom_color.icon = colorSettings
            end
        end
    elseif color_type == "icon" then
        -- Calculate derived colors for icon
        local hoverColor, clickedColor = self.helpers.getDerivedColors(baseColor, CONFIG.COLORS.NORMAL.ICON.NORMAL, CONFIG.COLORS.NORMAL.ICON.HOVER, CONFIG.COLORS.NORMAL.ICON.CLICKED)
        
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
                if not groupButton.custom_color then
                    groupButton.custom_color = {}
                end
                groupButton.custom_color.icon = colorSettings
                
                -- Apply to text if that toggle is on
                if self.color_picker_state.apply_to_text then
                    groupButton.custom_color.text = colorSettings
                end
            end
        else
            button.custom_color.icon = colorSettings
            
            -- Apply to text if that toggle is on
            if self.color_picker_state.apply_to_text then
                button.custom_color.text = colorSettings
            end
        end
    end

    saveConfig()
end

function ColorManager:renderColorPicker(ctx, button, toolbar, saveConfig, colorType)
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
        
        self.color_picker_state.current_color = self.helpers.hexToImGuiColor(colorRef)
        self.color_picker_state.apply_to_group = false
        self.color_picker_state.apply_to_icon = false
        self.color_picker_state.apply_to_text = false
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
    
    -- Add type-specific toggles
    if colorType == "text" then
        local apply_icon_changed, apply_icon_value =
            self.r.ImGui_Checkbox(ctx, "Apply to icon", self.color_picker_state.apply_to_icon)
        if apply_icon_changed then
            self.color_picker_state.apply_to_icon = apply_icon_value
        end
    elseif colorType == "icon" then
        local apply_text_changed, apply_text_value =
            self.r.ImGui_Checkbox(ctx, "Apply to text", self.color_picker_state.apply_to_text)
        if apply_text_changed then
            self.color_picker_state.apply_to_text = apply_text_value
        end
    end

    -- Show color picker with persistent state
    local changed, new_color =
        self.r.ImGui_ColorPicker4(ctx, "##colorpicker" .. button.id .. colorType, 
                                 self.color_picker_state.current_color, flags)

    if changed then
        self:handleColorChange(button, new_color, toolbar, saveConfig)
    end
end

function ColorManager:cleanup()
    self.color_picker_state = {
        clicked_button = nil,
        current_color = 0,
        apply_to_group = false,
        apply_to_icon = false,
        apply_to_text = false,
        color_type = "background"
    }
end

return {
    new = function(reaper, helpers)
        return ColorManager.new(reaper, helpers)
    end
}