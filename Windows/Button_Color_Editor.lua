-- Windows/Button_Color_Editor.lua

local ButtonColorEditor = {}
ButtonColorEditor.__index = ButtonColorEditor

function ButtonColorEditor.new()
    local self = setmetatable({}, ButtonColorEditor)

    self.color_picker_state = {
        clicked_button = nil,
        current_color = 0,
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

    -- Get target buttons based on global setting
    local targetButtons = {button}
    if CONFIG.COLOR_SETTINGS.APPLY_TO_GROUP and button.parent_group then
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
        elseif type(targetButton.custom_color[color_type]) ~= "table" then
            -- Convert existing string color to table format
            targetButton.custom_color[color_type] = {}
        end
        targetButton.custom_color[color_type].normal = baseColor

        -- Auto-generate hover and active colors for background and border
        if color_type == "background" or color_type == "border" then
            local configBaseColor = CONFIG.COLORS.NORMAL.BG.NORMAL
            local configHoverColor = CONFIG.COLORS.NORMAL.BG.HOVER
            local configClickedColor = CONFIG.COLORS.NORMAL.BG.CLICKED
            
            if color_type == "border" then
                configBaseColor = CONFIG.COLORS.NORMAL.BORDER.NORMAL
                configHoverColor = CONFIG.COLORS.NORMAL.BORDER.HOVER
                configClickedColor = CONFIG.COLORS.NORMAL.BORDER.CLICKED
            end
            
            local hoverColor, clickedColor = COLOR_UTILS.getDerivedColors(baseColor, configBaseColor, configHoverColor, configClickedColor)
            
            -- Set hover and active colors in the custom_color structure
            if not targetButton.custom_color.hover then
                targetButton.custom_color.hover = {}
            end
            if not targetButton.custom_color.active then
                targetButton.custom_color.active = {}
            end
            
            targetButton.custom_color.hover[color_type] = hoverColor
            targetButton.custom_color.active[color_type] = clickedColor
        end

        -- Apply linked colors based on global settings
        local shouldApplyBgBorderLink = 
            (color_type == "background" or color_type == "border") and CONFIG.COLOR_SETTINGS.LINK_BG_BORDER
        local shouldApplyTextIconLink = 
            (color_type == "text" or color_type == "icon") and CONFIG.COLOR_SETTINGS.LINK_TEXT_ICON

        if shouldApplyBgBorderLink then
            local linked_key = color_type == "background" and "border" or "background"
            if not targetButton.custom_color[linked_key] then
                targetButton.custom_color[linked_key] = {}
            end
            targetButton.custom_color[linked_key].normal = baseColor
            
            -- Also update hover/active colors for the linked type
            if color_type == "background" or color_type == "border" then
                local config_key = linked_key == "background" and "BG" or "BORDER"
                local configBaseColor = CONFIG.COLORS.NORMAL[config_key].NORMAL
                local configHoverColor = CONFIG.COLORS.NORMAL[config_key].HOVER
                local configClickedColor = CONFIG.COLORS.NORMAL[config_key].CLICKED
                
                local hoverColor, clickedColor = COLOR_UTILS.getDerivedColors(baseColor, configBaseColor, configHoverColor, configClickedColor)
                
                if not targetButton.custom_color.hover then
                    targetButton.custom_color.hover = {}
                end
                if not targetButton.custom_color.active then
                    targetButton.custom_color.active = {}
                end
                
                targetButton.custom_color.hover[linked_key] = hoverColor
                targetButton.custom_color.active[linked_key] = clickedColor
            end
        end
        
        if shouldApplyTextIconLink then
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

    -- Handle border offset picker specially
    if colorType == "border_offset" then
        self:renderBorderOffsetPicker(ctx, button)
        return
    end

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
    end

    local flags =
        reaper.ImGui_ColorEditFlags_AlphaBar() | reaper.ImGui_ColorEditFlags_AlphaPreview() |
        reaper.ImGui_ColorEditFlags_NoInputs() |
        reaper.ImGui_ColorEditFlags_PickerHueBar() |
        reaper.ImGui_ColorEditFlags_DisplayRGB() |
        reaper.ImGui_ColorEditFlags_DisplayHex()

    -- Global color settings are now managed in the main color menu

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

function ButtonColorEditor:renderBorderOffsetPicker(ctx, button)
    -- Initialize offset state if needed
    if not self.border_offset_state then
        self.border_offset_state = {
            saturation_offset = button.border_offset.saturation,
            value_offset = button.border_offset.value
        }
    end
    
    -- Get the background color to show preview
    local bg_color = CONFIG.COLORS.NORMAL.BG.NORMAL
    if button.custom_color and button.custom_color.background and button.custom_color.background.normal then
        bg_color = button.custom_color.background.normal
    end
    
    
    -- Saturation offset slider
    reaper.ImGui_Text(ctx, "Saturation Offset:")
    local sat_changed, new_sat = reaper.ImGui_SliderDouble(ctx, "##sat_offset", self.border_offset_state.saturation_offset, -1.0, 1.0, "%.2f")
    if sat_changed then
        self.border_offset_state.saturation_offset = new_sat
        self:updateBorderOffset(button)
    end
    
    -- Value offset slider
    reaper.ImGui_Text(ctx, "Value Offset:")
    local val_changed, new_val = reaper.ImGui_SliderDouble(ctx, "##val_offset", self.border_offset_state.value_offset, -1.0, 1.0, "%.2f")
    if val_changed then
        self.border_offset_state.value_offset = new_val
        self:updateBorderOffset(button)
    end
    
    reaper.ImGui_Separator(ctx)
    
    -- Reset button
    if reaper.ImGui_Button(ctx, "Reset to Default", 120, 0) then
        self.border_offset_state.saturation_offset = 0.0
        self.border_offset_state.value_offset = 0.0
        self:updateBorderOffset(button)
    end
end

function ButtonColorEditor:updateBorderOffset(button)
    -- Get target buttons based on global setting
    local targetButtons = {button}
    if CONFIG.COLOR_SETTINGS.APPLY_TO_GROUP and button.parent_group then
        targetButtons = button.parent_group.buttons
    end
    
    -- Update border offset for all target buttons
    for _, targetButton in ipairs(targetButtons) do
        targetButton.border_offset.saturation = self.border_offset_state.saturation_offset
        targetButton.border_offset.value = self.border_offset_state.value_offset
        
        -- Clear cache to force color recalculation
        targetButton:clearCache()
    end
    
    -- Save changes
    CONFIG_MANAGER:saveToolbarConfig(button.parent_toolbar)
end

function ButtonColorEditor:cleanup()
    self.color_picker_state = {
        clicked_button = nil,
        current_color = 0,
        color_type = "background"
    }
end

return ButtonColorEditor.new()
