-- Renderers/01_Toolbar/toolbar_content.lua

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
    self.toolbar_controller.is_vertical = is_vertical

    local editing_mode = self.toolbar_controller.button_editing_mode
    local row_count = #all_toolbars

    local avail_w0, avail_h0 = reaper.ImGui_GetContentRegionAvail(ctx)

    local col_width = nil
    local col_offset_x = 0
    if is_vertical then
        col_width = math.max(1, math.floor(avail_w0 / row_count))
        col_offset_x = math.floor((avail_w0 - col_width * row_count) / 2)
    end

    local layout0 = nil
    local layout_switch0 = nil

    local row_strip = not pin_force_horizontal
    local scroll_on = self.toolbar_controller.enable_row_scroll and row_strip
    local use_child = scroll_on and not pin_force_horizontal
    local use_row_child = row_strip and is_vertical
    local defer_vertical_layout = is_vertical and use_row_child
    local current_offset_x = 0
    local current_offset_y = 0

    if not is_vertical then
        UTILS.clampVerticalScroll(ctx)
    end

    local row_coords = COORDINATES.new(ctx)

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

        local layout_source_toolbar = row_toolbar
        if self:toolbarIsEmpty(row_toolbar) then
            local ph_button, ph_group = self.toolbar_controller:getEmptyPlaceholderButton(row_toolbar)
            layout_source_toolbar = self:buildPlaceholderShadowToolbar(row_toolbar, ph_group, ph_button)
        end

        self:tagToolbarButtons(layout_source_toolbar, self.toolbar_controller.toolbar_id, row_index)

        local layout_opts = {
            editing_mode = editing_mode,
            force_horizontal = pin_force_horizontal,
            toolbar_vertical = is_vertical,
            main_window_width = window_width,
            main_window_height = window_height,
        }
        local layout_id = tostring(self.toolbar_controller.toolbar_id) .. (row_index == 0 and "" or ("_row_" .. row_index))
        local layout0_local = nil

        local function layout_switch_id()
            return tostring(self.toolbar_controller.toolbar_id) .. "_row_" .. tostring(row_index) .. "_switch"
        end

        local function apply_switch_layout(switch_layout)
            if is_vertical then
                main_offset_y = switch_layout.height + switch_gap_before_sep + sep_size + strip_gap
            else
                main_offset_x = switch_layout.width + switch_gap_before_sep + sep_size + strip_gap
            end
        end

        if not defer_vertical_layout then
            if enable_switch and switch_tb then
                self:tagToolbarButtons(switch_tb, self.toolbar_controller.toolbar_id, row_index)
                local sw_opts = {
                    force_horizontal = pin_force_horizontal,
                    toolbar_vertical = is_vertical,
                    main_window_width = window_width,
                    main_window_height = window_height,
                }
                if is_vertical then
                    sw_opts.width_override = col_width
                end
                layout_switch = C.LayoutManager:getToolbarLayout(layout_switch_id(), switch_tb, sw_opts)
                apply_switch_layout(layout_switch)
            end
            if is_vertical then
                layout_opts.width_override = col_width
            elseif use_child then
                layout_opts.width_override = 99999
            elseif enable_switch and switch_tb and main_offset_x > 0 then
                layout_opts.width_override = math.max(window_width - main_offset_x, CONFIG.SIZES.MIN_WIDTH or 30)
            end
            layout0_local = C.LayoutManager:getToolbarLayout(layout_id, layout_source_toolbar, layout_opts)
        end

        local centered_y0 = is_vertical and ((layout0_local and layout0_local.padding_y) or self:toolbarEdgePad()) or self:toolbarEdgePad()
        local r_h = layout0_local and (layout0_local.height + main_offset_y + (centered_y0 * 2)) or avail_h0

        local child_id = "row_child_" .. row_index
        local flags = reaper.ImGui_WindowFlags_NoBackground() | reaper.ImGui_WindowFlags_NoScrollbar()
        if use_child and not is_vertical then
            flags = flags | reaper.ImGui_WindowFlags_HorizontalScrollbar()
        end

        local avail_w, avail_h = reaper.ImGui_GetContentRegionAvail(ctx)
        local child_w = is_vertical and math.max(1, col_width or 1) or math.max(1, avail_w)
        local child_h = is_vertical and math.max(1, avail_h0) or math.max(1, r_h)
        -- ImGui child windows / SameLine already stack rows/columns; don't add offset twice.
        local imgui_stacks_strip = use_row_child or (use_child and not is_vertical)
        local row_offset_x = imgui_stacks_strip and 0 or current_offset_x
        local row_offset_y = imgui_stacks_strip and 0 or current_offset_y

        reaper.ImGui_PushID(ctx, "row_" .. row_index)

        local visible = true
        local child_style_vars = 0
        if use_row_child or (use_child and not is_vertical) then
            if is_vertical and row_index == 0 and col_offset_x > 0 and reaper.ImGui_SetCursorPosX then
                reaper.ImGui_SetCursorPosX(ctx, reaper.ImGui_GetCursorPosX(ctx) + col_offset_x)
            end
            if reaper.ImGui_StyleVar_WindowPadding then
                reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding(), 0, 0)
                child_style_vars = child_style_vars + 1
            end
            if reaper.ImGui_StyleVar_ItemSpacing then
                reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), 0, 0)
                child_style_vars = child_style_vars + 1
            end
            visible = reaper.ImGui_BeginChild(ctx, child_id, child_w, child_h, 0, flags)
        end

        if defer_vertical_layout and visible then
            C.LayoutManager:setContext(ctx)
            local live_col_w = math.max(1, reaper.ImGui_GetWindowWidth(ctx) or col_width or 1)
            layout_opts.width_override = live_col_w
            if enable_switch and switch_tb then
                self:tagToolbarButtons(switch_tb, self.toolbar_controller.toolbar_id, row_index)
                layout_switch = C.LayoutManager:getToolbarLayout(
                    layout_switch_id(),
                    switch_tb,
                    {
                        force_horizontal = pin_force_horizontal,
                        width_override = live_col_w,
                        toolbar_vertical = is_vertical,
                        main_window_width = window_width,
                        main_window_height = window_height,
                    }
                )
                apply_switch_layout(layout_switch)
            end
            layout0_local = C.LayoutManager:getToolbarLayout(layout_id, layout_source_toolbar, layout_opts)
        end

        local coords = row_coords
        coords.ctx = ctx
        coords:refreshScroll()
        local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
        local col_render_w = col_width

        if visible and layout0_local then
            local current_win_w = reaper.ImGui_GetWindowWidth(ctx)
            local current_win_h = reaper.ImGui_GetWindowHeight(ctx)
            local pop = self:renderSingleRow(
                ctx, coords, draw_list, row_toolbar, row_index, is_vertical,
                col_render_w, switch_tb, enable_switch,
                current_win_w, current_win_h, editing_mode, pin_force_horizontal, layout0_local, layout_switch,
                row_offset_x, row_offset_y
            )
            if pop then popup_open = true end
            if use_child and not is_vertical then
                UTILS.clampVerticalScroll(ctx)
                UTILS.applyHorizontalWheelScroll(ctx)
            end
        end

        if (use_row_child or (use_child and not is_vertical)) and visible then
            reaper.ImGui_EndChild(ctx)
        end
        if child_style_vars > 0 then
            reaper.ImGui_PopStyleVar(ctx, child_style_vars)
        end

        reaper.ImGui_PopID(ctx)

        if row_index == 0 then
            layout0 = layout0_local
            layout_switch0 = layout_switch
        end

        if is_vertical then
            current_offset_x = current_offset_x + (col_width or 0)
        elseif not imgui_stacks_strip then
            current_offset_y = current_offset_y + r_h
        end

        if i < row_count and use_row_child then
            reaper.ImGui_SameLine(ctx)
        end
    end

    if pin_force_horizontal and layout0 then
        local single_h = self:computePinnedMinContentHeight(layout0, layout_switch0, self.toolbar_controller.enable_toolbar_switch)
        self._pin_content_min_h = single_h * row_count
    end

    if not is_vertical then
        UTILS.clampVerticalScroll(ctx)
        UTILS.clampHorizontalScroll(ctx)
    end

    self.toolbar_controller:updateDockState(ctx)

    return popup_open
end
