-- Renderers/01_Toolbars.lua

local ToolbarWindow = {}
ToolbarWindow.__index = ToolbarWindow

function ToolbarWindow.new(ToolbarController)
    local self = setmetatable({}, ToolbarWindow)
    self.toolbar_controller = ToolbarController
    self.fonts_preloaded = false
    self.last_window_width = 0
    self.last_window_height = 0
    -- Min window height for pinned/anchored mode (updated after layout each frame)
    self._pin_content_min_h = nil
    return self
end

-- Vertical slack matching calculateVerticalCenter (min_padding top + symmetric bottom)
local PIN_HEIGHT_PAD = 16

-- REAPER API: col_main_bg2 = main window / transport background (see SetThemeColor / GetThemeColor docs).
local function theme_transport_background_imgui()
    if not reaper.GetThemeColor then
        return nil
    end
    local ok, c = pcall(function()
        return reaper.GetThemeColor("col_main_bg2", 0)
    end)
    if not ok or type(c) ~= "number" or c < 0 then
        return nil
    end
    return COLOR_UTILS.reaperColorToImGui(c)
end

-- Pinned UI-anchor toolbars always use horizontal row layout; height is content minimum only.
function ToolbarWindow:computePinnedMinContentHeight(layout, layout_switch, show_switch)
    if not layout.groups or #layout.groups == 0 then
        local label = (CONFIG.UI and CONFIG.UI.USE_GROUP_LABELS) and 24 or 0
        return (CONFIG.SIZES.HEIGHT or 38) + label + PIN_HEIGHT_PAD
    end
    local row_h = layout.height
    if show_switch and layout_switch then
        row_h = math.max(row_h, layout_switch.height)
    end
    return row_h + PIN_HEIGHT_PAD
end

function ToolbarWindow:render(ctx, font)
    if not self.toolbar_controller then
        return
    end

    self.toolbar_controller.ctx = ctx
    self.toolbar_controller:applyDockState(ctx)

    reaper.ImGui_PushFont(ctx, font, CONFIG.SIZES.TEXT)

    local pin_chrome = self.toolbar_controller:shouldUsePinnedChrome()
    local follow = self.toolbar_controller:shouldFollowUiAnchor()
    local ax, ay, aw, ah
    local R = _G.REAPER_UI_ANCHOR
    if follow and R then
        ax, ay, aw, ah = R.get_anchor_rect(self.toolbar_controller.ui_anchor, ctx)
    end
    local pin_layout_ok = follow and ax ~= nil and ay ~= nil and aw and ah and aw > 8 and ah > 8
    local pin_transport_fill = pin_layout_ok and self.toolbar_controller.ui_anchor == "transport"
    -- Transport bar fill needs exact size; tcp/arrange pins only lock position.
    local pin_size_locked = pin_transport_fill

    local off_x = tonumber(self.toolbar_controller.ui_pin_offset_x) or 0
    local off_y = tonumber(self.toolbar_controller.ui_pin_offset_y) or 0
    local pin_x = pin_layout_ok and (ax + off_x) or ax
    local pin_y = pin_layout_ok and (ay + off_y) or ay

    local pin_w, pin_h
    if pin_layout_ok then
        local fallback_min = (CONFIG.SIZES.HEIGHT or 38) + ((CONFIG.UI and CONFIG.UI.USE_GROUP_LABELS) and 24 or 0) + PIN_HEIGHT_PAD
        local min_pin_h = math.max(8, self._pin_content_min_h or fallback_min)
        pin_w = math.max(8, aw)
        pin_h = math.max(8, min_pin_h)
        reaper.ImGui_SetNextWindowPos(ctx, pin_x, pin_y, reaper.ImGui_Cond_Always())
        if pin_size_locked then
            reaper.ImGui_SetNextWindowSize(ctx, pin_w, pin_h, reaper.ImGui_Cond_Always())
            reaper.ImGui_SetNextWindowSizeConstraints(ctx, pin_w, pin_h, pin_w, pin_h)
        else
            reaper.ImGui_SetNextWindowSize(ctx, 800, pin_h, reaper.ImGui_Cond_FirstUseEver())
            reaper.ImGui_SetNextWindowSizeConstraints(ctx, 50, pin_h, 2000, 1000)
        end
        if reaper.ImGui_SetNextWindowBgAlpha and not pin_transport_fill then
            pcall(function()
                reaper.ImGui_SetNextWindowBgAlpha(ctx, 0)
            end)
        end
    end

    -- Opaque colors on the shared stack so other ImGui windows (dropdowns, editors) stay solid.
    -- Pinned toolbars use NoBackground + SetNextWindowBgAlpha(0), except transport anchor (theme bar).
    local opaque_bg = CONFIG_MANAGER:getCachedColorSafe("WINDOW_BG") or COLOR_UTILS.toImGuiColor(CONFIG.COLORS.WINDOW_BG)
    local window_bg_push = (pin_transport_fill and theme_transport_background_imgui()) or opaque_bg

    local styles = {
        {reaper.ImGui_Col_WindowBg(), window_bg_push},
        {reaper.ImGui_Col_PopupBg(), opaque_bg},
        {reaper.ImGui_Col_SliderGrab(), 0x888888FF},
        {reaper.ImGui_Col_SliderGrabActive(), 0xAAAAAAFF},
        {reaper.ImGui_Col_FrameBg(), 0x555555FF}
    }

    for _, style in ipairs(styles) do
        reaper.ImGui_PushStyleColor(ctx, style[1], style[2])
    end

    -- Vertical toolbar column mode from cached window shape; UI-anchor pin always uses horizontal rows
    local is_vertical = not self.toolbar_controller:shouldFollowUiAnchor()
        and self.last_window_width > 0
        and self.last_window_height > 0
        and self.last_window_width < self.last_window_height

    if not pin_layout_ok then
        self._pin_content_min_h = nil
        reaper.ImGui_SetNextWindowSize(ctx, 800, 60, reaper.ImGui_Cond_FirstUseEver())
        -- Reduce max size constraints to prevent windows from being too large and creating invisible clickable areas
        -- Use reasonable maximums: 2000px width, 1000px height (instead of 10000x10000)
        local min_height = 60
        local min_width = 50
        if self.toolbar_controller then
            local rc = self.toolbar_controller:getRowCount()
            if not is_vertical then
                min_height = math.max(60, rc * ((CONFIG.SIZES and CONFIG.SIZES.HEIGHT or 38) + 8))
            else
                min_width = math.max(50, rc * (CONFIG.SIZES and CONFIG.SIZES.MIN_WIDTH or 30))
            end
        end
        reaper.ImGui_SetNextWindowSizeConstraints(ctx, min_width, min_height, 2000, 1000)
    end

    local window_flags =
        reaper.ImGui_WindowFlags_NoTitleBar() |
        reaper.ImGui_WindowFlags_NoCollapse() |
        reaper.ImGui_WindowFlags_NoFocusOnAppearing()
    if pin_chrome and reaper.ImGui_WindowFlags_NoDocking then
        window_flags = window_flags | reaper.ImGui_WindowFlags_NoDocking()
    end
    if pin_chrome and reaper.ImGui_WindowFlags_NoSavedSettings then
        window_flags = window_flags | reaper.ImGui_WindowFlags_NoSavedSettings()
    end
    if pin_layout_ok and pin_size_locked and reaper.ImGui_WindowFlags_NoResize then
        window_flags = window_flags | reaper.ImGui_WindowFlags_NoResize()
    end
    -- Locked to anchor when rect exists; still disallow dragging whenever pin mode is on (incl. rect lookup lag)
    if pin_chrome and reaper.ImGui_WindowFlags_NoMove then
        window_flags = window_flags | reaper.ImGui_WindowFlags_NoMove()
    end
    if pin_chrome and reaper.ImGui_WindowFlags_NoBackground and not pin_transport_fill then
        window_flags = window_flags | reaper.ImGui_WindowFlags_NoBackground()
    end

    -- Hide scrollbar in vertical mode (but still allow scrolling)
    if is_vertical then
        window_flags = window_flags | reaper.ImGui_WindowFlags_NoScrollbar()
    end

    -- Use unique window name for each toolbar to prevent conflicts
    local window_name = "Dynamic Toolbar##" .. (self.toolbar_controller.toolbar_id or "default")
    local visible, open = reaper.ImGui_Begin(ctx, window_name, true, window_flags)
    self.toolbar_controller.is_open = open
    if not pin_layout_ok then
        UTILS.snapWindowToMinimum(ctx, 0, 0, true)
    end

    if visible then
        if pin_layout_ok then
            reaper.ImGui_SetWindowPos(ctx, pin_x, pin_y, reaper.ImGui_Cond_Always())
            if pin_size_locked and pin_w and pin_h then
                reaper.ImGui_SetWindowSize(ctx, pin_w, pin_h, reaper.ImGui_Cond_Always())
            end
        end
        -- Cache window dimensions for next frame
        self.last_window_width = reaper.ImGui_GetWindowWidth(ctx)
        self.last_window_height = reaper.ImGui_GetWindowHeight(ctx)
        if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) then
            if C.DragDropManager and C.DragDropManager:isDragging() then
                C.DragDropManager:endDrag()
            elseif _G.POPUP_OPEN then
                if C.PopupContext then
                    C.PopupContext.closeAllAuxiliaryWindows({
                        include_insert_menu = true,
                        include_action_search = true,
                        focus_arrange = true,
                        clear_popup_flag = true,
                    })
                end
            elseif self.toolbar_controller.button_editing_mode then
                self.toolbar_controller:toggleEditingMode(false)
                UTILS.focusArrangeWindow(true)
            end
        end

        local hover_flags = reaper.ImGui_HoveredFlags_ChildWindows and reaper.ImGui_HoveredFlags_ChildWindows() or 0
        if reaper.ImGui_IsWindowHovered(ctx, hover_flags) and not reaper.ImGui_IsAnyItemHovered(ctx) and reaper.ImGui_IsMouseClicked(ctx, 1) then
            reaper.ImGui_OpenPopup(ctx, "toolbar_settings_menu")
        end

        local popup_open = false
        local toolbars = self.toolbar_controller.toolbars

        -- Pinned chrome (zero padding / flat border) applies only while drawing the main toolbar
        -- body, not during BeginPopup/Begin for settings, dropdowns, or other sub-windows.
        local function pushPinChromeStyleVars()
            local n = 0
            if pin_chrome and reaper.ImGui_StyleVar_WindowBorderSize and reaper.ImGui_StyleVar_WindowRounding then
                reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowBorderSize(), 0)
                reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowRounding(), 0)
                n = 2
                -- Match REAPER region width: default window padding shrinks the content region vs outer size
                if pin_layout_ok and reaper.ImGui_StyleVar_WindowPadding then
                    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding(), 0, 0)
                    n = n + 1
                end
            end
            return n
        end

        if toolbars and #toolbars > 0 then
            local pin_inner_style_vars = pushPinChromeStyleVars()
            popup_open = self:renderToolbarContent(ctx) or popup_open
            if pin_inner_style_vars > 0 then
                reaper.ImGui_PopStyleVar(ctx, pin_inner_style_vars)
            end
            if C.Interactions and C.Interactions:takeOpenToolbarSettingsDeferred(ctx) then
                reaper.ImGui_OpenPopup(ctx, "toolbar_settings_menu")
            end
            popup_open = reaper.ImGui_IsPopupOpen(ctx, "toolbar_settings_menu") or popup_open
            self:renderToolbarSettings(ctx)
            popup_open = reaper.ImGui_IsPopupOpen(ctx, "toolbar_settings_menu") or popup_open
        else
            local pin_inner_style_vars = pushPinChromeStyleVars()
            reaper.ImGui_Text(ctx, "No toolbars found in reaper-menu.ini")
            if pin_inner_style_vars > 0 then
                reaper.ImGui_PopStyleVar(ctx, pin_inner_style_vars)
            end
        end

        popup_open = self:renderUIElements(ctx, popup_open)

        local is_mouse_down = reaper.ImGui_IsMouseDown(ctx, 0) or reaper.ImGui_IsMouseDown(ctx, 1)

        -- Only refocus arrange window when explicitly closing popups or exiting edit mode
        -- Don't refocus on every mouse release as it can block other scripts from opening
        -- if self.was_mouse_down and not is_mouse_down and not popup_open then
        --     UTILS.focusArrangeWindow(true)
        -- end

        self.was_mouse_down = is_mouse_down
        self.is_mouse_down = is_mouse_down
    end

    pcall(reaper.ImGui_End, ctx)
    reaper.ImGui_PopStyleColor(ctx, #styles)
    reaper.ImGui_PopFont(ctx)
end

function ToolbarWindow:renderToolbarSettings(ctx)
    require("Systems.Modules_Factory").ensureUiModules()
    local colorCount, styleCount = C.GlobalStyle.apply(ctx)
    if reaper.ImGui_IsPopupOpen(ctx, "toolbar_settings_menu") then
        reaper.ImGui_SetNextWindowSizeConstraints(ctx, 575, 0, 575, 1150)
    end
    if not reaper.ImGui_BeginPopup(ctx, "toolbar_settings_menu") then
        C.GlobalStyle.reset(ctx, colorCount, styleCount)
        return
    end

    C.GlobalSettingsMenu:render(
        ctx,
        function()
            local current_toolbar = self.toolbar_controller:getCurrentToolbar()
            CONFIG_MANAGER:requestSaveMainConfig()

            if current_toolbar then
                for _, group in ipairs(current_toolbar.groups) do
                    group:clearCache()
                    for _, button in ipairs(group.buttons) do
                        button:clearCache()
                    end
                end
                self.toolbar_controller.last_min_width = nil
                self.toolbar_controller.last_height = nil
                self.toolbar_controller.last_spacing = nil
            end
        end,
        function(value, get_only)
            return self.toolbar_controller:toggleEditingMode(value, get_only)
        end,
        self.toolbar_controller.toolbars,
        self.toolbar_controller.currentToolbarIndex,
        function(index)
            self.toolbar_controller:setCurrentToolbarIndex(index)
        end,
        self.toolbar_controller,
        true
    )

    reaper.ImGui_EndPopup(ctx)
    C.GlobalStyle.reset(ctx, colorCount, styleCount)
end

function ToolbarWindow:toolbarIsEmpty(toolbar)
    return not toolbar or not toolbar.buttons or #toolbar.buttons == 0
end

-- L/R or U/D split: last anchor is flush to window edge; with 2+ anchors, groups between first and last anchors shift as one centered block.
function ToolbarWindow:layoutGroupOriginForSplit(layout, window_width, window_height, group_index, gx, gy)
    if not layout.split_active or not layout.split_point or not layout.groups[layout.split_point] then
        return gx, gy
    end
    local S = layout.split_indices
    local sp = layout.split_point
    if not layout.is_vertical then
        if group_index >= sp then
            gx = window_width - layout.right_width + (gx - layout.groups[sp].x)
        elseif S and #S >= 2 and group_index >= S[1] and group_index < sp then
            gx = gx + (layout.split_center_offset_x or 0)
        end
    else
        local bottom_h = layout.bottom_height or 0
        if group_index >= sp then
            gy = window_height - bottom_h + (gy - layout.groups[sp].y)
        elseif S and #S >= 2 and group_index >= S[1] and group_index < sp then
            gy = gy + (layout.split_center_offset_y or 0)
        end
    end
    return gx, gy
end

-- Relative rect for one button from layout (same math as GroupRenderer:renderGroup).
function ToolbarWindow:getGroupButtonRect(layout, group_index, button_index, centered_y, edit_mode_left_gutter, window_width, window_height, offset_x, offset_y)
    local group_layout = layout.groups[group_index]
    local button_layout = group_layout.buttons[button_index]
    edit_mode_left_gutter = edit_mode_left_gutter or 0
    offset_x = offset_x or 0
    offset_y = offset_y or 0
    local group_x = group_layout.x + edit_mode_left_gutter
    local group_y = layout.is_vertical and (group_layout.y or 0) or centered_y
    group_x, group_y = self:layoutGroupOriginForSplit(layout, window_width, window_height or 0, group_index, group_x, group_y)
    return {
        rel_x = group_x + button_layout.x + offset_x,
        rel_y = group_y + (button_layout.y or 0) + offset_y,
        width = button_layout.width,
        height = button_layout.height
    }
end

function ToolbarWindow:tagToolbarButtons(toolbar, controller_id)
    if not toolbar or not toolbar.groups then
        return
    end
    for _, group in ipairs(toolbar.groups) do
        for _, button in ipairs(group.buttons) do
            button.atb_controller_id = controller_id
            -- Layout runs before WidgetRenderer:renderWidget; tag the same fields draw will set so
            -- getLayoutWidth / saved state (e.g. toolbars_list, ftc_adaptive_grid) use the real button id.
            if button.widget then
                button.widget._atb_controller_id = controller_id
                button.widget._button_instance_id = button.instance_id
            end
        end
    end
end

-- Thin line between toolbar-switch widget and main toolbar (same style as 03_Button_separator).
-- gap_before_sep: space between switch strip edge and separator column (can be larger than SPACING).
-- pin_shift_x: horizontal nudge when pinned with extra window width (left/center/right align).
function ToolbarWindow:drawToolbarSwitchSeparator(ctx, draw_list, coords, layout_switch, is_vertical, sep_size, centered_y, gap_before_sep, pin_shift_x, offset_x, offset_y, col_width)
    gap_before_sep = gap_before_sep or (CONFIG.SIZES and CONFIG.SIZES.SPACING) or 2
    pin_shift_x = pin_shift_x or 0
    offset_x = offset_x or 0
    offset_y = offset_y or 0
    local line_thickness = 2.0
    local line_color = CONFIG_MANAGER:getCachedColorSafe("SEPARATOR", "LINE", "NORMAL") or 0x666666FF
    local ww = col_width or reaper.ImGui_GetWindowWidth(ctx)
    local H = CONFIG.SIZES.HEIGHT
    local inset = math.max(2, math.floor(H / 6))

    if is_vertical then
        local separator_rel_y = layout_switch.height + gap_before_sep + sep_size / 2 + offset_y
        local x1_rel = 6 + pin_shift_x + offset_x
        local x2_rel = offset_x + ww - 6 + pin_shift_x
        local x1_draw, separator_y = coords:relativeToDrawList(x1_rel, separator_rel_y)
        local x2_draw, _ = coords:relativeToDrawList(x2_rel, separator_rel_y)
        reaper.ImGui_DrawList_AddLine(draw_list, x1_draw, separator_y, x2_draw, separator_y, line_color, line_thickness)
    else
        local separator_rel_x = layout_switch.width + gap_before_sep + sep_size / 2 + pin_shift_x + offset_x
        local y1_rel = centered_y + inset
        local y2_rel = centered_y + H - inset
        local separator_x = select(1, coords:relativeToDrawList(separator_rel_x, 0))
        local _, y1_draw = coords:relativeToDrawList(0, y1_rel)
        local _, y2_draw = coords:relativeToDrawList(0, y2_rel)
        reaper.ImGui_DrawList_AddLine(draw_list, separator_x, y1_draw, separator_x, y2_draw, line_color, line_thickness)
    end
end

function ToolbarWindow:buildPlaceholderShadowToolbar(currentToolbar, ph_group, ph_button)
    return {
        section = currentToolbar.section,
        name = currentToolbar.name,
        custom_name = currentToolbar.custom_name,
        groups = { ph_group },
        buttons = { ph_button },
        updateName = currentToolbar.updateName,
        addButton = currentToolbar.addButton
    }
end

function ToolbarWindow:renderEmptyDropHighlight(ctx, draw_list, coords, rect)
    local x1, y1 = coords:relativeToDrawList(rect.rel_x, rect.rel_y)
    local x2, y2 = coords:relativeToDrawList(rect.rel_x + rect.width, rect.rel_y + rect.height)
    reaper.ImGui_DrawList_AddRect(draw_list, x1, y1, x2, y2, 0x00FF00FF, 0, 0, 3)
end

function ToolbarWindow:calculateVerticalCenter(ctx, layout, editing_mode)
    if layout and layout.is_vertical then
        return (layout.padding_y or 0)
    end

    local window_height = reaper.ImGui_GetWindowHeight(ctx)
    local content_height = layout.height
    local center_y = (window_height - content_height) / 2
    local min_padding = 8
    return math.max(center_y, min_padding)
end

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

    local group_x = group_layout.x + edit_mode_left_gutter + content_offset_x
    local group_y = (layout.is_vertical and (group_layout.y or 0) or centered_y) + content_offset_y
    group_x, group_y = self:layoutGroupOriginForSplit(layout, window_width, window_height or 0, gi, group_x, group_y)

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
        C.Interactions:setupInteractionArea(ctx, hit_x, hit_y, hit, hit, "toolbar_trailing_add_" .. toolbar_id)

    local base_hex = CONFIG.COLORS and CONFIG.COLORS.NORMAL and CONFIG.COLORS.NORMAL.TEXT and CONFIG.COLORS.NORMAL.TEXT.NORMAL
    local base_color = COLOR_UTILS.toImGuiColor(base_hex or "#B0B0B0FF")
    local gx, gy = coords:relativeToDrawList(glyph_cx, glyph_cy)
    DRAWING.toolbarEndAddGlyph(draw_list, gx, gy, outer_r, base_color, is_hovered or is_clicked)

    if clicked then
        local anchor = self:getToolbarTrailingInsertAnchorButton(currentToolbar)
        if anchor and C.Interactions and C.Interactions.openInsertMenu then
            local empty = self:toolbarIsEmpty(currentToolbar)
            C.Interactions:openInsertMenu(ctx, anchor, { position = empty and "before" or "after" })
        end
    end
end

-- True when the pointer is past all groups on the main axis (horizontal: right of last group; vertical: below last).
function ToolbarWindow:isToolbarTrailingDropZone(
    layout,
    base_y,
    edit_mode_left_gutter,
    content_offset_x,
    content_offset_y,
    window_width,
    window_height,
    mouse_rel_x,
    mouse_rel_y
)
    if not layout or not layout.groups or #layout.groups < 1 then
        return false
    end
    edit_mode_left_gutter = edit_mode_left_gutter or 0
    content_offset_x = content_offset_x or 0
    content_offset_y = content_offset_y or 0
    base_y = base_y or 0
    local min_l, min_t, max_r, max_b = math.huge, math.huge, 0, 0
    for i, group_layout in ipairs(layout.groups) do
        local gx = group_layout.x + edit_mode_left_gutter + content_offset_x
        local gy = (layout.is_vertical and (group_layout.y or 0) or base_y) + content_offset_y
        gx, gy = self:layoutGroupOriginForSplit(layout, window_width, window_height or 0, i, gx, gy)
        min_l = math.min(min_l, gx)
        min_t = math.min(min_t, gy)
        max_r = math.max(max_r, gx + group_layout.width)
        max_b = math.max(max_b, gy + group_layout.height)
    end
    if layout.is_vertical then
        return mouse_rel_x >= min_l and mouse_rel_x <= max_r and mouse_rel_y > max_b
    end
    return mouse_rel_y >= min_t and mouse_rel_y <= max_b and mouse_rel_x > max_r
end

function ToolbarWindow:handleToolbarDragDrop(ctx, toolbar, editing_mode, coords, draw_list, layout, base_y, edit_mode_left_gutter, layout_source_toolbar, content_offset_x, content_offset_y)
    if not editing_mode or not C.DragDropManager:isDragging() then
        return
    end

    if toolbar and toolbar.is_toolbar_switch_widget then
        return
    end

    -- Screen-rect hit test (see Coordinates:isMouseOverWindow). Per-context ImGui_IsWindowHovered is
    -- unreliable when the drag started in another context, which broke cross-toolbar indicators and drops.
    if not coords:isMouseOverWindow() then
        return
    end
    
    edit_mode_left_gutter = edit_mode_left_gutter or 0
    layout_source_toolbar = layout_source_toolbar or toolbar
    content_offset_x = content_offset_x or 0
    content_offset_y = content_offset_y or 0

    if C.DragDropManager:isGroupDrag() then
        local payload = C.DragDropManager.drag_payload
        local src_section = payload and payload.source_toolbar
        local src_gi = payload and payload.source_group_index
        local mouse_screen_x, mouse_screen_y = COORDINATES.getMouseScreenForDrag(ctx)
        local mouse_rel_x, mouse_rel_y = coords:screenToRelative(mouse_screen_x, mouse_screen_y)
        local window_width = reaper.ImGui_GetWindowWidth(ctx)
        local window_height = reaper.ImGui_GetWindowHeight(ctx)
        -- Empty toolbar: use same placeholder landing zone as button drag (group branch would miss it)
        if (not toolbar.buttons or #toolbar.buttons == 0) and layout.groups[1] and layout.groups[1].buttons[1] and layout_source_toolbar.groups[1] and
            layout_source_toolbar.groups[1].buttons[1] and layout_source_toolbar.groups[1].buttons[1].is_empty_toolbar_placeholder then
            local g1 = layout.groups[1]
            local b1 = g1.buttons[1]
            local group_x = g1.x + edit_mode_left_gutter + content_offset_x
            local group_y = (layout.is_vertical and (g1.y or 0) or base_y) + content_offset_y
            group_x, group_y = self:layoutGroupOriginForSplit(layout, window_width, window_height, 1, group_x, group_y)
            local rx = group_x + b1.x
            local ry = group_y + (b1.y or 0)
            if mouse_rel_x >= rx and mouse_rel_x <= rx + b1.width and mouse_rel_y >= ry and mouse_rel_y <= ry + b1.height then
                C.DragDropManager.empty_drop_toolbar = toolbar
                C.DragDropManager:markPotentialDropTarget()
                return
            end
        end
        for i, group_layout in ipairs(layout.groups) do
            if layout_source_toolbar.section == src_section and i == src_gi then
                -- skip dragged source group
            else
                local group_x = group_layout.x + edit_mode_left_gutter + content_offset_x
                local group_y = (layout.is_vertical and (group_layout.y or 0) or base_y) + content_offset_y
                group_x, group_y = self:layoutGroupOriginForSplit(layout, window_width, window_height, i, group_x, group_y)
                local gw = group_layout.width
                local gh = group_layout.height
                if mouse_rel_x >= group_x and mouse_rel_x <= group_x + gw and mouse_rel_y >= group_y and mouse_rel_y <= group_y + gh then
                    C.DragDropManager.drop_target_toolbar = toolbar
                    C.DragDropManager.drop_target_group_index = i
                    if layout.is_vertical then
                        local cy = group_y + gh / 2
                        C.DragDropManager.drop_position = mouse_rel_y > cy and "after" or "before"
                    else
                        local cx = group_x + gw / 2
                        C.DragDropManager.drop_position = mouse_rel_x > cx and "after" or "before"
                    end
                    C.DragDropManager:markPotentialDropTarget()
                    break
                end
            end
        end
        if not C.DragDropManager.drop_target_group_index and #layout.groups > 0 then
            if self:isToolbarTrailingDropZone(
                layout,
                base_y,
                edit_mode_left_gutter,
                content_offset_x,
                content_offset_y,
                window_width,
                window_height,
                mouse_rel_x,
                mouse_rel_y
            ) then
                C.DragDropManager.drop_target_toolbar = toolbar
                C.DragDropManager.drop_target_group_index = #layout.groups
                C.DragDropManager.drop_position = "after"
                C.DragDropManager:markPotentialDropTarget()
            end
        end
        return
    end
    
    local button_rects = {}
    
    C.LayoutManager:setContext(ctx)
    local window_width = reaper.ImGui_GetWindowWidth(ctx)
    local window_height = reaper.ImGui_GetWindowHeight(ctx)

    for i, group_layout in ipairs(layout.groups) do
        local group = layout_source_toolbar.groups[i]
        local group_x = group_layout.x + edit_mode_left_gutter + content_offset_x
        local group_y = (layout.is_vertical and (group_layout.y or 0) or base_y) + content_offset_y
        group_x, group_y = self:layoutGroupOriginForSplit(layout, window_width, window_height, i, group_x, group_y)
        for j, button_layout in ipairs(group_layout.buttons) do
            local button = group.buttons[j]
            if not button.is_separator then
                local button_rel_x = group_x + button_layout.x
                local button_rel_y = group_y + (button_layout.y or 0)
                
                button_rects[button.instance_id] = {
                    rel_x = button_rel_x,
                    rel_y = button_rel_y,
                    width = button_layout.width,
                    height = button_layout.height,
                    button = button
                }
            end
        end
    end
    
    -- Screen mouse must come from the drag source context (or main) so cross-toolbar drags hit-test correctly.
    local mouse_screen_x, mouse_screen_y = COORDINATES.getMouseScreenForDrag(ctx)
    local mouse_rel_x, mouse_rel_y = coords:screenToRelative(mouse_screen_x, mouse_screen_y)
    
    for instance_id, rect in pairs(button_rects) do
        if C.DragDropManager:getDragSource() and C.DragDropManager:getDragSource().instance_id == instance_id then
            -- Skip source button
        else
            if mouse_rel_x >= rect.rel_x and mouse_rel_x <= rect.rel_x + rect.width and
               mouse_rel_y >= rect.rel_y and mouse_rel_y <= rect.rel_y + rect.height then
                if rect.button.is_empty_toolbar_placeholder then
                    C.DragDropManager.empty_drop_toolbar = toolbar
                else
                    C.DragDropManager.current_drop_target = rect.button
                    if layout.is_vertical then
                        local button_center_y = rect.rel_y + rect.height / 2
                        C.DragDropManager.drop_position = mouse_rel_y > button_center_y and "after" or "before"
                    else
                        local button_center_x = rect.rel_x + rect.width / 2
                        C.DragDropManager.drop_position = mouse_rel_x > button_center_x and "after" or "before"
                    end
                end
                C.DragDropManager:markPotentialDropTarget()
                break
            end
        end
    end

    local src_btn = C.DragDropManager:getDragSource()
    if not C.DragDropManager.current_drop_target and not C.DragDropManager.empty_drop_toolbar and src_btn and not src_btn:isSeparator() and
        #layout.groups > 0 and (toolbar.buttons and #toolbar.buttons > 0) then
        if self:isToolbarTrailingDropZone(
            layout,
            base_y,
            edit_mode_left_gutter,
            content_offset_x,
            content_offset_y,
            window_width,
            window_height,
            mouse_rel_x,
            mouse_rel_y
        ) then
            C.DragDropManager.drop_trailing_new_group_toolbar = toolbar
            C.DragDropManager:markPotentialDropTarget()
        end
    end
end

function ToolbarWindow:refineDropPositionForDragGhost(ctx, coords, layout, layout_source_toolbar, toolbar, base_y, edit_mode_left_gutter, content_offset_x, content_offset_y)
    if not C.DragDropManager:isDragging() then
        return
    end
    if C.DragDropManager:isGroupDrag() then
        local tgt_gi = C.DragDropManager.drop_target_group_index
        if not tgt_gi or not layout.groups[tgt_gi] then
            return
        end
        local mouse_screen_x, mouse_screen_y = COORDINATES.getMouseScreenForDrag(ctx)
        local mouse_rel_x, mouse_rel_y = coords:screenToRelative(mouse_screen_x, mouse_screen_y)
        local window_width = reaper.ImGui_GetWindowWidth(ctx)
        local window_height = reaper.ImGui_GetWindowHeight(ctx)
        edit_mode_left_gutter = edit_mode_left_gutter or 0
        content_offset_x = content_offset_x or 0
        content_offset_y = content_offset_y or 0
        local group_layout = layout.groups[tgt_gi]
        local group_x = group_layout.x + edit_mode_left_gutter + content_offset_x
        local group_y = (layout.is_vertical and (group_layout.y or 0) or base_y) + content_offset_y
        group_x, group_y = self:layoutGroupOriginForSplit(layout, window_width, window_height, tgt_gi, group_x, group_y)
        local gw = group_layout.width
        local gh = group_layout.height
        if layout.is_vertical then
            local cy = group_y + gh / 2
            C.DragDropManager.drop_position = mouse_rel_y > cy and "after" or "before"
        else
            local cx = group_x + gw / 2
            C.DragDropManager.drop_position = mouse_rel_x > cx and "after" or "before"
        end
        return
    end
    local tgt = C.DragDropManager:getCurrentDropTarget()
    if not tgt or tgt.is_empty_toolbar_placeholder then
        return
    end
    local mouse_screen_x, mouse_screen_y = COORDINATES.getMouseScreenForDrag(ctx)
    local mouse_rel_x, mouse_rel_y = coords:screenToRelative(mouse_screen_x, mouse_screen_y)
    local window_width = reaper.ImGui_GetWindowWidth(ctx)
    local window_height = reaper.ImGui_GetWindowHeight(ctx)
    edit_mode_left_gutter = edit_mode_left_gutter or 0
    content_offset_x = content_offset_x or 0
    content_offset_y = content_offset_y or 0
    for i, group_layout in ipairs(layout.groups) do
        local group = layout_source_toolbar.groups[i]
        local group_x = group_layout.x + edit_mode_left_gutter + content_offset_x
        local group_y = (layout.is_vertical and (group_layout.y or 0) or base_y) + content_offset_y
        group_x, group_y = self:layoutGroupOriginForSplit(layout, window_width, window_height, i, group_x, group_y)
        for j, button_layout in ipairs(group_layout.buttons) do
            local button = group.buttons[j]
            if button.instance_id == tgt.instance_id then
                local rel_x = group_x + button_layout.x
                local rel_y = group_y + (button_layout.y or 0)
                if layout.is_vertical then
                    local cy = rel_y + button_layout.height / 2
                    C.DragDropManager.drop_position = mouse_rel_y > cy and "after" or "before"
                else
                    local cx = rel_x + button_layout.width / 2
                    C.DragDropManager.drop_position = mouse_rel_x > cx and "after" or "before"
                end
                return
            end
        end
    end
end

function ToolbarWindow:renderSingleRow(ctx, coords, draw_list, row_toolbar, row_index, is_vertical, width_override, switch_toolbar, enable_switch, window_width, window_height, editing_mode, pin_force_horizontal, layout0, layout_switch, row_offset_x, row_offset_y)
    local popup_open = false
    
    local strip_gap = (CONFIG.SIZES and CONFIG.SIZES.SPACING) or 2
    local sep_size = (CONFIG.SIZES and CONFIG.SIZES.SEPARATOR_SIZE) or 12
    local switch_gap_before_sep = strip_gap + 4

    local main_offset_x = 0
    local main_offset_y = 0

    if enable_switch and switch_toolbar and layout_switch then
        if is_vertical then
            main_offset_y = layout_switch.height + switch_gap_before_sep + sep_size + strip_gap
        else
            main_offset_x = layout_switch.width + switch_gap_before_sep + sep_size + strip_gap
        end
    end

    local layout_source_toolbar = row_toolbar
    if self:toolbarIsEmpty(row_toolbar) then
        local ph_button, ph_group = self.toolbar_controller:getEmptyPlaceholderButton(row_toolbar)
        layout_source_toolbar = self:buildPlaceholderShadowToolbar(row_toolbar, ph_group, ph_button)
    end
    
    local pin_shift_x = 0
    if self.toolbar_controller:shouldFollowUiAnchor() and not layout0.is_vertical then
        local row_w = main_offset_x + layout0.width
        local slack = (width_override or window_width) - row_w
        if slack > 0 then
            local al = self.toolbar_controller.ui_anchor_align or "center"
            if al == "center" then
                pin_shift_x = math.floor(slack * 0.5 + 0.5)
            elseif al == "right" then
                pin_shift_x = math.floor(slack + 0.5)
            end
        end
    end

    local centered_y0 = 0
    if layout0.is_vertical then
        centered_y0 = layout0.padding_y or 0
    else
        centered_y0 = 8 -- Min padding
    end

    self:handleToolbarDragDrop(
        ctx,
        row_toolbar,
        editing_mode,
        coords,
        draw_list,
        layout0,
        centered_y0,
        0, -- edit_mode_left_gutter
        layout_source_toolbar,
        main_offset_x + pin_shift_x + (row_offset_x or 0),
        main_offset_y + (row_offset_y or 0)
    )

    local layout = C.LayoutManager:applyDragGhostLayoutShift(layout0, layout_source_toolbar) or layout0
    if layout ~= layout0 then
        local cy_refine = centered_y0
        self:refineDropPositionForDragGhost(ctx, coords, layout, layout_source_toolbar, row_toolbar, cy_refine, 0, main_offset_x + pin_shift_x + (row_offset_x or 0), main_offset_y + (row_offset_y or 0))
        layout = C.LayoutManager:applyDragGhostLayoutShift(layout0, layout_source_toolbar) or layout
    end

    local centered_y = centered_y0

    if enable_switch and layout_switch then
        local switch_title_offset_y = (not is_vertical and layout.widget_title_band) or 0
        for i, group_layout in ipairs(layout_switch.groups) do
            local group = switch_toolbar.groups[i]
            local group_x = group_layout.x + pin_shift_x + (row_offset_x or 0)
            local group_y = (layout_switch.is_vertical and (group_layout.y or 0) or (centered_y + switch_title_offset_y)) + (row_offset_y or 0)
            C.GroupRenderer:renderGroup(
                ctx,
                group,
                group_x,
                group_y,
                coords,
                draw_list,
                false,
                group_layout,
                layout_switch,
                i,
                switch_toolbar
            )
        end
        self:drawToolbarSwitchSeparator(ctx, draw_list, coords, layout_switch, is_vertical, sep_size, centered_y + switch_title_offset_y, switch_gap_before_sep, pin_shift_x, (row_offset_x or 0), (row_offset_y or 0), width_override)
    end

    if self:toolbarIsEmpty(row_toolbar) then
        for i, group_layout in ipairs(layout.groups) do
            local group = layout_source_toolbar.groups[i]
            local group_x = group_layout.x + main_offset_x + pin_shift_x + (row_offset_x or 0)
            local group_y = (layout.is_vertical and (group_layout.y or 0) or centered_y) + main_offset_y + (row_offset_y or 0)
            group_x, group_y = self:layoutGroupOriginForSplit(layout, width_override or window_width, window_height, i, group_x, group_y)

            C.GroupRenderer:renderGroup(
                ctx,
                group,
                group_x,
                group_y,
                coords,
                draw_list,
                editing_mode,
                group_layout,
                layout,
                i,
                layout_source_toolbar
            )
        end

        if editing_mode and C.DragDropManager:isDragging() and C.DragDropManager.empty_drop_toolbar == row_toolbar and
            layout.groups[1] and layout.groups[1].buttons[1] then
            local er = self:getGroupButtonRect(layout, 1, 1, centered_y, 0, width_override or window_width, window_height, main_offset_x + pin_shift_x + (row_offset_x or 0), main_offset_y + (row_offset_y or 0))
            self:renderEmptyDropHighlight(ctx, draw_list, coords, er)
            -- simplified ghost logic
            if C.DragDropManager:isGroupDrag() and C.DragDropManager:getDragSourceGroup() then
                local src_group = C.DragDropManager:getDragSourceGroup()
                local spacing = CONFIG.SIZES.SPACING or 0
                local gx, gy = er.rel_x, er.rel_y
                for _, btn in ipairs(src_group.buttons) do
                    local gw = (btn.cached_width and btn.cached_width.total) or CONFIG.SIZES.MIN_WIDTH
                    local gh = CONFIG.SIZES.HEIGHT
                    if btn:isSeparator() then
                        if layout.is_vertical then gw, gh = er.width, (btn.cache.layout and btn.cache.layout.height) or CONFIG.SIZES.SEPARATOR_SIZE
                        else gw, gh = (btn.cache.layout and btn.cache.layout.width) or CONFIG.SIZES.SEPARATOR_SIZE, CONFIG.SIZES.SEPARATOR_SIZE end
                    elseif layout.is_vertical then gw = er.width end
                    local bl = { width = gw, height = gh, is_vertical = layout.is_vertical }
                    C.ButtonRenderer:renderButton(ctx, btn, gx, gy, coords, draw_list, editing_mode, bl, { ghost_mode = true })
                    if layout.is_vertical then gy = gy + gh + spacing else gx = gx + gw + spacing end
                end
            else
                local src = C.DragDropManager:getDragSource()
                if src then
                    local gw = (src.cached_width and src.cached_width.total) or CONFIG.SIZES.MIN_WIDTH
                    local gh = CONFIG.SIZES.HEIGHT
                    if src:isSeparator() then
                        if layout.is_vertical then gw, gh = er.width, (src.cache.layout and src.cache.layout.height) or CONFIG.SIZES.SEPARATOR_SIZE
                        else gw, gh = (src.cache.layout and src.cache.layout.width) or CONFIG.SIZES.SEPARATOR_SIZE, CONFIG.SIZES.SEPARATOR_SIZE end
                    elseif layout.is_vertical then gw = er.width end
                    local gx, gy = er.rel_x + (er.width - gw) / 2, er.rel_y + (er.height - gh) / 2
                    local gl = { width = gw, height = gh, is_vertical = layout.is_vertical }
                    C.ButtonRenderer:renderButton(ctx, src, gx, gy, coords, draw_list, editing_mode, gl, { ghost_mode = true })
                end
            end
        end
    else
        for i, group_layout in ipairs(layout.groups) do
            local group = row_toolbar.groups[i]
            local group_x = group_layout.x + main_offset_x + pin_shift_x + (row_offset_x or 0)
            local group_y = (layout.is_vertical and (group_layout.y or 0) or centered_y) + main_offset_y + (row_offset_y or 0)
            group_x, group_y = self:layoutGroupOriginForSplit(layout, width_override or window_width, window_height, i, group_x, group_y)

            C.GroupRenderer:renderGroup(
                ctx,
                group,
                group_x,
                group_y,
                coords,
                draw_list,
                editing_mode,
                group_layout,
                layout,
                i,
                row_toolbar
            )

            local settings_button, settings_group = C.Interactions:getButtonSettings(ctx)
            if settings_button then
                for _, button in ipairs(group.buttons) do
                    if button.instance_id == settings_button.instance_id then
                        if C.ButtonSettingsMenu:handleButtonSettingsMenu(ctx, settings_button, settings_group, layout.is_vertical) then
                            popup_open = true
                        else
                            C.Interactions:clearButtonSettings(ctx)
                        end
                        break
                    end
                end
            end
        end
    end

    if editing_mode and C.ButtonRenderer then
        if row_toolbar and not row_toolbar.is_toolbar_switch_widget then
            self:renderEditModeTrailingAddControl(
                ctx,
                coords,
                draw_list,
                layout,
                row_toolbar,
                width_override or window_width,
                window_height,
                centered_y,
                0,
                main_offset_x + pin_shift_x + (row_offset_x or 0),
                main_offset_y + (row_offset_y or 0)
            )
        end
        if row_index == 0 then
            C.ButtonRenderer:renderPendingControlsOnTop(ctx, draw_list, coords)
        end
    end

    return popup_open
end

function ToolbarWindow:renderToolbarContent(ctx)
    local all_toolbars = self.toolbar_controller:getAllRowToolbars()
    if not all_toolbars or #all_toolbars == 0 or not all_toolbars[1] then
        return false
    end

    local popup_open = false

    C.LayoutManager:setContext(ctx)
    local window_width = reaper.ImGui_GetWindowWidth(ctx)
    local window_height = reaper.ImGui_GetWindowHeight(ctx)
    local pin_force_horizontal = self.toolbar_controller:shouldFollowUiAnchor()
    local is_vertical = not pin_force_horizontal and window_width > 0 and window_height > 0 and window_width < window_height

    local editing_mode = self.toolbar_controller.button_editing_mode
    local row_count = #all_toolbars

    local col_width = nil
    if is_vertical then
        col_width = math.floor(window_width / row_count)
    end

    local layout0 = nil
    local layout_switch0 = nil
    local current_offset_x = 0
    local current_offset_y = 0

    for i = 1, row_count do
        local row_index = i - 1
        local row_toolbar = all_toolbars[i]
        
        if not self:toolbarIsEmpty(row_toolbar) and self.toolbar_controller._empty_ph_button then
            self.toolbar_controller:clearEmptyPlaceholderCache()
        end

        local enable_switch = false
        local switch_tb = nil
        if row_index == 0 then
            enable_switch = self.toolbar_controller.enable_toolbar_switch
            switch_tb = self.toolbar_controller.toolbar_switch_toolbar
        else
            enable_switch = self.toolbar_controller.extra_rows[row_index] and self.toolbar_controller.extra_rows[row_index].enable_toolbar_switch
            switch_tb = self.toolbar_controller.extra_row_switch_toolbars[row_index]
        end

        local layout_switch = nil
        local main_offset_x = 0
        local main_offset_y = 0
        local strip_gap = (CONFIG.SIZES and CONFIG.SIZES.SPACING) or 2
        local sep_size = (CONFIG.SIZES and CONFIG.SIZES.SEPARATOR_SIZE) or 12
        local switch_gap_before_sep = strip_gap + 4

        if enable_switch and switch_tb then
            self:tagToolbarButtons(switch_tb, self.toolbar_controller.toolbar_id)
            layout_switch = C.LayoutManager:getToolbarLayout(
                tostring(self.toolbar_controller.toolbar_id) .. "_row_" .. tostring(row_index) .. "_switch",
                switch_tb,
                { force_horizontal = pin_force_horizontal }
            )
            if is_vertical then
                main_offset_y = layout_switch.height + switch_gap_before_sep + sep_size + strip_gap
            else
                main_offset_x = layout_switch.width + switch_gap_before_sep + sep_size + strip_gap
            end
        end

        local layout_source_toolbar = row_toolbar
        if self:toolbarIsEmpty(row_toolbar) then
            local ph_button, ph_group = self.toolbar_controller:getEmptyPlaceholderButton(row_toolbar)
            layout_source_toolbar = self:buildPlaceholderShadowToolbar(row_toolbar, ph_group, ph_button)
        end

        self:tagToolbarButtons(layout_source_toolbar, self.toolbar_controller.toolbar_id)

        local layout_opts = { editing_mode = editing_mode, force_horizontal = pin_force_horizontal }
        
        local use_child = self.toolbar_controller.enable_row_scroll and not pin_force_horizontal
        
        if is_vertical then
            layout_opts.width_override = col_width
        else
            if use_child then
                -- When per-row scrolling is ON in horizontal mode, we prevent wrapping so the row can scroll horizontally.
                -- We use a very large width_override so buttons never wrap.
                layout_opts.width_override = 99999
            elseif enable_switch and switch_tb and main_offset_x > 0 then
                layout_opts.width_override = math.max(window_width - main_offset_x, CONFIG.SIZES.MIN_WIDTH or 30)
            end
        end

        local layout_id = tostring(self.toolbar_controller.toolbar_id) .. (row_index == 0 and "" or ("_row_" .. row_index))
        local layout0_local = C.LayoutManager:getToolbarLayout(layout_id, layout_source_toolbar, layout_opts)
        
        local centered_y0 = is_vertical and (layout0_local.padding_y or 0) or 8
        local r_w = layout0_local.width + main_offset_x
        local r_h = layout0_local.height + main_offset_y + (centered_y0 * 2)

        local child_id = "row_child_" .. row_index
        local flags = reaper.ImGui_WindowFlags_NoBackground() | reaper.ImGui_WindowFlags_NoScrollbar()
        if not is_vertical then
            flags = flags | reaper.ImGui_WindowFlags_HorizontalScrollbar()
        end

        local avail_w, avail_h = reaper.ImGui_GetContentRegionAvail(ctx)
        local child_w = is_vertical and math.max(1, col_width or 1) or math.max(1, avail_w)
        local child_h = is_vertical and math.max(1, avail_h) or math.max(1, r_h)
        local row_offset_x = use_child and 0 or current_offset_x
        local row_offset_y = use_child and 0 or current_offset_y

        reaper.ImGui_PushID(ctx, "row_" .. row_index)

        local visible = true
        if use_child then
            visible = reaper.ImGui_BeginChild(ctx, child_id, child_w, child_h, 0, flags)
        end

        local coords = COORDINATES.new(ctx)
        local draw_list = reaper.ImGui_GetWindowDrawList(ctx)

        if visible then
            local pop = self:renderSingleRow(
                ctx, coords, draw_list, row_toolbar, row_index, is_vertical,
                col_width, switch_tb, enable_switch,
                window_width, window_height, editing_mode, pin_force_horizontal, layout0_local, layout_switch,
                row_offset_x, row_offset_y
            )
            if pop then popup_open = true end
        end
        
        if use_child and visible then
            reaper.ImGui_EndChild(ctx)
        end
        
        reaper.ImGui_PopID(ctx)

        if row_index == 0 then
            layout0 = layout0_local
            layout_switch0 = layout_switch
        end

        if is_vertical then
            current_offset_x = current_offset_x + col_width
        else
            current_offset_y = current_offset_y + r_h
        end

        if i < row_count then
            if use_child and is_vertical then
                reaper.ImGui_SameLine(ctx)
            end
        end
    end

    if pin_force_horizontal and layout0 then
        local single_h = self:computePinnedMinContentHeight(layout0, layout_switch0, self.toolbar_controller.enable_toolbar_switch)
        self._pin_content_min_h = single_h * row_count
    end

    self.toolbar_controller:updateDockState(ctx)

    return popup_open
end

function ToolbarWindow:renderUIElements(ctx, popup_open)
    local button_settings_menu = rawget(C, "ButtonSettingsMenu")
    local action_search = rawget(C, "ActionSearch")
    local icon_selector = rawget(C, "IconSelector")
    local button_dropdown_menu = rawget(C, "ButtonDropdownMenu")
    local button_dropdown_editor = rawget(C, "ButtonDropdownEditor")
    if popup_open
        or (C.Interactions and (C.Interactions.preset_browser_open or C.Interactions.insert_menu_button))
        or (button_settings_menu and button_settings_menu.widget_selection and button_settings_menu.widget_selection.is_open)
        or (button_settings_menu and button_settings_menu.dropdown_edit_button)
        or (action_search and action_search.is_open)
        or (icon_selector and icon_selector.is_open)
        or (button_dropdown_menu and button_dropdown_menu.is_open)
        or (button_dropdown_editor and button_dropdown_editor.is_open)
    then
        require("Systems.Modules_Factory").ensureUiModules()
    end

    if C.IconSelector and C.IconSelector.is_open then
        popup_open = C.IconSelector:renderGrid(ctx) or popup_open
    end

    if C.ButtonDropdownMenu and C.ButtonDropdownMenu.is_open then
        popup_open = C.ButtonDropdownMenu:renderDropdown(ctx) or popup_open
    end

    if C.Interactions and C.Interactions.insert_menu_button then
        popup_open = C.Interactions:renderInsertMenu(ctx) or popup_open
    end
    if C.ActionSearch then
        popup_open = C.ActionSearch:render(ctx) or popup_open
    end
    if C.Interactions and C.Interactions.preset_browser_open then
        C.Interactions:ensurePresetBrowserLoaded()
        popup_open = C.Interactions:renderPresetBrowserWindow(ctx) or popup_open
    end
    if C.Interactions then
        popup_open = C.Interactions:renderUnderMouseAutoArmNotice(ctx) or popup_open
    end

    button_settings_menu = rawget(C, "ButtonSettingsMenu")
    if button_settings_menu and button_settings_menu.widget_selection and button_settings_menu.widget_selection.is_open then
        popup_open = button_settings_menu:renderWidgetSelector(ctx) or popup_open
    end

    if button_settings_menu and button_settings_menu.dropdown_edit_button then
        self.toolbar_controller:showDropdownEditor(button_settings_menu.dropdown_edit_button, ctx)
        button_settings_menu.dropdown_edit_button = nil
    end

    if C.ButtonDropdownEditor and C.ButtonDropdownEditor.is_open then
        popup_open = C.ButtonDropdownEditor:renderDropdownEditor(ctx, C.ButtonDropdownEditor.current_button) or popup_open
    end

    -- GlobalColorEditor floating window is no longer used;
    -- colors are now rendered inline via the Colors tab in the settings popup.

    return popup_open
end

return {
    new = function(...)
        return ToolbarWindow.new(...)
    end
}