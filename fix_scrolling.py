import re

with open('/Users/fearghasgundy/Desktop/Audio/Reaper/Scripts/Advanced Toolbars/Working Copy/Renderers/01_Toolbar.lua', 'r') as f:
    content = f.read()

# Restore enable_row_scroll check and fix width_override for horizontal mode

match = re.search(r"        local layout_opts = \{ editing_mode = editing_mode, force_horizontal = pin_force_horizontal \}(.*?)        local child_w = is_vertical and col_width or 0\n        local child_h = is_vertical and 0 or math\.max\(20, row_height\)\n\n        local use_child = not pin_force_horizontal", content, re.DOTALL)
if match:
    old_block = match.group(0)
    
    new_block = """        local layout_opts = { editing_mode = editing_mode, force_horizontal = pin_force_horizontal }
        
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
        local flags = reaper.ImGui_WindowFlags_NoBackground()
        if not is_vertical then
            flags = flags | reaper.ImGui_WindowFlags_HorizontalScrollbar()
        end

        local child_w = is_vertical and col_width or 0
        local child_h = is_vertical and 0 or (use_child and math.max(20, row_height) or r_h)"""
        
    content = content.replace(old_block, new_block)
else:
    print("Could not find block")

with open('/Users/fearghasgundy/Desktop/Audio/Reaper/Scripts/Advanced Toolbars/Working Copy/Renderers/01_Toolbar.lua', 'w') as f:
    f.write(content)
print("Updated 01_Toolbar.lua scrolling")
