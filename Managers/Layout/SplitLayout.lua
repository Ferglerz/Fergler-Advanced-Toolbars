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
