-- Utils/Core/button/identity.lua

local M = {}

function M.resolveActionCommandId(action_id)
    if type(action_id) == "string" and action_id:match("^_") then
        return reaper.NamedCommandLookup(action_id)
    end
    return tonumber(action_id)
end

function M.actionSupportsToggle(command_id)
    if not command_id or command_id <= 0 then
        return false
    end
    return reaper.GetToggleCommandState(command_id) >= 0
end

function M.hasIcon(button)
    return button and (button.icon_char or button.icon_path or button.reaper_icon_path or button.reaper_track_icon_path)
end

function M.hasWidget(button)
    return button and button.widget ~= nil
end

function M.isKnobWidget(widget)
    if not widget or widget.type ~= "slider" then
        return false
    end
    local style = widget.slider_style
    return style == "knob" or style == "simple_knob"
end

function M.customColorHasConcreteVisual(custom_color)
    if type(custom_color) ~= "table" then
        return false
    end
    local function slot(tab)
        return tab and tab.normal ~= nil
    end
    if slot(custom_color.background) or slot(custom_color.border) or slot(custom_color.text) or slot(custom_color.icon) then
        return true
    end
    local h = custom_color.hover
    if h and (h.background ~= nil or h.border ~= nil) then
        return true
    end
    local a = custom_color.active
    if a and (a.background ~= nil or a.border ~= nil) then
        return true
    end
    return false
end

function M.hasInheritedStyleSource(button)
    if not button then
        return false
    end
    if button.user_colors and type(button.user_colors) == "table" and next(button.user_colors) ~= nil then
        return true
    end
    return M.customColorHasConcreteVisual(button.custom_color)
end

function M.hasWidgetWithWidth(button)
    local w = button and button.widget
    return w and (w.width ~= nil or w.getLayoutWidth ~= nil)
end

function M.isWidgetSlider(button)
    return button and button.widget and button.widget.type == "slider"
end

function M.isWidgetDropdown(button)
    return button and button.widget and button.widget.type == "dropdown"
end

function M.isWidgetColourSwatch(button)
    return button and button.widget and button.widget.type == "colour_swatch"
end

function M.widgetUsesChipChrome(button)
    return button and button.widget and button.widget.chip_widget == true
end

function M.colorMouseKeyForButton(button, mouse_key)
    if M.widgetUsesChipChrome(button) then
        return "NORMAL"
    end
    return mouse_key
end

function M.hasWidgetName(button)
    return button and button.widget and button.widget.name
end

function M.hasWidgetDescription(button)
    return button and button.widget and button.widget.description and button.widget.description ~= ""
end

function M.shouldSuppressWidgetTooltip(button)
    return button and button.widget and button.widget.suppress_tooltip == true
end

function M.hasAlpha(color)
    return color and (color & 0xFF) > 0
end

return M
