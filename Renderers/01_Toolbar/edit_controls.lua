-- Renderers/01_Toolbar/edit_controls.lua

function ToolbarWindow:getToolbarTrailingInsertAnchorButton(currentToolbar)
    if not currentToolbar or currentToolbar.is_toolbar_switch_widget then
        return nil
    end
    if self:toolbarIsEmpty(currentToolbar) then
        return select(1, self.toolbar_controller:getEmptyPlaceholderButton(currentToolbar))
    end
    local bu = currentToolbar.buttons
    if not bu or #bu == 0 then
        return nil
    end
    return bu[#bu]
end

-- Trailing + control in edit mode: same insert menu as between buttons; empty toolbar uses "before" on placeholder.
function ToolbarWindow:renderEditModeTrailingAddControl(
    ctx,
    coords,
    draw_list,
    layout,
    currentToolbar,
    window_width,
    window_height,
    centered_y,
    edit_mode_left_gutter,
    content_offset_x,
    content_offset_y
)
    if not layout or not layout.groups or #layout.groups < 1 then
        return
    end
    local gi = #layout.groups
    local group_layout = layout.groups[gi]
    if not group_layout.buttons or #group_layout.buttons < 1 then
        return
    end
    local bl = group_layout.buttons[#group_layout.buttons]

    local preset_open = C.Interactions and C.Interactions.isPresetBrowserOpen and C.Interactions:isPresetBrowserOpen()
    if C.DragDropManager:isDragging() or preset_open then
        return
    end

    local group_x, group_y = self:resolveGroupScreenPos(layout, gi, edit_mode_left_gutter, window_width, window_height, centered_y, content_offset_x, content_offset_y)

    local spacing = CONFIG.SIZES.SPACING or 0
    local sep_size = (CONFIG.SIZES and CONFIG.SIZES.SEPARATOR_SIZE) or 12
    -- Match visual gap used around in-toolbar separators: inter-item spacing + separator column.
    local trail_gap = spacing + sep_size
    local outer_r = math.max(3, math.floor(0.3 * CONFIG.SIZES.MIN_HEIGHT + 0.5))
    local trail_right = group_x + bl.x + bl.width
    local glyph_cx, glyph_cy
    local bh = bl.height or CONFIG.SIZES.HEIGHT
    if layout.is_vertical then
        -- Below buttons + GROUP label row (group_layout.height includes label strip from layout manager).
        local gw = group_layout.width or (bl.width or 0)
        glyph_cx = math.floor(group_x + gw * 0.5 + 0.5)
        glyph_cy = math.floor(group_y + group_layout.height + trail_gap + outer_r + 0.5)
    else
        glyph_cx = math.floor(trail_right + trail_gap + outer_r + 0.5)
        glyph_cy = math.floor(group_y + (bl.y or 0) + bh * 0.5 + 0.5)
    end

    local pad = 4
    local hit = math.ceil(outer_r * 2 + pad * 2)
    local hit_x = glyph_cx - hit * 0.5
    local hit_y = glyph_cy - hit * 0.5

    local toolbar_id = tostring(self.toolbar_controller.toolbar_id or "tb")
    local clicked, is_hovered, is_clicked =
        C.Interactions:setupInteractionArea(ctx, hit_x, hit_y, hit, hit, "toolbar_trailing_add_" .. toolbar_id, coords)

    local base_hex = CONFIG.COLORS and CONFIG.COLORS.NORMAL and CONFIG.COLORS.NORMAL.TEXT and CONFIG.COLORS.NORMAL.TEXT.NORMAL
    local base_color = COLOR_UTILS.toImGuiColor(base_hex or "#B0B0B0FF")
    local gx, gy = coords:relativeToDrawList(glyph_cx, glyph_cy)
    DRAWING.drawSymbolGlyph(ctx, draw_list, gx, gy, outer_r, base_color, "plus", is_hovered or is_clicked)

    if clicked then
        local anchor = self:getToolbarTrailingInsertAnchorButton(currentToolbar)
        if anchor and C.Interactions and C.Interactions.openInsertMenu then
            local empty = self:toolbarIsEmpty(currentToolbar)
            C.Interactions:openInsertMenu(ctx, anchor, { position = empty and "before" or "after" })
        end
    end
end
