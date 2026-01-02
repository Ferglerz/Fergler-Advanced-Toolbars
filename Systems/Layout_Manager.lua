-- Layout/Layout_Manager.lua

local LayoutManager = {}
LayoutManager.__index = LayoutManager

function LayoutManager.new()
    local self = setmetatable({}, LayoutManager)
    
    -- Cache for toolbar layouts
    self.toolbar_layouts = {}
    
    -- Flags to track when recalculation is needed
    self.config_changed = false
    self.force_recalculate = false
    
    -- Window dimension cache
    self.last_window_width = 0
    self.last_window_height = 0
    self.last_orientation_vertical = false
    
    return self
end

function LayoutManager:getToolbarLayout(toolbar_id, toolbar)
    -- Get current window dimensions
    local window_width = 0
    local window_height = 0
    
    if self.ctx then
        window_width = reaper.ImGui_GetWindowWidth(self.ctx)
        window_height = reaper.ImGui_GetWindowHeight(self.ctx)
    end

    local is_vertical = window_width > 0 and window_height > 0 and window_width < window_height
    self.is_vertical = is_vertical
    
    -- Create cache key that includes window dimensions (NO SCROLL POSITION)
    local cache_key = toolbar_id .. "_" .. window_width .. "x" .. window_height .. (is_vertical and "_v" or "_h")
    
    -- Check if layout needs to be recalculated
    local layout = self.toolbar_layouts[cache_key]
    
    -- Only recalculate when necessary
    if not layout or 
       self.force_recalculate or
       window_width ~= self.last_window_width or 
       window_height ~= self.last_window_height or
       self.last_orientation_vertical ~= is_vertical or
       self:needsRecalculation(toolbar) then
        
        -- Update cached values
        self.last_window_width = window_width
        self.last_window_height = window_height
        self.last_orientation_vertical = is_vertical
        
        -- Calculate the layout and store it
        layout = self:calculateToolbarLayout(toolbar)
        self.toolbar_layouts[cache_key] = layout
    end
    
    -- Add scroll-adjusted positions to the cached layout (these change frequently)
    self:addScrollAdjustedPositions(layout)
    
    return layout
end

function LayoutManager:ensureTextCache(button)
    -- Ensure button has cache table
    if not button.cache then
        button.cache = {}
    end
    
    -- Ensure text cache exists and return it
    if not button.cache.text then
        button.cache.text = {}
    end
    
    return button.cache.text
end

function LayoutManager:needsRecalculation(toolbar)
    -- Check if any config parameters that affect layout have changed
    if self.config_changed then
        return true
    end
    
    -- Check if any buttons need layout recalculation
    for _, button in ipairs(toolbar.buttons) do
        if button.layout_dirty then
            return true
        end
    end
    
    -- Check if any groups have invalidated caches
    for _, group in ipairs(toolbar.groups) do
        if not group:getDimensions() then
            return true
        end
    end
    
    return false
end

function LayoutManager:calculateToolbarLayout(toolbar)
    local layout = {
        width = 0,
        height = CONFIG.SIZES.HEIGHT, -- Base height
        groups = {},
        split_point = nil,
        right_width = 0,
        is_vertical = self.is_vertical,
        padding_x = 0,
        padding_y = 0
    }
    
    -- Find split point if needed (only relevant for horizontal layout)
    if not self.is_vertical then
        for i, group in ipairs(toolbar.groups) do
            if group.is_split_point then
                layout.split_point = i
                break
            end
        end
    end
    
    -- Calculate each group's layout
    -- Use PADDING for margins (left/right, and top in vertical mode)
    local left_margin, right_margin
    if self.is_vertical then
        -- In vertical mode, use padding for both left/right and top
        left_margin = CONFIG.SIZES.PADDING
        right_margin = CONFIG.SIZES.PADDING
    else
        left_margin = CONFIG.SIZES.PADDING
        right_margin = 0
    end
    local current_x = left_margin
    local current_y = left_margin
    local max_height = CONFIG.SIZES.HEIGHT
    local max_width = 0
    local available_width = math.max((self.last_window_width or 0) - left_margin - right_margin, CONFIG.SIZES.MIN_WIDTH)

    layout.padding_x = left_margin
    layout.padding_y = left_margin
    
    for i, group in ipairs(toolbar.groups) do
        local cached_dims = group:getDimensions()
        local group_layout
        
        -- Determine if group needs recalculation
        local needs_recalc = not cached_dims
        if not needs_recalc then
            for _, button in ipairs(group.buttons) do
                if button.layout_dirty then
                    needs_recalc = true
                    break
                end
            end
        end
        if not needs_recalc and cached_dims then
            if cached_dims.is_vertical ~= self.is_vertical then
                needs_recalc = true
            elseif self.is_vertical and cached_dims.available_width ~= available_width then
                needs_recalc = true
            end
        end
        
        if not needs_recalc then
            -- Use cached dimensions but recompute button positions for accuracy
            group_layout = {
                x = current_x,
                y = self.is_vertical and current_y or 0,
                width = cached_dims.width,
                height = cached_dims.height,
                buttons = {},
                label_height = cached_dims.label_height,
                content_height = cached_dims.content_height,
                is_vertical = self.is_vertical
            }
            
            local button_primary = 0
            for j, button in ipairs(group.buttons) do
                local button_width, extra_padding = self:calculateButtonWidth(self.ctx, button)
                local button_height = CONFIG.SIZES.HEIGHT
                
                -- For separators in vertical mode, use separator size for height
                if self.is_vertical and button:isSeparator() then
                    button_height = button.cache.layout and button.cache.layout.height or CONFIG.SIZES.SEPARATOR_SIZE
                end
                
                if self.is_vertical then
                    -- available_width already accounts for both left and right margins, so don't subtract again
                    button_width = math.max(available_width, button_width)
                end
                button.cached_width = {
                    total = button_width,
                    extra_padding = extra_padding
                }
                
                local button_layout = {
                    x = self.is_vertical and 0 or button_primary,
                    y = self.is_vertical and button_primary or 0,
                    width = button_width,
                    height = button_height,
                    is_vertical = self.is_vertical
                }
                
                table.insert(group_layout.buttons, button_layout)
                if self.is_vertical then
                    button_primary = button_primary + button_height + (j < #group.buttons and CONFIG.SIZES.SPACING or 0)
                else
                    button_primary = button_primary + button_width + (j < #group.buttons and CONFIG.SIZES.SPACING or 0)
                end
            end
        else
            -- Calculate group layout
            group_layout = self:calculateGroupLayout(group, self.is_vertical and available_width or nil, self.is_vertical, self.is_vertical and right_margin or 0)
        end
        
        -- Position the group
        group_layout.x = current_x
        group_layout.y = self.is_vertical and current_y or 0
        
        -- Track maximum extents
        max_height = math.max(max_height, group_layout.height)
        max_width = math.max(max_width, group_layout.x + group_layout.width)
        
        -- Add to layout
        table.insert(layout.groups, group_layout)
        
        -- Update position for next group
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
        
        -- In vertical mode, add extra spacing after groups with labels
        if self.is_vertical then
            local group_has_label = CONFIG.UI.USE_GROUP_LABELS and group.group_label and group.group_label.text and #group.group_label.text > 0
            if group_has_label then
                spacing = spacing + 6
            end
            current_y = current_y + group_layout.height + (i < #toolbar.groups and spacing or 0)
        else
            current_x = current_x + group_layout.width + spacing
        end
    end
    
    if self.is_vertical then
        -- For vertical layout, height is cumulative with padding
        layout.height = current_y
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
    
    -- Adjust layout for split point if needed
    if layout.split_point and not self.is_vertical then
        self:adjustLayoutForSplit(layout)
    end
    
    -- Don't add scroll positions here - they'll be calculated separately when needed
    return layout
end

-- NEW: Add scroll-adjusted positions alongside raw positions
function LayoutManager:addScrollAdjustedPositions(layout)
    if not self.ctx then
        return
    end
    
    local scroll_x = reaper.ImGui_GetScrollX(self.ctx)
    local scroll_y = reaper.ImGui_GetScrollY(self.ctx)
    
    -- Add scroll-adjusted positions to all group layouts
    for _, group_layout in ipairs(layout.groups) do
        group_layout.scroll_x = group_layout.x - scroll_x
        group_layout.scroll_y = group_layout.y - scroll_y
        
        -- Add scroll-adjusted positions to all button layouts within groups
        for _, button_layout in ipairs(group_layout.buttons) do
            button_layout.scroll_x = (group_layout.x + (button_layout.x or 0)) - scroll_x
            button_layout.scroll_y = (group_layout.y + (button_layout.y or 0)) - scroll_y
        end
    end
end

function LayoutManager:calculateButtonWidth(ctx, button)
    -- Initialize layout cache if needed
    if not button.cache.layout then
        button.cache.layout = {}
    end
    
    -- For separators, check if cache is still valid (orientation and separator size must match)
    if button:isSeparator() then
        local cached_vertical = button.cache.layout.is_vertical
        local cached_separator_size = button.cache.layout.separator_size
        local current_separator_size = CONFIG.SIZES.SEPARATOR_SIZE
        
        -- Invalidate cache if orientation changed or separator size changed
        if cached_vertical ~= self.is_vertical or cached_separator_size ~= current_separator_size then
            button.cache.layout.width = nil
            button.cache.layout.height = nil
            button.cache.layout.is_vertical = nil
            button.cache.layout.separator_size = nil
        end
    end
    
    -- Check if width is already cached (only if not a separator or cache is valid)
    if button.cache.layout.width and not (button:isSeparator() and (button.cache.layout.is_vertical ~= self.is_vertical or button.cache.layout.separator_size ~= CONFIG.SIZES.SEPARATOR_SIZE)) then
        return button.cache.layout.width, button.cache.layout.extra_padding
    end
    
    -- Special handling for separator buttons
    if button:isSeparator() then
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
        
        local extra_padding = 0
        if button.is_section_end or button.is_alone then
            extra_padding = math.floor((CONFIG.SIZES.ROUNDING - 8) / 4)
        end
        
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
    
    -- Check if button has a widget with a width specified
    if button.widget and button.widget.width then
        local extra_padding = 0
        if button.is_section_end or button.is_alone then
            extra_padding = math.floor((CONFIG.SIZES.ROUNDING - 8) / 4)
        end
        
        -- Cache the calculated width with widget width
        button.cache.layout.width = button.widget.width + extra_padding
        button.cache.layout.extra_padding = extra_padding
        button.cache.layout.height = CONFIG.SIZES.HEIGHT
        
        return button.cache.layout.width, button.cache.layout.extra_padding
    end

    -- Initialize text cache and calculate width if needed
    local text_cache = self:ensureTextCache(button)
    
    if text_cache.width == nil then
        text_cache.width = (not (button.hide_label or CONFIG.UI.HIDE_ALL_LABELS)) 
            and C.ButtonContent:calculateTextWidth(ctx, button.display_text) or 0
    end

    -- Get icon width from cache if available
    local icon_width = 0
    if button.icon_char and button.icon_font then
        -- Calculate icon width from font size for built-in icons
        -- Get the icon font and measure the character
        if not button.cache.icon_font or button.cache.icon_font.path ~= button.icon_font then
            button.cache.icon_font = {
                path = button.icon_font,
                font = C.ButtonContent:loadIconFont(button.icon_font)
            }
        end
        local icon_font = button.cache.icon_font.font
        if icon_font then
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

    local total_width = 0
    if icon_width > 0 and text_cache.width > 0 then
        total_width = math.max(CONFIG.SIZES.MIN_WIDTH, icon_width + CONFIG.ICON_FONT.PADDING + text_cache.width)
    elseif icon_width > 0 then
        total_width = math.max(CONFIG.SIZES.MIN_WIDTH, icon_width)
    else
        total_width = math.max(CONFIG.SIZES.MIN_WIDTH, text_cache.width)
    end

    local extra_padding = 0
    if button.is_section_end or button.is_alone then
        extra_padding = math.floor((CONFIG.SIZES.ROUNDING - 8) / 4)
    end

    -- Cache the calculated width
    button.cache.layout.width = total_width + (CONFIG.ICON_FONT.PADDING * 2) + extra_padding
    button.cache.layout.extra_padding = extra_padding
    button.cache.layout.height = CONFIG.SIZES.HEIGHT

    return button.cache.layout.width, button.cache.layout.extra_padding
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
        local button_height = CONFIG.SIZES.HEIGHT
        
        -- For separators in vertical mode, use separator size for height
        if vertical_mode and button:isSeparator() then
            button_height = button.cache.layout and button.cache.layout.height or CONFIG.SIZES.SEPARATOR_SIZE
        end
        
        -- For separators in horizontal mode, use separator_size for width (don't override with forced_button_width)
        if not vertical_mode and button:isSeparator() then
            button_width = button.cache.layout and button.cache.layout.width or CONFIG.SIZES.SEPARATOR_SIZE
        elseif forced_button_width then
            button_width = math.max(forced_button_width, CONFIG.SIZES.MIN_WIDTH)
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
            group_layout.height = math.max(group_layout.content_height, CONFIG.SIZES.HEIGHT)
        else
            group_layout.content_height = CONFIG.SIZES.HEIGHT
            group_layout.width = current_primary - (CONFIG.SIZES.SPACING > 0 and CONFIG.SIZES.SPACING or 0)
            group_layout.height = CONFIG.SIZES.HEIGHT
        end
    end
    
    -- Calculate label height if needed
    if CONFIG.UI.USE_GROUP_LABELS and group.group_label and group.group_label.text and #group.group_label.text > 0 then
        group_layout.label_height = 20  -- Approximate, will be calculated more precisely during rendering
        group_layout.height = group_layout.height + group_layout.label_height
    end
    
    -- Cache the calculated dimensions
    group:cacheDimensions(
        group_layout.width,
        group_layout.height,
        vertical_mode,
        forced_button_width,
        group_layout.label_height,
        group_layout.content_height
    )
    
    return group_layout
end

function LayoutManager:adjustLayoutForSplit(layout)
    -- Calculate total width of right-aligned groups
    local right_width = 0
    for i = layout.split_point, #layout.groups do
        right_width = right_width + layout.groups[i].width
        -- Add spacing between groups (separators are now part of groups, so this is simpler)
        if i < #layout.groups then
            right_width = right_width + CONFIG.SIZES.SPACING
        end
    end
    
    -- Add some extra padding
    right_width = right_width + CONFIG.SIZES.SPACING
    
    -- Store for renderer to use
    layout.right_width = right_width
end

function LayoutManager:invalidateCache()
    self.force_recalculate = true
end

function LayoutManager:configChanged()
    self.config_changed = true
end

function LayoutManager:endFrame()
    -- Reset flags at the end of frame
    self.force_recalculate = false
    self.config_changed = false
end

function LayoutManager:setContext(ctx)
    self.ctx = ctx
end

return LayoutManager