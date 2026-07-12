local widgetTitle = require("Utils.Widget.widget_title")

return function(LayoutManager)
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
        _G.CURRENT_HOST_BUTTON = button
        button.widget._host_button = button
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
function LayoutManager:calculateExtraPadding(button)
    if not button or button:isSeparator() then
        return 0
    end
    local has_rounding = (not CONFIG.UI.USE_GROUPING)
        or button.is_alone
        or button.is_visual_section_start
        or button.is_visual_section_end
        or button.is_section_start
        or button.is_section_end
    if has_rounding then
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
    _G.CURRENT_HOST_BUTTON = button
    if button.widget then
        button.widget._host_button = button
    end
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
        _G.CURRENT_HOST_BUTTON = button
        button.widget._host_button = button
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
    _G.CURRENT_HOST_BUTTON = button
    button.widget._host_button = button
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
    elseif button.icon_path or button.reaper_icon_path or button.reaper_track_icon_path then
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
    
    -- Check if width is already cached (only if not a separator/widget or cache is valid)
    if button.cache.layout.width and not button.widget
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


end
