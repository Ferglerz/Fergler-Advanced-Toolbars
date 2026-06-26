-- Managers/Layout_Math.lua
local widgetTitle = require("Utils.widget_title")

return function(LayoutManager)
function LayoutManager:calculateMargins()
    local pad = math.max(1, math.floor((CONFIG.SIZES.PADDING or 6) / 2))
    if self.is_vertical then
        return pad, pad
    else
        return pad, 0
    end
end

-- Sorted group indices marked as split anchors (segment starts). Last anchor = flush right (horizontal) or flush bottom (vertical).
function LayoutManager:collectSplitIndices(toolbar)
    local S = {}
    if not toolbar or not toolbar.groups then
        return S
    end
    for i, group in ipairs(toolbar.groups) do
        if (self.is_vertical and group.is_split_point_v) or (not self.is_vertical and group.is_split_point_h) then
            table.insert(S, i)
        end
    end
    table.sort(S)
    return S
end

function LayoutManager:computeSplitCenterOffsets(layout)
    layout.split_center_offset_x = 0
    layout.split_center_offset_y = 0
    local S = layout.split_indices
    if not S or #S < 2 then
        return
    end
    local g = layout.groups
    local mid_lo, mid_hi = S[1], S[#S] - 1
    if mid_hi < mid_lo or not g[mid_lo] or not g[mid_hi] then
        return
    end
    if not layout.is_vertical then
        local mid_w = (g[mid_hi].x or 0) + (g[mid_hi].width or 0) - (g[mid_lo].x or 0)
        local R_start = (self._imgui_window_width or 0) - (layout.right_width or 0)
        layout.split_center_offset_x = (R_start - g[mid_lo].x - mid_w) / 2
    else
        local mid_h = (g[mid_hi].y or 0) + (g[mid_hi].height or 0) - (g[mid_lo].y or 0)
        local B_start = (self._imgui_window_height or 0) - (layout.bottom_height or 0)
        layout.split_center_offset_y = (B_start - g[mid_lo].y - mid_h) / 2
    end
end

function LayoutManager:buttonBodyHeight(button, vertical_mode)
    local body_h = CONFIG.SIZES.HEIGHT
    if button.widget and button.cache.layout and button.cache.layout.height then
        body_h = button.cache.layout.height
    end
    if vertical_mode and button:isSeparator() then
        body_h = button.cache.layout and button.cache.layout.height or CONFIG.SIZES.SEPARATOR_SIZE
    end
    return body_h
end

--- Authoritative per-button width/height for group layout (no stale cache floor).
function LayoutManager:measureButtonStrip(button, button_layout, vertical_mode)
    if not button or not button_layout then
        return CONFIG.SIZES.HEIGHT, 0, nil
    end
    local pad = (button.cached_width and button.cached_width.extra_padding) or self:calculateExtraPadding(button)

    if not vertical_mode and button.widget and button.widget.getLayoutWidth then
        local ok, w = pcall(button.widget.getLayoutWidth, button.widget, self.ctx, vertical_mode)
        if ok and type(w) == "number" and w > 0 then
            button_layout.width = w + pad
            if button.cache and button.cache.layout then
                button.cache.layout.width = button_layout.width
                button.cache.layout.extra_padding = pad
            end
        end
    end

    local body_h = CONFIG.SIZES.HEIGHT
    if vertical_mode and button:isSeparator() then
        body_h = button.cache.layout and button.cache.layout.height or CONFIG.SIZES.SEPARATOR_SIZE
    elseif button.widget and button.widget.getLayoutHeight then
        local strip_w = math.max(1, button_layout.width or CONFIG.SIZES.MIN_WIDTH or 30)
        local ok, h = pcall(button.widget.getLayoutHeight, button.widget, self.ctx, strip_w, vertical_mode)
        if ok and type(h) == "number" and h > 0 then
            body_h = h
            if button.cache and button.cache.layout then
                button.cache.layout.height = h
            end
        end
    elseif button.widget and button.cache and button.cache.layout and button.cache.layout.height then
        body_h = button.cache.layout.height
    end

    local title_h, title_lines = 0, nil
    if button.widget then
        title_h, title_lines = widgetTitle.measure(self.ctx, button.widget, button_layout.width, vertical_mode)
    end
    if title_h > 0 then
        button_layout.title_height = title_h
        button_layout.title_lines = title_lines
    else
        button_layout.title_height = nil
        button_layout.title_lines = nil
    end

    if vertical_mode then
        button_layout.height = body_h + title_h
    else
        button_layout.height = body_h
    end

    return body_h, title_h, title_lines
end

--- Title strip on every group layout pass.
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
function LayoutManager:finalizeLayoutDimensions(layout, current_x, current_y, max_height, max_width, left_margin, right_margin, available_width)
    if self.is_vertical then
        -- For vertical layout, height is calculated dynamically from final group Y coordinates to include split shifts
        layout.height = left_margin
        for _, group_layout in ipairs(layout.groups) do
            local group_end = (group_layout.y or 0) + (group_layout.height or 0)
            layout.height = math.max(layout.height, group_end)
        end
        layout.width = math.max(max_width, available_width + left_margin + right_margin)
    else
        -- Set the total height to the maximum height needed
        layout.height = max_height
        
        -- Calculate total width
        for i, group_layout in ipairs(layout.groups) do
            local group_end = group_layout.x + group_layout.width
            layout.width = math.max(layout.width, group_end)
        end
    end
end

-- Main toolbar layout calculation (orchestration)
function LayoutManager:calculateToolbarLayout(toolbar)
    local layout = {
        width = 0,
        height = CONFIG.SIZES.HEIGHT, -- Base height
        groups = {},
        split_point = nil,
        split_indices = nil,
        split_center_offset_x = 0,
        split_center_offset_y = 0,
        right_width = 0,
        bottom_height = 0,
        is_vertical = self.is_vertical,
        padding_x = 0,
        padding_y = 0
    }

    local split_ix = self:collectSplitIndices(toolbar)
    if #split_ix >= 1 then
        layout.split_indices = split_ix
        layout.split_point = split_ix[#split_ix]
    else
        layout.split_point = nil
    end
    
    -- Calculate margins
    local left_margin, right_margin = self:calculateMargins()
    local current_x = left_margin
    local current_y = left_margin
    local max_height = CONFIG.SIZES.HEIGHT
    local max_width = 0
    local w_for_layout = (self.layout_width_override ~= nil) and self.layout_width_override or (self._imgui_window_width or 0)
    local available_width = math.max(w_for_layout - left_margin - right_margin, CONFIG.SIZES.MIN_WIDTH)

    layout.padding_x = left_margin
    layout.padding_y = left_margin
    
    -- Process each group
    for i, group in ipairs(toolbar.groups) do
        local group_layout = self:processGroupLayout(group, current_x, current_y, available_width, right_margin)
        
        -- Track maximum extents
        max_height = math.max(max_height, group_layout.height)
        max_width = math.max(max_width, group_layout.x + group_layout.width)
        
        -- Add to layout
        table.insert(layout.groups, group_layout)
        
        -- Calculate spacing and update position for next group
        local spacing = self:calculateGroupSpacing(group, i, #toolbar.groups)
        
        if self.is_vertical then
            current_y = current_y + group_layout.height + (i < #toolbar.groups and spacing or 0)
        else
            current_x = current_x + group_layout.width + spacing
        end
    end

    -- Horizontal mode: unify widget_title_band across ALL groups so every row member
    -- is pushed down by the tallest title band, not just per-group.
    if not self.is_vertical then
        local global_band = 0
        for _, gl in ipairs(layout.groups) do
            if gl.widget_title_band and gl.widget_title_band > global_band then
                global_band = gl.widget_title_band
            end
        end
        layout.widget_title_band = global_band > 0 and global_band or nil
        if global_band > 0 then
            for _, gl in ipairs(layout.groups) do
                local old_band = gl.widget_title_band or 0
                gl.widget_title_band = global_band
                -- Re-position buttons: shift all button y to the global band
                for _, bl in ipairs(gl.buttons) do
                    bl.y = global_band
                end
                -- Update group height to reflect the global band
                local label_h = gl.label_height or 0
                gl.height = (gl.content_height or CONFIG.SIZES.HEIGHT) + global_band + label_h
            end
            -- Recompute max_height with the updated group heights
            max_height = CONFIG.SIZES.HEIGHT
            for _, gl in ipairs(layout.groups) do
                max_height = math.max(max_height, gl.height)
            end
        end
        current_x = self:reflowHorizontalGroupPositions(layout, toolbar, left_margin)
        max_width = left_margin
        for _, gl in ipairs(layout.groups) do
            max_width = math.max(max_width, (gl.x or 0) + (gl.width or 0))
        end
    end

    if self.is_vertical then
        current_y = self:reflowVerticalGroupPositions(layout, toolbar, left_margin)
        max_height = CONFIG.SIZES.HEIGHT
        for _, gl in ipairs(layout.groups) do
            max_height = math.max(max_height, (gl.y or 0) + (gl.height or 0))
        end
    end

    layout.split_active = false
    if layout.split_point then
        self:adjustLayoutForSplit(layout)
        local win_w = self._imgui_window_width or 0
        local win_h = self._imgui_window_height or 0
        local gr = layout.groups[layout.split_point]
        if not self.is_vertical then
            layout.split_active = gr and win_w > 0 and (win_w - layout.right_width > gr.x) or false
            if layout.split_active then
                self:applySplitBridgeSeparatorOmit(layout, toolbar)
            end
        else
            layout.split_active = gr and win_h > 0 and (win_h - layout.bottom_height > gr.y) or false
            if layout.split_active then
                self:applySplitBridgeSeparatorOmit(layout, toolbar)
            end
        end
        if layout.split_active then
            self:computeSplitCenterOffsets(layout)
        end
    end


    self:finalizeLayoutDimensions(layout, current_x, current_y, max_height, max_width, left_margin, right_margin, available_width)
    self:refreshToolbarGroupCaches(layout, toolbar, available_width)

    return layout
end

-- Calculate extra padding for section end or alone buttons
function LayoutManager:calculateExtraPadding(button)
    if button.is_section_end or button.is_alone then
        return math.floor((CONFIG.SIZES.ROUNDING - 8) / 4)
    end
    return 0
end

-- Validate and invalidate separator cache if needed
function LayoutManager:validateSeparatorCache(button)
    if not button:isSeparator() or not button.cache.layout then
        return true
    end
    
    local cached_vertical = button.cache.layout.is_vertical
    local cached_separator_size = button.cache.layout.separator_size
    local current_separator_size = CONFIG.SIZES.SEPARATOR_SIZE
    
    -- Invalidate cache if orientation changed or separator size changed
    if cached_vertical ~= self.is_vertical or cached_separator_size ~= current_separator_size then
        button.cache.layout.width = nil
        button.cache.layout.height = nil
        button.cache.layout.is_vertical = nil
        button.cache.layout.separator_size = nil
        return false
    end
    
    return true
end

-- Calculate separator button width
function LayoutManager:calculateSeparatorWidth(button)
    -- Determine if we're in editing mode
    local editing_mode = false
    for _, controller_data in ipairs(_G.TOOLBAR_CONTROLLERS) do
        if controller_data.controller and controller_data.controller.button_editing_mode then
            editing_mode = true
            break
        end
    end
    
    -- Calculate separator size based on edit mode
    local separator_size = editing_mode and math.max(CONFIG.SIZES.SEPARATOR_SIZE, 20) or CONFIG.SIZES.SEPARATOR_SIZE
    local extra_padding = self:calculateExtraPadding(button)
    
    -- Cache the calculated width/height
    -- In vertical mode, separator size affects height; in horizontal, it affects width
    if self.is_vertical then
        -- In vertical mode, separator takes full width, size affects height
        button.cache.layout.width = CONFIG.SIZES.MIN_WIDTH  -- Will be overridden by available_width in group layout
        button.cache.layout.height = separator_size
    else
        -- In horizontal mode, separator size directly controls width
        button.cache.layout.width = separator_size + extra_padding
        button.cache.layout.height = CONFIG.SIZES.HEIGHT
    end
    button.cache.layout.extra_padding = extra_padding
    button.cache.layout.separator_size = separator_size  -- Store for reference
    button.cache.layout.is_vertical = self.is_vertical  -- Store orientation for cache validation

    return button.cache.layout.width, button.cache.layout.extra_padding
end

-- Calculate widget button width
function LayoutManager:calculateWidgetButtonWidth(ctx, button)
    local layout_cache = CACHE_UTILS.ensureButtonCacheSubtable(button, "layout")
    local extra_padding = self:calculateExtraPadding(button)
    local inner
    if button.widget.getLayoutWidth then
        local ok, w = pcall(button.widget.getLayoutWidth, button.widget, ctx, self.is_vertical)
        inner = ok and w or nil
    else
        inner = button.widget.width
    end

    inner = inner or button.widget.width or CONFIG.SIZES.MIN_WIDTH or 30
    if type(inner) ~= "number" or inner ~= inner then
        inner = CONFIG.SIZES.MIN_WIDTH or 30
    end

    local strip_w = inner
    if self.is_vertical then
        local w_for = self.layout_width_override or self._imgui_window_width or 0
        if w_for > 0 then
            local lm, rm = self:calculateMargins()
            strip_w = math.max(CONFIG.SIZES.MIN_WIDTH or 30, w_for - lm - rm)
        end
    end

    local inner_h = CONFIG.SIZES.HEIGHT
    if button.widget.getLayoutHeight then
        local ok, h = pcall(button.widget.getLayoutHeight, button.widget, ctx, strip_w, self.is_vertical)
        if ok and type(h) == "number" and h > 0 then
            inner_h = h
        end
    end

    if button.widget.slider_style == "simple_knob" then
        inner = inner + inner_h
    end

    button.cache.layout.width = inner + extra_padding
    button.cache.layout.extra_padding = extra_padding
    button.cache.layout.height = inner_h
    layout_cache.width = inner + extra_padding
    layout_cache.extra_padding = extra_padding
    layout_cache.height = inner_h

    return layout_cache.width, layout_cache.extra_padding
end

-- In vertical mode, buttons are stretched to forced width after base measurement.
-- Recompute dynamic widget height using that final width so render/layout stay in sync.
function LayoutManager:recomputeWidgetHeightForFinalWidth(ctx, button, final_button_width, extra_padding, is_vertical_mode)
    if not is_vertical_mode or not button or not button.widget or not button.widget.getLayoutHeight then
        return nil
    end
    local strip_w = math.max(1, final_button_width or CONFIG.SIZES.MIN_WIDTH or 30)
    local ok, h = pcall(button.widget.getLayoutHeight, button.widget, ctx, strip_w, true)
    if ok and type(h) == "number" and h > 0 then
        button.cache.layout.height = h
        return h
    end
    return nil
end

-- Get icon width from button
function LayoutManager:getIconWidth(ctx, button)
    local icon_width = 0
    
    if button.icon_char and button.icon_font then
        -- Calculate icon width from font size for built-in icons
        local resolved = C.ButtonContent:loadIconFont(button.icon_font)
        local ic = button.cache.icon_font
        if not ic or ic.path ~= button.icon_font or ic.font ~= resolved then
            CACHE_UTILS.ensureButtonCache(button)
            button.cache.icon_font = {
                path = button.icon_font,
                font = resolved
            }
        end
        local icon_font = button.cache.icon_font.font
        if icon_font and ensureIconFontAttachedToContext(ctx, icon_font) then
            -- Push the font with the current size and measure the character
            reaper.ImGui_PushFont(ctx, icon_font, CONFIG.ICON_FONT.SIZE)
            local char_width = reaper.ImGui_CalcTextSize(ctx, button.icon_char)
            reaper.ImGui_PopFont(ctx)
            icon_width = char_width
        end
    elseif button.icon_path then
        -- Ensure image icon is loaded and cached for width calculation
        C.IconManager:loadButtonIcon(button)
        if button.cache.icon and button.cache.icon.dimensions then
            icon_width = button.cache.icon.dimensions.width
        end
    elseif button.cache.icon and button.cache.icon.dimensions then
        icon_width = button.cache.icon.dimensions.width
    end
    
    return icon_width
end

-- Calculate regular button width (icon + text)
function LayoutManager:calculateRegularButtonWidth(ctx, button)
    -- Initialize text cache and calculate width if needed
    local text_cache = self:ensureTextCache(button)
    
    if text_cache.width == nil then
        text_cache.width = (not (button.hide_label or CONFIG.UI.HIDE_ALL_LABELS))
            and C.ButtonContent:calculateTextWidth(ctx, BUTTON_UTILS.getButtonLabelTextForRender(button)) or 0
    end

    -- Get icon width
    local icon_width = self:getIconWidth(ctx, button)

    -- Calculate total width
    local total_width = 0
    if icon_width > 0 and text_cache.width > 0 then
        total_width = math.max(CONFIG.SIZES.MIN_WIDTH, icon_width + CONFIG.ICON_FONT.PADDING + text_cache.width)
    elseif icon_width > 0 then
        total_width = math.max(CONFIG.SIZES.MIN_WIDTH, icon_width)
    else
        total_width = math.max(CONFIG.SIZES.MIN_WIDTH, text_cache.width)
    end

    local extra_padding = self:calculateExtraPadding(button)

    -- Cache the calculated width
    button.cache.layout.width = total_width + (CONFIG.ICON_FONT.PADDING * 2) + extra_padding
    button.cache.layout.extra_padding = extra_padding
    button.cache.layout.height = CONFIG.SIZES.HEIGHT

    return button.cache.layout.width, button.cache.layout.extra_padding
end

-- Main button width calculation (orchestration)
function LayoutManager:calculateButtonWidth(ctx, button)
    -- Initialize layout cache if needed
    CACHE_UTILS.ensureButtonCacheSubtable(button, "layout")
    
    -- For separators, validate cache
    if button:isSeparator() then
        self:validateSeparatorCache(button)
    end
    
    -- Dynamic widget width/height (e.g. text-sized dropdown, multi-row swatches) must not use a stale cache
    local dynamic_widget_w = button.widget and button.widget.getLayoutWidth
    local dynamic_widget_h = button.widget and button.widget.getLayoutHeight
    -- Check if width is already cached (only if not a separator or cache is valid)
    if button.cache.layout.width and not dynamic_widget_w and not dynamic_widget_h
        and not (button:isSeparator() and (button.cache.layout.is_vertical ~= self.is_vertical or button.cache.layout.separator_size ~= CONFIG.SIZES.SEPARATOR_SIZE)) then
        return button.cache.layout.width, button.cache.layout.extra_padding
    end
    
    -- Route to appropriate calculator
    if button:isSeparator() then
        return self:calculateSeparatorWidth(button)
    elseif BUTTON_UTILS.hasWidgetWithWidth(button) then
        return self:calculateWidgetButtonWidth(ctx, button)
    else
        return self:calculateRegularButtonWidth(ctx, button)
    end
end

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

function LayoutManager:adjustLayoutForSplit(layout)
    local sp = layout.split_point
    if not sp then
        return
    end
    if not layout.is_vertical then
        local right_width = 0
        for i = sp, #layout.groups do
            right_width = right_width + layout.groups[i].width
            if i < #layout.groups then
                right_width = right_width + CONFIG.SIZES.SPACING
            end
        end
        right_width = right_width + (layout.padding_x or CONFIG.SIZES.PADDING)
        layout.right_width = right_width
        layout.bottom_height = 0
    else
        local bottom_height = 0
        for i = sp, #layout.groups do
            bottom_height = bottom_height + layout.groups[i].height
            if i < #layout.groups then
                bottom_height = bottom_height + CONFIG.SIZES.SPACING
            end
        end
        bottom_height = bottom_height + (layout.padding_y or CONFIG.SIZES.PADDING)
        layout.bottom_height = bottom_height
        layout.right_width = 0
    end
end

-- When left/right split is active, the last group on the left ends with a separator that only
-- bridges to the right block; drop it from layout and drawing so it does not sit against the flex gap.
function LayoutManager:applySplitBridgeSeparatorOmit(layout, toolbar)
    local sp = layout.split_point
    if not sp or sp < 2 then
        return
    end
    local gi = sp - 1
    local group = toolbar.groups[gi]
    local gl = layout.groups[gi]
    if not group or not gl or not gl.buttons then
        return
    end
    local n = #group.buttons
    if n < 1 then
        return
    end
    if not group.buttons[n]:isSeparator() then
        return
    end
    local bl = gl.buttons[n]
    if not bl then
        return
    end
    local spacing = CONFIG.SIZES.SPACING or 0
    local is_vert = layout.is_vertical
    
    local delta = (is_vert and bl.height or bl.width) or 0
    if n > 1 then
        delta = delta + spacing
    end
    
    if is_vert then
        gl.height = math.max(0, (gl.height or 0) - delta)
        bl.height = 0
        for i = sp, #layout.groups do
            local g2 = layout.groups[i]
            g2.y = (g2.y or 0) - delta
        end
        local max_end = 0
        for _, g2 in ipairs(layout.groups) do
            max_end = math.max(max_end, (g2.y or 0) + (g2.height or 0))
        end
        layout.height = max_end
    else
        gl.width = math.max(0, (gl.width or 0) - delta)
        bl.width = 0
        for i = sp, #layout.groups do
            local g2 = layout.groups[i]
            g2.x = (g2.x or 0) - delta
        end
        local max_end = 0
        for _, g2 in ipairs(layout.groups) do
            max_end = math.max(max_end, (g2.x or 0) + (g2.width or 0))
        end
        layout.width = max_end
    end
end


end
