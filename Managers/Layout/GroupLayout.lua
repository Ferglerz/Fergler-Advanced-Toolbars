local widgetTitle = require("Utils.Widget.widget_title")

return function(LayoutManager)
function LayoutManager:applyWidgetTitleLayout(group_layout, group)
    if not self.ctx or not group_layout or not group_layout.buttons or not group then
        return
    end
    local vertical_mode = self.is_vertical == true
    local spacing = CONFIG.SIZES.SPACING or 0

    if BUTTON_UTILS.shouldShowGroupLabelRow(self._layout_editing_mode, group) then
        group_layout.label_height = group_layout.label_height or 24
    end
    local label_h = group_layout.label_height or 0

    for j, button_layout in ipairs(group_layout.buttons) do
        local button = group.buttons[j]
        if not button then
            goto continue_btn
        end
        self:measureButtonStrip(button, button_layout, vertical_mode)
        ::continue_btn::
    end

    if vertical_mode then
        group_layout.widget_title_band = nil
        local button_primary = 0
        for j, bl in ipairs(group_layout.buttons) do
            bl.x = 0
            bl.y = button_primary
            button_primary = button_primary + bl.height + (j < #group_layout.buttons and spacing or 0)
        end
        local used_spacing = (#group_layout.buttons > 1) and spacing or 0
        if #group_layout.buttons > 0 then
            group_layout.content_height = math.max(button_primary, CONFIG.SIZES.HEIGHT)
        else
            group_layout.content_height = 0
        end
        group_layout.height = group_layout.content_height + label_h
    else
        local band = 0
        for _, bl in ipairs(group_layout.buttons) do
            band = math.max(band, bl.title_height or 0)
        end
        group_layout.widget_title_band = band > 0 and band or nil
        local max_btn_h = CONFIG.SIZES.HEIGHT
        local button_primary = 0
        for j, bl in ipairs(group_layout.buttons) do
            if bl.height and bl.height > max_btn_h then
                max_btn_h = bl.height
            end
            bl.x = button_primary
            bl.y = band
            button_primary = button_primary + (bl.width or 0) + (j < #group_layout.buttons and spacing or 0)
        end
        local used_spacing = (#group_layout.buttons > 1) and spacing or 0
        if #group_layout.buttons > 0 then
            group_layout.width = math.max(button_primary, CONFIG.SIZES.MIN_WIDTH)
        end
        group_layout.content_height = max_btn_h
        group_layout.height = max_btn_h + band + label_h
    end
end

-- Process a single group layout
function LayoutManager:processGroupLayout(group, current_x, current_y, available_width, right_margin)
    local group_layout = self:calculateGroupLayout(
        group,
        self.is_vertical and available_width or nil,
        self.is_vertical,
        self.is_vertical and right_margin or 0
    )

    self:applyWidgetTitleLayout(group_layout, group)

    -- Position the group
    group_layout.x = current_x
    group_layout.y = self.is_vertical and current_y or 0
    
    return group_layout
end

--- Re-stack vertical group y from final heights (after widget title pass).
function LayoutManager:reflowVerticalGroupPositions(layout, toolbar, start_y)
    if not layout or not layout.is_vertical or not layout.groups or not toolbar or not toolbar.groups then
        return start_y or 0
    end
    local cy = start_y or layout.padding_y or 0
    for i, gl in ipairs(layout.groups) do
        gl.y = cy
        local spacing = self:calculateGroupSpacing(toolbar.groups[i], i, #layout.groups)
        cy = cy + (gl.height or 0) + (i < #layout.groups and spacing or 0)
    end
    return cy
end

--- Persist final group dimensions after reflow (layout pass owns width/height/y).
function LayoutManager:refreshToolbarGroupCaches(layout, toolbar, available_width)
    if not layout or not layout.groups or not toolbar or not toolbar.groups then
        return
    end
    for i, gl in ipairs(layout.groups) do
        local group = toolbar.groups[i]
        if group then
            group:cacheDimensions(
                gl.width,
                gl.height,
                layout.is_vertical,
                layout.is_vertical and available_width or nil,
                gl.label_height,
                gl.content_height
            )
        end
    end
end

function LayoutManager:reflowHorizontalGroupPositions(layout, toolbar, start_x)
    if not layout or layout.is_vertical or not layout.groups or not toolbar or not toolbar.groups then
        return start_x or 0
    end
    local cx = start_x or layout.padding_x or 0
    for i, gl in ipairs(layout.groups) do
        gl.x = cx
        local spacing = self:calculateGroupSpacing(toolbar.groups[i], i, #layout.groups)
        cx = cx + (gl.width or 0) + (i < #layout.groups and spacing or 0)
    end
    return cx
end

-- Calculate spacing between groups
function LayoutManager:calculateGroupSpacing(group, i, total_groups)
    local spacing = CONFIG.SIZES.SPACING
    
    -- Add extra spacing if the current group contains a separator
    local group_has_separator = false
    for _, button in ipairs(group.buttons) do
        if button:isSeparator() then
            group_has_separator = true
            break
        end
    end
    
    if group_has_separator then
        spacing = spacing + CONFIG.SIZES.SPACING
    end
    
    -- In vertical mode, add extra spacing after groups with labels (including edit-mode placeholder row)
    if self.is_vertical then
        if BUTTON_UTILS.shouldShowGroupLabelRow(self._layout_editing_mode, group) then
            spacing = spacing + 6
        end
    end
    
    return spacing
end

-- Finalize layout dimensions (width/height)
function LayoutManager:calculateGroupLayout(group, forced_button_width, vertical_mode, right_margin)
    right_margin = right_margin or 0
    local group_layout = {
        width = 0,
        height = CONFIG.SIZES.HEIGHT,
        buttons = {},
        label_height = 0,
        content_height = 0,
        is_vertical = vertical_mode
    }
    
    -- Calculate button layouts and total width/height
    local current_primary = 0
    local max_width = 0
    local spacing = CONFIG.SIZES.SPACING
    
    for i, button in ipairs(group.buttons) do
        -- Calculate button width/height
        local button_width, extra_padding = self:calculateButtonWidth(self.ctx, button)
        local button_height = self:buttonBodyHeight(button, vertical_mode)
        
        -- For separators in horizontal mode, use separator_size for width (don't override with forced_button_width)
        if not vertical_mode and button:isSeparator() then
            button_width = button.cache.layout and button.cache.layout.width or CONFIG.SIZES.SEPARATOR_SIZE
        elseif forced_button_width then
            -- In vertical mode, expand buttons to fill forced_button_width (available_width), but cap at forced_button_width
            -- But ensure minimum width is respected
            button_width = math.min(forced_button_width, math.max(forced_button_width, math.max(button_width, CONFIG.SIZES.MIN_WIDTH)))
            local forced_h = self:recomputeWidgetHeightForFinalWidth(self.ctx, button, button_width, extra_padding, vertical_mode)
            if forced_h then
                button_height = forced_h
            end
        end
        
        local button_layout = {
            x = vertical_mode and 0 or current_primary,
            y = vertical_mode and current_primary or 0,
            width = button_width,
            height = button_height,
            is_vertical = vertical_mode
        }

        button.cached_width = {
            total = button_width,
            extra_padding = extra_padding
        }
        
        table.insert(group_layout.buttons, button_layout)
        
        if vertical_mode then
            current_primary = current_primary + button_height + (i < #group.buttons and spacing or 0)
            max_width = math.max(max_width, button_width)
        else
            current_primary = current_primary + button_width + (i < #group.buttons and spacing or 0)
            max_width = current_primary
        end
        
        -- Clear layout dirty flag after recalculation
        button.layout_dirty = false
    end
    
    if #group.buttons > 0 then
        if vertical_mode then
            local used_spacing = (#group.buttons > 1) and spacing or 0
            group_layout.content_height = current_primary - used_spacing
            group_layout.width = math.max(max_width, forced_button_width or CONFIG.SIZES.MIN_WIDTH)
            group_layout.height = group_layout.content_height
        else
            local max_btn_h = CONFIG.SIZES.HEIGHT
            for _, bl in ipairs(group_layout.buttons) do
                if bl.height and bl.height > max_btn_h then
                    max_btn_h = bl.height
                end
            end
            group_layout.content_height = max_btn_h
            -- Sum of button widths + internal spacing; only subtract trailing spacing when 2+ buttons
            -- (otherwise single-widget strips were w - SPACING and layout width lagged behind draw width).
            if #group.buttons > 1 and CONFIG.SIZES.SPACING > 0 then
                group_layout.width = current_primary - CONFIG.SIZES.SPACING
            else
                group_layout.width = current_primary
            end
            group_layout.height = max_btn_h
        end
    end
    
    -- Calculate label height if needed (real label or edit-mode GROUP row)
    if BUTTON_UTILS.shouldShowGroupLabelRow(self._layout_editing_mode, group) then
        group_layout.label_height = 24
    end
    
    return group_layout
end


end
