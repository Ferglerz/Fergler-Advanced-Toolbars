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
    
    -- Create cache key that includes window dimensions
    local cache_key = toolbar_id .. "_" .. window_width .. "x" .. window_height
    
    -- Check if layout needs to be recalculated
    local layout = self.toolbar_layouts[cache_key]
    
    -- Only recalculate when necessary
    if not layout or 
       self.force_recalculate or
       window_width ~= self.last_window_width or 
       window_height ~= self.last_window_height or
       self:needsRecalculation(toolbar) then
        
        -- Update window dimensions
        self.last_window_width = window_width
        self.last_window_height = window_height
        
        -- Calculate the layout and store it
        layout = self:calculateToolbarLayout(toolbar)
        self.toolbar_layouts[cache_key] = layout
    end
    
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
        height = CONFIG.SIZES.HEIGHT,
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
    local current_x = 0
    
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
                                    C.ButtonContent:calculateButtonWidth(self.ctx, button)
                
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
        
        -- Add to layout
        table.insert(layout.groups, group_layout)
        
        -- Update position for next group
        current_x = current_x + group_layout.width + CONFIG.SIZES.SEPARATOR_WIDTH
    end
    
    -- Calculate total width
    for i, group_layout in ipairs(layout.groups) do
        local group_end = group_layout.x + group_layout.width
        layout.width = math.max(layout.width, group_end)
    end
    
    -- Adjust layout for split point if needed
    if layout.split_point then
        self:adjustLayoutForSplit(layout)
    end
    
    return layout
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
        local button_width
        if button.cached_width and not button.layout_dirty then
            button_width = button.cached_width.total
        else
            button_width = C.ButtonContent:calculateButtonWidth(self.ctx, button)
            -- Clear layout dirty flag after recalculation
            button.layout_dirty = false
        end
        
        local button_layout = {
            x = current_x,
            y = 0,
            width = button_width,
            height = CONFIG.SIZES.HEIGHT
        }
        
        table.insert(group_layout.buttons, button_layout)
        current_x = current_x + button_width + (i < #group.buttons and CONFIG.SIZES.SPACING or 0)
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
        if i < #layout.groups then
            right_width = right_width + CONFIG.SIZES.SEPARATOR_WIDTH
        end
    end
    
    -- Add some extra padding
    right_width = right_width + CONFIG.SIZES.SEPARATOR_WIDTH
    
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