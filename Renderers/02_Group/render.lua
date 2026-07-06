function GroupRenderer:shouldSkipButtonRender(params, button, button_index)
    if params.toolbar_layout
        and params.toolbar_layout.split_active
        and params.toolbar_layout.split_point
        and params.group_index == params.toolbar_layout.split_point - 1
        and button:isSeparator()
        and button_index == #params.group.buttons then
        return true
    end
    if BUTTON_UTILS.shouldSkipSeparatorInVerticalMode(button, params.is_vertical, params.has_visible_label) then
        return true
    end
    return false
end

-- Span used to center the group label/decoration on what is actually drawn (not stale layout.width).
function GroupRenderer:shouldOmitButtonFromLabelSpan(params, button, button_index)
    if params.toolbar_layout
        and params.toolbar_layout.split_active
        and params.toolbar_layout.split_point
        and params.group_index == params.toolbar_layout.split_point - 1
        and button:isSeparator()
        and button_index == #params.group.buttons then
        return true
    end
    -- Parsed groups end on a separator; it is not part of the label/decoration span.
    if not params.is_vertical and button:isSeparator() and button_index == #params.group.buttons then
        return true
    end
    if BUTTON_UTILS.shouldSkipSeparatorInVerticalMode(button, params.is_vertical, params.has_visible_label) then
        return true
    end
    local bl = params.layout.buttons[button_index]
    if bl and (bl.width or 0) <= 0 and (bl.height or 0) <= 0 then
        return true
    end
    return false
end

function GroupRenderer:createLabelSpanAccumulator(is_vertical, fallback_x, fallback_w)
    return {
        is_vertical = is_vertical,
        fallback_x = fallback_x,
        fallback_w = fallback_w,
        left = nil,
        right = 0,
    }
end

function GroupRenderer:extendLabelSpanFromButton(span, abs_x, button_layout)
    if span.is_vertical then
        return
    end
    local right = abs_x + (button_layout.width or 0)
    span.left = span.left and math.min(span.left, abs_x) or abs_x
    span.right = math.max(span.right, right)
end

function GroupRenderer:labelSpanFromAccumulator(span)
    if span.is_vertical then
        return span.fallback_x, span.fallback_w
    end
    if span.left then
        return span.left, span.right - span.left
    end
    return span.fallback_x, span.fallback_w
end

function GroupRenderer:measureGroupLabelBounds(params)
    local pos_x = params.position and params.position.x or 0
    local layout = params.layout
    local label_span = self:createLabelSpanAccumulator(
        params.is_vertical,
        pos_x,
        layout and layout.width or 0
    )
    if layout and layout.buttons and params.group and params.group.buttons then
        for i, button_layout in ipairs(layout.buttons) do
            local button = params.group.buttons[i]
            if button and not self:shouldOmitButtonFromLabelSpan(params, button, i) then
                local button_x = pos_x + (button_layout.x or 0)
                self:extendLabelSpanFromButton(label_span, button_x, button_layout)
            end
        end
    end
    return self:labelSpanFromAccumulator(label_span)
end

function GroupRenderer:renderGroupWithParams(params)
    self:renderGroupBlockGhostIfNeeded(params)
    self:renderTrailingNewGroupButtonGhostIfNeeded(params)
    local current_x = params.position.x
    local label_span = self:createLabelSpanAccumulator(
        params.is_vertical,
        params.position.x,
        params.layout and params.layout.width or 0
    )

    -- Render all buttons (including separators)
    for i, button_layout in ipairs(params.layout.buttons) do
        local button = params.group.buttons[i]
        local button_y = params.position.y + (button_layout.y or 0)

        -- Ensure button_layout has is_vertical from toolbar layout
        if params.toolbar_layout and params.toolbar_layout.is_vertical then
            button_layout.is_vertical = true
        end

        if self:shouldSkipButtonRender(params, button, i) then
            -- Skip rendering this separator
        else
            local button_x = current_x + button_layout.x
            self:renderDragGhostButtonIfNeeded(params, button, button_layout, "before")
            C.ButtonRenderer:renderButton(
                params.ctx,
                button,
                button_x,
                button_y,
                params.coords,
                params.draw_list,
                params.editing_mode,
                button_layout,
                { button_index_in_group = i }
            )
            self:renderDragGhostButtonIfNeeded(params, button, button_layout, "after")
            if not self:shouldOmitButtonFromLabelSpan(params, button, i) then
                self:extendLabelSpanFromButton(label_span, button_x, button_layout)
            end
        end
    end

    -- Render group label if needed
    if BUTTON_UTILS.shouldShowGroupLabelRow(params.editing_mode, params.group) then
        local label_x, label_w = self:labelSpanFromAccumulator(label_span)
        self:renderGroupLabel(
            params.ctx,
            params.group,
            label_x,
            params.position.y,
            label_w,
            params.coords,
            params.draw_list,
            params.layout,
            params.toolbar_layout,
            params.editing_mode,
            params.toolbar_owner,
            params.group_index
        )
    end

    return params.layout.width, params.layout.height
end

-- Ensure label cache exists and is initialized
