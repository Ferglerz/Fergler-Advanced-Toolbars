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
    
    return self
end

function LayoutManager:getToolbarLayout(toolbar_id, toolbar)
    -- Check if layout needs to be recalculated
    local layout = self.toolbar_layouts[toolbar_id]
    
    if not layout or self.force_recalculate or self:needsRecalculation(toolbar) then
        layout = self:calculateToolbarLayout(toolbar)
        self.toolbar_layouts[toolbar_id] = layout
    end
    
    return layout
end

function LayoutManager:needsRecalculation(toolbar)
    -- Check if any config parameters that affect layout have changed
    if self.config_changed then
        return true
    end
    
    -- Check if any buttons have dirty flags
    for _, button in ipairs(toolbar.buttons) do
        if button.is_dirty then
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
        split_point = nil
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
        local group_layout = self:calculateGroupLayout(group)
        
        -- Position the group
        group_layout.x = current_x
        group_layout.y = 0
        
        table.insert(layout.groups, group_layout)
        current_x = current_x + group_layout.width + CONFIG.SIZES.SEPARATOR_WIDTH
        
        -- Update total layout width (will be adjusted later for split)
        layout.width = current_x
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
    
    -- Check for cached dimensions first
    local cached_dims = group:getDimensions()
    if cached_dims then
        group_layout.width = cached_dims.width
        group_layout.height = cached_dims.height
        
        -- Calculate button positions within the group
        local current_x = 0
        for i, button in ipairs(group.buttons) do
            local button_width = C.ButtonContent:calculateButtonWidth(self.ctx, button)
            
            local button_layout = {
                x = current_x,
                y = 0,
                width = button_width,
                height = CONFIG.SIZES.HEIGHT
            }
            
            table.insert(group_layout.buttons, button_layout)
            current_x = current_x + button_width + (i < #group.buttons and CONFIG.SIZES.SPACING or 0)
        end
    else
        -- Calculate layout from scratch
        local current_x = 0
        
        for i, button in ipairs(group.buttons) do
            local button_width = C.ButtonContent:calculateButtonWidth(self.ctx, button)
            
            local button_layout = {
                x = current_x,
                y = 0,
                width = button_width,
                height = CONFIG.SIZES.HEIGHT
            }
            
            table.insert(group_layout.buttons, button_layout)
            current_x = current_x + button_width + (i < #group.buttons and CONFIG.SIZES.SPACING or 0)
            group_layout.width = current_x - (i < #group.buttons and CONFIG.SIZES.SPACING or 0)
        end
        
        -- Calculate label height if needed
        if CONFIG.UI.USE_GROUP_LABELS and group.group_label and group.group_label.text and #group.group_label.text > 0 then
            group_layout.label_height = 20  -- Approximate, will be calculated more precisely during rendering
            group_layout.height = group_layout.height + group_layout.label_height
        end
        
        -- Cache the calculated dimensions
        group:cacheDimensions(group_layout.width, group_layout.height)
    end
    
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