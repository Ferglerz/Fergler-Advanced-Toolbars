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
    
    -- Create cache key that includes window dimensions (NO SCROLL POSITION)
    local cache_key = toolbar_id .. "_" .. window_width .. "x" .. window_height
    
    -- Check if layout needs to be recalculated
    local layout = self.toolbar_layouts[cache_key]
    
    -- Only recalculate when necessary
    if not layout or 
       self.force_recalculate or
       window_width ~= self.last_window_width or 
       window_height ~= self.last_window_height or
       self:needsRecalculation(toolbar) then
        
        -- Update cached values
        self.last_window_width = window_width
        self.last_window_height = window_height
        
        -- Calculate the layout and store it
        layout = self:calculateToolbarLayout(toolbar)
        self.toolbar_layouts[cache_key] = layout
    end
    
    -- Add scroll-adjusted positions to the cached layout (these change frequently)
    self:addScrollAdjustedPositions(layout)
    
    return layout
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
        right_width = 0
    }
    
    -- Find split point if needed
    for i, group in ipairs(toolbar.groups) do
        if group.is_split_point then
            layout.split_point = i
            break
        end
    end
    
    -- Calculate each group's layout
    -- Add left margin equal to the larger of button spacing or separator width
    local left_margin = math.max(CONFIG.SIZES.SPACING, CONFIG.SIZES.SEPARATOR_WIDTH)
    local current_x = left_margin
    local max_height = CONFIG.SIZES.HEIGHT
    
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
        
        if not needs_recalc then
            -- Use cached dimensions
            group_layout = {
                x = current_x,
                y = 0,
                width = cached_dims.width,
                height = cached_dims.height,
                buttons = {}
            }
            
            -- Calculate button positions using cached dimensions
            local button_x = 0
            for j, button in ipairs(group.buttons) do
                local button_width = button.cached_width and button.cached_width.total or 
                                    self:calculateButtonWidth(self.ctx, button)
                
                local button_layout = {
                    x = button_x,
                    y = 0,
                    width = button_width,
                    height = CONFIG.SIZES.HEIGHT
                }
                
                table.insert(group_layout.buttons, button_layout)
                button_x = button_x + button_width + (j < #group.buttons and CONFIG.SIZES.SPACING or 0)
            end
        else
            -- Calculate group layout
            group_layout = self:calculateGroupLayout(group)
        end
        
        -- Position the group
        group_layout.x = current_x
        group_layout.y = 0
        
        -- Track maximum height needed
        max_height = math.max(max_height, group_layout.height)
        
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
        
        current_x = current_x + group_layout.width + spacing
    end
    
    -- Set the total height to the maximum height needed
    layout.height = max_height
    
    -- Calculate total width
    for i, group_layout in ipairs(layout.groups) do
        local group_end = group_layout.x + group_layout.width
        layout.width = math.max(layout.width, group_end)
    end
    
    -- Adjust layout for split point if needed
    if layout.split_point then
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
            button_layout.scroll_x = button_layout.x - scroll_x
            button_layout.scroll_y = button_layout.y - scroll_y
        end
    end
end

function LayoutManager:calculateButtonWidth(ctx, button)
    -- Initialize layout cache if needed
    if not button.cache.layout then
        button.cache.layout = {}
    end
    
    -- Check if width is already cached
    if button.cache.layout.width then
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
        
        -- Calculate separator width based on edit mode
        local separator_width = editing_mode and math.max(CONFIG.SIZES.SEPARATOR_WIDTH, 20) or CONFIG.SIZES.SEPARATOR_WIDTH
        
        local extra_padding = 0
        if button.is_section_end or button.is_alone then
            extra_padding = math.floor((CONFIG.SIZES.ROUNDING - 8) / 4)
        end
        
        -- Cache the calculated width
        button.cache.layout.width = separator_width + extra_padding
        button.cache.layout.extra_padding = extra_padding
        button.cache.layout.height = CONFIG.SIZES.HEIGHT
        
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

    -- Initialize text cache if needed
    if not button.cache.text then
        button.cache.text = {}
    end
    
    -- Calculate text width if not already cached
    if not button.cache.text.width then
        button.cache.text.width = 0
        if not (button.hide_label or CONFIG.UI.HIDE_ALL_LABELS) then
            button.cache.text.width = C.ButtonContent:calculateTextWidth(ctx, button.display_text)
        end
    end

    -- Get icon width from cache if available
    local icon_width = 0
    if button.icon_char and button.icon_font then
        icon_width = CONFIG.ICON_FONT.WIDTH
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
    if icon_width > 0 and button.cache.text.width > 0 then
        total_width = math.max(CONFIG.SIZES.MIN_WIDTH, icon_width + CONFIG.ICON_FONT.PADDING + button.cache.text.width)
    elseif icon_width > 0 then
        total_width = math.max(CONFIG.SIZES.MIN_WIDTH, icon_width)
    else
        total_width = math.max(CONFIG.SIZES.MIN_WIDTH, button.cache.text.width)
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

function LayoutManager:calculateGroupLayout(group)
    local group_layout = {
        width = 0,
        height = CONFIG.SIZES.HEIGHT,
        buttons = {},
        label_height = 0
    }
    
    -- Calculate button layouts and total width
    local current_x = 0
    
    for i, button in ipairs(group.buttons) do
        -- Calculate button width
        local button_width = self:calculateButtonWidth(self.ctx, button)
        
        local button_layout = {
            x = current_x,
            y = 0,
            width = button_width,
            height = CONFIG.SIZES.HEIGHT
        }
        
        table.insert(group_layout.buttons, button_layout)
        current_x = current_x + button_width + (i < #group.buttons and CONFIG.SIZES.SPACING or 0)
        
        -- Clear layout dirty flag after recalculation
        button.layout_dirty = false
    end
    
    -- Total width is position of last button plus its width
    if #group.buttons > 0 then
        group_layout.width = current_x - (CONFIG.SIZES.SPACING > 0 and CONFIG.SIZES.SPACING or 0)
    end
    
    -- Calculate label height if needed
    if CONFIG.UI.USE_GROUP_LABELS and group.group_label and group.group_label.text and #group.group_label.text > 0 then
        group_layout.label_height = 20  -- Approximate, will be calculated more precisely during rendering
        group_layout.height = group_layout.height + group_layout.label_height
    end
    
    -- Cache the calculated dimensions
    group:cacheDimensions(group_layout.width, group_layout.height)
    
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