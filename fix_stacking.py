import re

with open('/Users/fearghasgundy/Desktop/Audio/Reaper/Scripts/Advanced Toolbars/Working Copy/Renderers/01_Toolbar.lua', 'r') as f:
    content = f.read()

# 1. Update renderSingleRow signature to include row_offset_x, row_offset_y at the end
old_sig = "function ToolbarWindow:renderSingleRow(ctx, coords, draw_list, row_toolbar, row_index, is_vertical, width_override, switch_toolbar, enable_switch, window_width, window_height, editing_mode, pin_force_horizontal, layout0, layout_switch)"
new_sig = "function ToolbarWindow:renderSingleRow(ctx, coords, draw_list, row_toolbar, row_index, is_vertical, width_override, switch_toolbar, enable_switch, window_width, window_height, editing_mode, pin_force_horizontal, layout0, layout_switch, row_offset_x, row_offset_y)"
content = content.replace(old_sig, new_sig)

# 2. Add row_offset_x, row_offset_y to drag drop
old_dd = """    self:handleToolbarDragDrop(
        ctx,
        row_toolbar,
        editing_mode,
        coords,
        draw_list,
        layout0,
        centered_y0,
        0, -- edit_mode_left_gutter
        layout_source_toolbar,
        main_offset_x + pin_shift_x,
        main_offset_y
    )"""
new_dd = """    self:handleToolbarDragDrop(
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
    )"""
content = content.replace(old_dd, new_dd)

# 3. Add to ghost layout shift
old_ghost = """        self:refineDropPositionForDragGhost(ctx, coords, layout, layout_source_toolbar, row_toolbar, cy_refine, 0, main_offset_x + pin_shift_x, main_offset_y)"""
new_ghost = """        self:refineDropPositionForDragGhost(ctx, coords, layout, layout_source_toolbar, row_toolbar, cy_refine, 0, main_offset_x + pin_shift_x + (row_offset_x or 0), main_offset_y + (row_offset_y or 0))"""
content = content.replace(old_ghost, new_ghost)

# 4. Add to switch rendering
old_switch = """            local group_x = group_layout.x + pin_shift_x
            local group_y = layout_switch.is_vertical and (group_layout.y or 0) or (centered_y + switch_title_offset_y)"""
new_switch = """            local group_x = group_layout.x + pin_shift_x + (row_offset_x or 0)
            local group_y = (layout_switch.is_vertical and (group_layout.y or 0) or (centered_y + switch_title_offset_y)) + (row_offset_y or 0)"""
content = content.replace(old_switch, new_switch)

old_sep = """        self:drawToolbarSwitchSeparator(ctx, draw_list, coords, layout_switch, is_vertical, sep_size, centered_y + switch_title_offset_y, switch_gap_before_sep, pin_shift_x, 0, 0, width_override)"""
new_sep = """        self:drawToolbarSwitchSeparator(ctx, draw_list, coords, layout_switch, is_vertical, sep_size, centered_y + switch_title_offset_y, switch_gap_before_sep, pin_shift_x, (row_offset_x or 0), (row_offset_y or 0), width_override)"""
content = content.replace(old_sep, new_sep)

# 5. Add to empty row rendering
old_empty = """            local group_x = group_layout.x + main_offset_x + pin_shift_x
            local group_y = (layout.is_vertical and (group_layout.y or 0) or centered_y) + main_offset_y"""
new_empty = """            local group_x = group_layout.x + main_offset_x + pin_shift_x + (row_offset_x or 0)
            local group_y = (layout.is_vertical and (group_layout.y or 0) or centered_y) + main_offset_y + (row_offset_y or 0)"""
content = content.replace(old_empty, new_empty)

old_empty_rect = """            local er = self:getGroupButtonRect(layout, 1, 1, centered_y, 0, width_override or window_width, window_height, main_offset_x + pin_shift_x, main_offset_y)"""
new_empty_rect = """            local er = self:getGroupButtonRect(layout, 1, 1, centered_y, 0, width_override or window_width, window_height, main_offset_x + pin_shift_x + (row_offset_x or 0), main_offset_y + (row_offset_y or 0))"""
content = content.replace(old_empty_rect, new_empty_rect)

# 6. Add to edit mode add control
old_edit = """                main_offset_x + pin_shift_x,
                main_offset_y
            )"""
new_edit = """                main_offset_x + pin_shift_x + (row_offset_x or 0),
                main_offset_y + (row_offset_y or 0)
            )"""
content = content.replace(old_edit, new_edit)

# 7. Update renderToolbarContent loop
match = re.search(r"    local col_width = nil(.*?)    if pin_force_horizontal and layout0 then", content, re.DOTALL)
if match:
    old_loop = match.group(0)
    
    # We replace the loop to include current_offset tracking and PushID
    new_loop = """    local col_width = nil
    local row_height = nil
    if is_vertical then
        col_width = math.floor(window_width / row_count)
    else
        row_height = math.floor(window_height / row_count)
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
        if is_vertical then
            layout_opts.width_override = col_width
        else
            if enable_switch and switch_tb and main_offset_x > 0 then
                layout_opts.width_override = math.max(window_width - main_offset_x, CONFIG.SIZES.MIN_WIDTH or 30)
            end
        end

        local layout_id = tostring(self.toolbar_controller.toolbar_id) .. (row_index == 0 and "" or ("_row_" .. row_index))
        local layout0_local = C.LayoutManager:getToolbarLayout(layout_id, layout_source_toolbar, layout_opts)
        
        local centered_y0 = is_vertical and (layout0_local.padding_y or 0) or 8
        local r_w = layout0_local.width + main_offset_x
        local r_h = layout0_local.height + main_offset_y + (centered_y0 * 2)

        local child_id = "row_child_" .. row_index
        local flags = reaper.ImGui_WindowFlags_NoBackground()
        if not is_vertical then
            flags = flags | reaper.ImGui_WindowFlags_HorizontalScrollbar()
        end

        local child_w = is_vertical and col_width or 0
        local child_h = is_vertical and 0 or math.max(20, row_height)

        local use_child = not pin_force_horizontal
        local row_offset_x = use_child and 0 or current_offset_x
        local row_offset_y = use_child and 0 or current_offset_y

        reaper.ImGui_PushID(ctx, "row_" .. row_index)

        if use_child then
            reaper.ImGui_BeginChild(ctx, child_id, child_w, child_h, 0, flags)
        end

        local coords = COORDINATES.new(ctx)
        local draw_list = reaper.ImGui_GetWindowDrawList(ctx)

        local pop = self:renderSingleRow(
            ctx, coords, draw_list, row_toolbar, row_index, is_vertical,
            col_width, switch_tb, enable_switch,
            window_width, window_height, editing_mode, pin_force_horizontal, layout0_local, layout_switch,
            row_offset_x, row_offset_y
        )
        if pop then popup_open = true end
        
        if use_child then
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

    if pin_force_horizontal and layout0 then"""
    content = content.replace(old_loop, new_loop)
else:
    print("Could not find loop to replace")

with open('/Users/fearghasgundy/Desktop/Audio/Reaper/Scripts/Advanced Toolbars/Working Copy/Renderers/01_Toolbar.lua', 'w') as f:
    f.write(content)
print("Updated 01_Toolbar.lua offsets")
