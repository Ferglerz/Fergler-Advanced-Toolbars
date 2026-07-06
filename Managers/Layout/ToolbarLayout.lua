return function(LayoutManager)
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

end
