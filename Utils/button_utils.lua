-- Utils/button_utils.lua
-- Utility functions for button property checks and common operations

local ButtonUtils = {}

-- Check if button has an icon (either character or path)
function ButtonUtils.hasIcon(button)
    return button and (button.icon_char or button.icon_path)
end

-- Check if button has a widget
function ButtonUtils.hasWidget(button)
    return button and button.widget ~= nil
end

-- Check if button has a widget with a width specified (fixed or computed per frame)
function ButtonUtils.hasWidgetWithWidth(button)
    local w = button and button.widget
    return w and (w.width ~= nil or w.getLayoutWidth ~= nil)
end

-- Check if button widget is a slider
function ButtonUtils.isWidgetSlider(button)
    return button and button.widget and button.widget.type == "slider"
end

function ButtonUtils.isWidgetDropdown(button)
    return button and button.widget and button.widget.type == "dropdown"
end

-- Check if button widget has a name
function ButtonUtils.hasWidgetName(button)
    return button and button.widget and button.widget.name
end

-- Check if button widget has a description
function ButtonUtils.hasWidgetDescription(button)
    return button and button.widget and button.widget.description and button.widget.description ~= ""
end

-- Get separator height from cache or default
function ButtonUtils.getSeparatorHeight(button, is_vertical)
    if not button then
        return CONFIG.SIZES.SEPARATOR_SIZE
    end
    
    if is_vertical then
        return (button.cache and button.cache.layout and button.cache.layout.height) or CONFIG.SIZES.SEPARATOR_SIZE
    else
        return CONFIG.SIZES.HEIGHT
    end
end

-- Get extra padding from cached width
function ButtonUtils.getExtraPadding(button)
    if not button then
        return 0
    end
    return (button.cached_width and button.cached_width.extra_padding) or 0
end

-- Check if button should display text
function ButtonUtils.shouldDisplayText(button)
    if not button then
        return false
    end
    return not button.hide_label and 
           button.display_text and 
           button.display_text ~= "" and 
           button.display_text ~= "SEPARATOR"
end

-- Check if text should be shown (accounting for global hide setting)
function ButtonUtils.shouldShowText(button)
    if not button then
        return false
    end
    return not (button.hide_label or CONFIG.UI.HIDE_ALL_LABELS)
end

-- Check if button is first in group
function ButtonUtils.isFirstButtonInGroup(button)
    if not button or not button.parent_group then
        return false
    end
    return button.parent_group.buttons[1] == button
end

-- Check if color has alpha (is not transparent)
function ButtonUtils.hasAlpha(color)
    return color and (color & 0xFF) > 0
end

-- Check if group has valid label
function ButtonUtils.hasValidGroupLabel(group)
    return CONFIG.UI.USE_GROUP_LABELS and 
           group and 
           group.group_label and 
           group.group_label.text and 
           #group.group_label.text > 0
end

-- Check if should skip separator in vertical mode with label
function ButtonUtils.shouldSkipSeparatorInVerticalMode(button, is_vertical, has_visible_label)
    return is_vertical and 
           has_visible_label and 
           button:isSeparator() and 
           button.is_section_end
end

-- Check if can start drag operation
function ButtonUtils.canStartDrag(drag_cache, mouse_dragging)
    return drag_cache and 
           drag_cache.mouse_down_on_button and 
           mouse_dragging and 
           not drag_cache.was_dragging_last_frame and 
           not C.DragDropManager:isDragging()
end

-- Check if can start separator drag
function ButtonUtils.canStartSeparatorDrag(drag_cache, mouse_dragging, current_time)
    if not drag_cache or not drag_cache.mouse_down_on_button then
        return false
    end
    
    if C.DragDropManager:isDragging() or drag_cache.was_dragging_last_frame then
        return false
    end
    
    -- Start drag immediately for separators (no delay) or after minimal movement
    return mouse_dragging or 
           (drag_cache.drag_start_time and current_time - drag_cache.drag_start_time > 0.05)
end

-- Get group label text safely
function ButtonUtils.getGroupLabelText(group)
    if not group or not group.group_label then
        return ""
    end
    return group.group_label.text or ""
end

-- Check if group has separator
function ButtonUtils.groupHasSeparator(group)
    if not group or not group.buttons then
        return false
    end
    
    for _, button in ipairs(group.buttons) do
        if button:isSeparator() then
            return true
        end
    end
    
    return false
end

-- Group-local layout for drag-drop ghost (relative x/y within group, same space as button_layout.*)
function ButtonUtils.computeDragGhostGroupLayout(source_button, target_button_layout, toolbar_layout)
    local spacing = CONFIG.SIZES.SPACING or 0
    local is_vert = toolbar_layout.is_vertical
    local drop_after = C.DragDropManager.drop_position == "after"
    local gw, gh

    if source_button:isSeparator() then
        if is_vert then
            gw = target_button_layout.width
            gh = (source_button.cache.layout and source_button.cache.layout.height) or CONFIG.SIZES.SEPARATOR_SIZE
        else
            gw = (source_button.cache.layout and source_button.cache.layout.width) or CONFIG.SIZES.SEPARATOR_SIZE
            gh = CONFIG.SIZES.HEIGHT
        end
    else
        gw = (source_button.cached_width and source_button.cached_width.total) or CONFIG.SIZES.MIN_WIDTH
        gh = CONFIG.SIZES.HEIGHT
        if is_vert then
            gw = target_button_layout.width
        end
    end

    local gx, gy
    if is_vert then
        gx = target_button_layout.x
        if drop_after then
            gy = target_button_layout.y + target_button_layout.height + spacing
        else
            gy = target_button_layout.y - gh - spacing
        end
    else
        gy = target_button_layout.y
        if drop_after then
            gx = target_button_layout.x + target_button_layout.width + spacing
        else
            gx = target_button_layout.x - gw - spacing
        end
    end

    return { x = gx, y = gy, width = gw, height = gh, is_vertical = is_vert }
end

return ButtonUtils

